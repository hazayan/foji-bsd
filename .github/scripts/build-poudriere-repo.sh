#!/bin/sh
set -eu

FREEBSD_RELEASE="${FREEBSD_RELEASE:-15.0-RELEASE}"
FREEBSD_MAJOR="${FREEBSD_MAJOR:-15}"
PKG_ABI="${PKG_ABI:-FreeBSD:${FREEBSD_MAJOR}:aarch64}"
POUDRIERE_ARCH="${POUDRIERE_ARCH:-arm64.aarch64}"
TARGET_ARCH="${TARGET_ARCH:-aarch64}"
JAIL_NAME="${JAIL_NAME:-freebsd${FREEBSD_MAJOR}-aarch64}"
PORTS_TREE="${PORTS_TREE:-foji}"
SET_NAME="${SET_NAME:-default}"
REQUESTED_PORTS="${REQUESTED_PORTS:-auto}"
PACKAGE_FETCH_BRANCH="${PACKAGE_FETCH_BRANCH:-latest}"
POUDRIERE_JAIL_FLAGS="${POUDRIERE_JAIL_FLAGS:--X}"
HEARTBEAT_INTERVAL="${HEARTBEAT_INTERVAL:-60}"
REPO_OUT="${REPO_OUT:-repo-output/${PKG_ABI}}"
POUDRIERE_BASE="${POUDRIERE_BASE:-/usr/local/poudriere}"
case "${POUDRIERE_BASE}" in
	/*)
		;;
	*)
		POUDRIERE_BASE="$(pwd)/${POUDRIERE_BASE}"
		;;
esac
PORTS_ROOT="${POUDRIERE_BASE}/ports/${PORTS_TREE}"
PACKAGES_ROOT="${POUDRIERE_BASE}/data/packages/${JAIL_NAME}-${PORTS_TREE}-${SET_NAME}"
DISTFILES_CACHE="${DISTFILES_CACHE:-${POUDRIERE_BASE}/distfiles}"
PKGLIST="/usr/local/etc/poudriere.d/${PKG_ABI}.pkglist"
SIGNING_KEY="${POUDRIERE_BASE}/keys/pkg.key"
SIGNING_PUB="${POUDRIERE_BASE}/keys/pkg.pub"
SIGNING_TYPE="${SIGNING_TYPE:-ecdsa}"

log() {
	printf '\n==> %s\n' "$*"
}

heartbeat() {
	while :; do
		sleep "${HEARTBEAT_INTERVAL}"
		log "Heartbeat: build still running at $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
		ps -ax -o pid,stat,etime,command |
			awk '/[p]oudriere|[p]kg |[m]ake|[q]emu|[c]c |[c][+][+] |[r]ustc|[c]argo/ {print}'
	done
}

start_heartbeat() {
	heartbeat &
	HEARTBEAT_PID="$!"
	trap stop_heartbeat EXIT INT TERM
}

stop_heartbeat() {
	if [ -n "${HEARTBEAT_PID:-}" ]; then
		kill "${HEARTBEAT_PID}" 2>/dev/null || true
		wait "${HEARTBEAT_PID}" 2>/dev/null || true
	fi
}

require_secret() {
	if [ -z "${PKG_REPO_SIGNING_KEY_B64:-}" ]; then
		echo "PKG_REPO_SIGNING_KEY_B64 secret is required. It must contain a base64-encoded OpenSSL ECDSA DER private key." >&2
		exit 1
	fi
}

discover_ports() {
	find ./*/*/Makefile \
		-print |
		sed 's#^\./##; s#/Makefile$##' |
		sort
}

word_contains() {
	word="$1"
	shift
	for candidate in "$@"; do
		if [ "${candidate}" = "${word}" ]; then
			return 0
		fi
	done
	return 1
}

port_supports_target_arch() {
	origin="$1"
	port_dir="${PORTS_ROOT}/${origin}"
	only_for_archs="$(make -C "${port_dir}" -V ONLY_FOR_ARCHS)"
	not_for_archs="$(make -C "${port_dir}" -V NOT_FOR_ARCHS)"

	if [ -n "${only_for_archs}" ]; then
		# shellcheck disable=SC2086
		if ! word_contains "${TARGET_ARCH}" ${only_for_archs}; then
			log "Skipping ${origin}: ONLY_FOR_ARCHS=${only_for_archs}"
			return 1
		fi
	fi

	if [ -n "${not_for_archs}" ]; then
		# shellcheck disable=SC2086
		if word_contains "${TARGET_ARCH}" ${not_for_archs}; then
			log "Skipping ${origin}: NOT_FOR_ARCHS=${not_for_archs}"
			return 1
		fi
	fi

	return 0
}

write_pkglist() {
	: > "${PKGLIST}"
	if [ "${REQUESTED_PORTS}" = "auto" ]; then
		ports="$(discover_ports)"
	else
		ports="${REQUESTED_PORTS}"
	fi

	for origin in ${ports}; do
		if [ ! -d "${PORTS_ROOT}/${origin}" ]; then
			echo "Requested port origin does not exist in poudriere ports tree: ${origin}" >&2
			exit 1
		fi
		if port_supports_target_arch "${origin}"; then
			echo "${origin}" >> "${PKGLIST}"
		fi
	done
}

install_packages() {
	log "Installing poudriere and build prerequisites"
	env ASSUME_ALWAYS_YES=yes pkg bootstrap -f
	pkg update -f
	pkg install -y \
		ca_root_nss \
		git \
		pkg \
		poudriere \
		rsync \
		sudo

	if is_cross_build_host; then
		pkg install -y qemu-user-static
	fi
}

host_arch() {
	uname -p
}

normalized_arch() {
	case "$1" in
		arm64)
			echo "aarch64"
			;;
		amd64)
			echo "amd64"
			;;
		*)
			echo "$1"
			;;
	esac
}

is_cross_build_host() {
	[ "$(normalized_arch "$(host_arch)")" != "$(normalized_arch "${TARGET_ARCH}")" ]
}

configure_qemu() {
	log "Configuring qemu-user-static for cross-architecture package builds"
	kldload imgact_binmisc 2>/dev/null || true
	service qemu_user_static onestart 2>/dev/null || true
	binmiscctl list || true
}

configure_poudriere() {
	log "Configuring poudriere"
	mkdir -p "${POUDRIERE_BASE}" "${DISTFILES_CACHE}" "${POUDRIERE_BASE}/keys" /usr/local/etc/poudriere.d

	cat > /usr/local/etc/poudriere.conf <<EOF
NO_ZFS=yes
BASEFS=${POUDRIERE_BASE}
DISTFILES_CACHE=${DISTFILES_CACHE}
FREEBSD_HOST=https://download.FreeBSD.org
RESOLV_CONF=/etc/resolv.conf
USE_TMPFS=no
PARALLEL_JOBS=1
PREPARE_PARALLEL_JOBS=1
ALLOW_MAKE_JOBS=yes
KEEP_OLD_PACKAGES=no
KEEP_OLD_PACKAGES_COUNT=1
CHECK_CHANGED_OPTIONS=verbose
CHECK_CHANGED_DEPS=yes
PKG_REPO_SIGNING_KEY=${SIGNING_TYPE}:${SIGNING_KEY}
EOF

	printf '%s' "${PKG_REPO_SIGNING_KEY_B64}" | base64 -d > "${SIGNING_KEY}"
	chmod 0400 "${SIGNING_KEY}"
	openssl ec -in "${SIGNING_KEY}" -inform DER -pubout -out "${SIGNING_PUB}" -outform DER
}

create_jail_and_ports() {
	log "Creating poudriere jail ${JAIL_NAME} for ${FREEBSD_RELEASE} ${POUDRIERE_ARCH}"
	if ! poudriere jail -l -n -q | grep -qx "${JAIL_NAME}"; then
		# -X disables native xtools. The CI path uses an aarch64 VM for aarch64
		# packages, so we do not need poudriere to build a cross toolchain.
		# shellcheck disable=SC2086
		poudriere jail -c \
			-j "${JAIL_NAME}" \
			-v "${FREEBSD_RELEASE}" \
			-a "${POUDRIERE_ARCH}" \
			${POUDRIERE_JAIL_FLAGS} \
			-m http
	fi

	log "Creating poudriere ports tree ${PORTS_TREE}"
	if ! poudriere ports -l -q | awk '{print $1}' | grep -qx "${PORTS_TREE}"; then
		poudriere ports -c -p "${PORTS_TREE}" -m git+https
	fi
}

overlay_ports() {
	log "Overlaying foji-bsd custom ports into ${PORTS_ROOT}"
	for category in databases sysutils; do
		if [ -d "${category}" ]; then
			mkdir -p "${PORTS_ROOT}/${category}"
			rsync -a --delete "${category}/" "${PORTS_ROOT}/${category}/"
		fi
	done

	for metadata in UIDs GIDs; do
		if [ -f "${metadata}" ]; then
			cp "${metadata}" "${PORTS_ROOT}/${metadata}"
		fi
	done
}

build_repo() {
	log "Generating full pkglist"
	mkdir -p "$(dirname "${PKGLIST}")"
	write_pkglist
	cat "${PKGLIST}"
	if [ ! -s "${PKGLIST}" ]; then
		echo "No ports support target arch ${TARGET_ARCH}" >&2
		exit 1
	fi

	log "Building package set with poudriere"
	poudriere bulk \
		-j "${JAIL_NAME}" \
		-p "${PORTS_TREE}" \
		-z "${SET_NAME}" \
		-b "${PACKAGE_FETCH_BRANCH}" \
		-f "${PKGLIST}"
}

publishable_flat_repo() {
	log "Creating flat pkg repository at ${REPO_OUT}"
	rm -rf "${REPO_OUT}"
	mkdir -p "${REPO_OUT}"

	if [ ! -d "${PACKAGES_ROOT}/All" ]; then
		echo "Expected poudriere package directory not found: ${PACKAGES_ROOT}/All" >&2
		echo "Available package directories:" >&2
		find "${POUDRIERE_BASE}/data/packages" -maxdepth 2 -type d -print 2>/dev/null || true
		exit 1
	fi

	find "${PACKAGES_ROOT}/All" -maxdepth 1 -type f -name '*.pkg' -exec cp -p {} "${REPO_OUT}/" \;
	cp "${SIGNING_PUB}" "${REPO_OUT}/foji.pub"

	if ! find "${REPO_OUT}" -maxdepth 1 -type f -name '*.pkg' | grep -q .; then
		echo "No .pkg files were produced by poudriere" >&2
		exit 1
	fi

	pkg repo "${REPO_OUT}" "${SIGNING_TYPE}:${SIGNING_KEY}"
	ls -lah "${REPO_OUT}"
}

main() {
	start_heartbeat
	require_secret
	install_packages
	if is_cross_build_host; then
		configure_qemu
	else
		log "Skipping qemu-user-static setup on native $(host_arch) VM"
	fi
	configure_poudriere
	create_jail_and_ports
	overlay_ports
	build_repo
	publishable_flat_repo
}

main "$@"
