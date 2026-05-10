#!/usr/bin/env bash
set -euo pipefail

FREEBSD_RELEASE="${FREEBSD_RELEASE:-15.0-RELEASE}"
FREEBSD_MAJOR="${FREEBSD_MAJOR:-15}"
FOJI_BUILDER_ARCH="${FOJI_BUILDER_ARCH:-aarch64}"
FOJI_FORGE_DIR="${FOJI_FORGE_DIR:-${HOME}/devel/forge}"
FOJI_SSH_PUBLIC_KEY="${FOJI_SSH_PUBLIC_KEY:-${HOME}/.ssh/vms.pub}"
FOJI_SSH_PRIVATE_KEY="${FOJI_SSH_PRIVATE_KEY:-${HOME}/.ssh/vms}"
FOJI_SSH_PORT="${FOJI_SSH_PORT:-2222}"
FOJI_VM_CPUS="${FOJI_VM_CPUS:-}"
FOJI_VM_MEM="${FOJI_VM_MEM:-}"
FOJI_VM_DISK_SIZE="${FOJI_VM_DISK_SIZE:-64G}"
FOJI_REMOTE_USER="${FOJI_REMOTE_USER:-freebsd}"
FOJI_REMOTE_DIR="${FOJI_REMOTE_DIR:-/home/freebsd/foji-bsd}"
FOJI_BUILD_PROFILE="${FOJI_BUILD_PROFILE:-}"
REQUESTED_PORTS="${REQUESTED_PORTS:-auto}"
REPO_PACKAGE_ORIGINS="${REPO_PACKAGE_ORIGINS:-}"
PACKAGE_FETCH_BRANCH="${PACKAGE_FETCH_BRANCH:-}"
PACKAGE_FETCH_URL="${PACKAGE_FETCH_URL:-}"
PACKAGE_FETCH_WHITELIST="${PACKAGE_FETCH_WHITELIST:-}"
POUDRIERE_BULK_FLAGS="${POUDRIERE_BULK_FLAGS:--v}"
PORTS_REF="${PORTS_REF:-}"
SIGNING_TYPE="${SIGNING_TYPE:-ecdsa}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-hazayan/foji-bsd}"
RELEASE_TARGET="${RELEASE_TARGET:-sourcehut-pages}"
SOURCEHUT_PAGES_DOMAIN="${SOURCEHUT_PAGES_DOMAIN:-ylabidi.srht.site}"
PUBLISH="${PUBLISH:-no}"

case "${FOJI_BUILDER_ARCH}" in
	amd64)
		FOJI_VM_CPUS="${FOJI_VM_CPUS:-4}"
		FOJI_VM_MEM="${FOJI_VM_MEM:-8192}"
		PACKAGE_FETCH_BRANCH="${PACKAGE_FETCH_BRANCH:-quarterly}"
		FREEBSD_IMAGE_URL="${FREEBSD_IMAGE_URL:-https://download.freebsd.org/releases/VM-IMAGES/${FREEBSD_RELEASE}/amd64/Latest/FreeBSD-${FREEBSD_RELEASE}-amd64-BASIC-CLOUDINIT-zfs.raw.xz}"
		FREEBSD_IMAGE_SHA512="${FREEBSD_IMAGE_SHA512:-35f01d06cdb0d447455001faf6c658b34999d2b9fad73a07c66b99fcdb4b032c18b49109f1082cb5bec049295941dfe32a7295dec6fb37d8a51562a7fa06baf4}"
		PKG_ABI="${PKG_ABI:-FreeBSD:${FREEBSD_MAJOR}:amd64}"
		POUDRIERE_ARCH="${POUDRIERE_ARCH:-amd64}"
		TARGET_ARCH="${TARGET_ARCH:-amd64}"
		JAIL_NAME="${JAIL_NAME:-freebsd${FREEBSD_MAJOR}-amd64}"
		;;
	aarch64)
		FOJI_VM_CPUS="${FOJI_VM_CPUS:-2}"
		FOJI_VM_MEM="${FOJI_VM_MEM:-4096}"
		PACKAGE_FETCH_BRANCH="${PACKAGE_FETCH_BRANCH:-quarterly}"
		FREEBSD_IMAGE_URL="${FREEBSD_IMAGE_URL:-https://download.freebsd.org/releases/VM-IMAGES/${FREEBSD_RELEASE}/aarch64/Latest/FreeBSD-${FREEBSD_RELEASE}-arm64-aarch64-BASIC-CLOUDINIT-zfs.raw.xz}"
		FREEBSD_IMAGE_SHA512="${FREEBSD_IMAGE_SHA512:-cf99580c2c86e9df165ab2981e7d46993e212bceb367f47b4ac2c7a5543c00663052c21b2b4d776ffcf096d5591293f196853069229f613877755473c1616ca2}"
		PKG_ABI="${PKG_ABI:-FreeBSD:${FREEBSD_MAJOR}:aarch64}"
		POUDRIERE_ARCH="${POUDRIERE_ARCH:-arm64.aarch64}"
		TARGET_ARCH="${TARGET_ARCH:-aarch64}"
		JAIL_NAME="${JAIL_NAME:-freebsd${FREEBSD_MAJOR}-aarch64}"
		;;
	*)
		printf 'Unsupported FOJI_BUILDER_ARCH: %s\n' "${FOJI_BUILDER_ARCH}" >&2
		exit 1
		;;
esac

PORTS_TREE="${PORTS_TREE:-foji}"
PORTS_BRANCH="${PORTS_BRANCH:-}"
if [ -z "${PORTS_BRANCH}" ] && [ "${PACKAGE_FETCH_BRANCH}" = "quarterly" ]; then
	PORTS_BRANCH="2026Q2"
fi
if [ -z "${PORTS_REF}" ] && [ "${PORTS_BRANCH}" = "2026Q2" ]; then
	case "${FOJI_BUILDER_ARCH}" in
		aarch64)
			# Temporary pin to a validated 2026Q2 state where the aarch64
			# quarterly package set can satisfy kunci's large build deps.
			PORTS_REF="f724b00b1bf27db4605258801fbe8f21a537178a"
			;;
		amd64)
			# Temporary pin to a validated 2026Q2 state where the amd64
			# quarterly package set can satisfy kunci's large build deps.
			PORTS_REF="f724b00b1bf27db4605258801fbe8f21a537178a"
			;;
	esac
fi

case "${FOJI_BUILD_PROFILE}" in
	"")
		;;
	kunci)
		REQUESTED_PORTS="kunci"
		REPO_PACKAGE_ORIGINS="sysutils/kunci"
		;;
	sysbsd-amd64)
		if [ "${FOJI_BUILDER_ARCH}" != "amd64" ]; then
			printf 'FOJI_BUILD_PROFILE=sysbsd-amd64 requires FOJI_BUILDER_ARCH=amd64\n' >&2
			exit 1
		fi
		REQUESTED_PORTS="kunci zhamel zhamel-zfskey-kmod"
		REPO_PACKAGE_ORIGINS="sysutils/kunci sysutils/zhamel sysutils/zhamel-zfskey-kmod"
		;;
	foji-amd64)
		if [ "${FOJI_BUILDER_ARCH}" != "amd64" ]; then
			printf 'FOJI_BUILD_PROFILE=foji-amd64 requires FOJI_BUILDER_ARCH=amd64\n' >&2
			exit 1
		fi
		REQUESTED_PORTS="kunci zhamel zhamel-zfskey-kmod manticore nomad-pot-driver knox"
		REPO_PACKAGE_ORIGINS="sysutils/kunci sysutils/zhamel sysutils/zhamel-zfskey-kmod databases/manticore sysutils/nomad-pot-driver security/knox"
		;;
	manticore-amd64)
		if [ "${FOJI_BUILDER_ARCH}" != "amd64" ]; then
			printf 'FOJI_BUILD_PROFILE=manticore-amd64 requires FOJI_BUILDER_ARCH=amd64\n' >&2
			exit 1
		fi
		REQUESTED_PORTS="manticore"
		REPO_PACKAGE_ORIGINS="databases/manticore"
		;;
	changed)
		REQUESTED_PORTS="changed"
		;;
	*)
		printf 'Unsupported FOJI_BUILD_PROFILE: %s\n' "${FOJI_BUILD_PROFILE}" >&2
		exit 1
		;;
esac

SET_NAME="${SET_NAME:-default}"
POUDRIERE_JAIL_FLAGS="${POUDRIERE_JAIL_FLAGS:--X}"
RELEASE_TAG="${RELEASE_TAG:-repo-${PKG_ABI//:/-}}"
REPO_OUT="${REPO_OUT:-repo-output/${PKG_ABI}}"
SOURCEHUT_PAGES_SUBDIR="${SOURCEHUT_PAGES_SUBDIR:-/foji-bsd/${RELEASE_TAG}}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ARCH_DIR="${FOJI_FORGE_DIR}/bsd/${FOJI_BUILDER_ARCH}"
STATE_DIR="${ARCH_DIR}/builder"
IMAGE_XZ="${ARCH_DIR}/$(basename "${FREEBSD_IMAGE_URL}")"
BASE_IMAGE="${IMAGE_XZ%.xz}"
OVERLAY_IMAGE="${STATE_DIR}/foji-${FREEBSD_RELEASE}-${FOJI_BUILDER_ARCH}.qcow2"
SEED_DIR="${STATE_DIR}/seed"
SEED_ISO="${STATE_DIR}/cidata.iso"
PID_FILE="${STATE_DIR}/qemu.pid"
SERIAL_LOG="${STATE_DIR}/serial.log"
KNOWN_HOSTS="${STATE_DIR}/known_hosts"
VARS_FD="${STATE_DIR}/uefi-vars.fd"

log() {
	printf '\n==> %s\n' "$*"
}

die() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

if [ "${REQUESTED_PORTS}" = changed ]; then
	REQUESTED_PORTS="$("${SCRIPT_DIR}/list-changed-ports.sh")"
	[ -n "${REQUESTED_PORTS}" ] || die "No changed custom ports found. Set CHANGED_SINCE or REQUESTED_PORTS explicitly."
	REPO_PACKAGE_ORIGINS="${REPO_PACKAGE_ORIGINS:-${REQUESTED_PORTS}}"
fi

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_host_tools() {
	require_cmd curl
	require_cmd genisoimage
	require_cmd qemu-img
	require_cmd rsync
	require_cmd scp
	require_cmd ssh
	require_cmd nc
	require_cmd xz
	case "${FOJI_BUILDER_ARCH}" in
		amd64) require_cmd qemu-system-x86_64 ;;
		aarch64) require_cmd qemu-system-aarch64 ;;
	esac
}

ssh_target() {
	printf '%s@127.0.0.1' "${FOJI_REMOTE_USER}"
}

ssh_opts() {
	printf '%s\n' \
		-o StrictHostKeyChecking=accept-new \
		-o UserKnownHostsFile="${KNOWN_HOSTS}" \
		-o ConnectTimeout=5 \
		-o BatchMode=yes \
		-i "${FOJI_SSH_PRIVATE_KEY}" \
		-p "${FOJI_SSH_PORT}"
}

scp_opts() {
	printf '%s\n' \
		-o StrictHostKeyChecking=accept-new \
		-o UserKnownHostsFile="${KNOWN_HOSTS}" \
		-o ConnectTimeout=5 \
		-o BatchMode=yes \
		-i "${FOJI_SSH_PRIVATE_KEY}" \
		-P "${FOJI_SSH_PORT}"
}

shell_quote() {
	local value="$1"
	printf "'%s'" "${value//\'/\'\\\'\'}"
}

write_env_line() {
	local name="$1"
	local value="$2"
	printf 'export %s=%s\n' "${name}" "$(shell_quote "${value}")"
}

ensure_signing_key() {
	[ -n "${PKG_REPO_SIGNING_KEY_B64:-}" ] || die "PKG_REPO_SIGNING_KEY_B64 must be present in the environment"
}

download_image() {
	mkdir -p "${ARCH_DIR}"
	if [ ! -f "${IMAGE_XZ}" ]; then
		log "Downloading ${FREEBSD_IMAGE_URL}"
		curl -fL --retry 3 --retry-delay 5 -o "${IMAGE_XZ}.tmp" "${FREEBSD_IMAGE_URL}"
		mv "${IMAGE_XZ}.tmp" "${IMAGE_XZ}"
	fi
	verify_image_checksum

	if [ ! -f "${BASE_IMAGE}" ]; then
		log "Decompressing ${IMAGE_XZ}"
		xz -dk "${IMAGE_XZ}"
	fi
}

verify_image_checksum() {
	if [ "${FREEBSD_IMAGE_SHA512:-}" = skip ]; then
		log "Skipping SHA512 verification for ${IMAGE_XZ}"
		return 0
	fi
	[ -n "${FREEBSD_IMAGE_SHA512:-}" ] || die "FREEBSD_IMAGE_SHA512 is required for ${FREEBSD_IMAGE_URL}; set it to the expected SHA512 or to 'skip'"
	log "Verifying SHA512 for ${IMAGE_XZ}"
	if command -v sha512sum >/dev/null 2>&1; then
		printf '%s  %s\n' "${FREEBSD_IMAGE_SHA512}" "${IMAGE_XZ}" | sha512sum -c -
	elif command -v sha512 >/dev/null 2>&1; then
		local actual
		actual="$(sha512 -q "${IMAGE_XZ}")"
		[ "${actual}" = "${FREEBSD_IMAGE_SHA512}" ] || die "SHA512 mismatch for ${IMAGE_XZ}: ${actual}"
		printf '%s: OK\n' "${IMAGE_XZ}"
	else
		die "Missing SHA512 verifier: sha512sum or sha512"
	fi
}

create_overlay() {
	mkdir -p "${STATE_DIR}"
	if [ ! -f "${OVERLAY_IMAGE}" ]; then
		log "Creating persistent overlay ${OVERLAY_IMAGE}"
		(
			cd "${STATE_DIR}"
			qemu-img create -f qcow2 -F raw -b "../$(basename "${BASE_IMAGE}")" "$(basename "${OVERLAY_IMAGE}")"
			qemu-img resize "$(basename "${OVERLAY_IMAGE}")" "${FOJI_VM_DISK_SIZE}"
		)
	fi
}

create_seed_iso() {
	[ -r "${FOJI_SSH_PUBLIC_KEY}" ] || die "SSH public key is not readable: ${FOJI_SSH_PUBLIC_KEY}"
	local public_key
	public_key="$(tr -d '\n' < "${FOJI_SSH_PUBLIC_KEY}")"

	rm -rf "${SEED_DIR}"
	mkdir -p "${SEED_DIR}"
	cat > "${SEED_DIR}/meta-data" <<EOF
instance-id: foji-${FREEBSD_RELEASE}-${FOJI_BUILDER_ARCH}
local-hostname: foji-${FOJI_BUILDER_ARCH}
EOF
	cat > "${SEED_DIR}/user-data" <<EOF
#cloud-config
hostname: foji-${FOJI_BUILDER_ARCH}
users:
  - default
ssh_authorized_keys:
  - ${public_key}
ssh_pwauth: false
package_update: true
packages:
  - sudo
network:
  ethernets:
    vtnet0:
      dhcp4: true
write_files:
  - path: /usr/local/etc/sudoers.d/foji-builder
    owner: root:wheel
    permissions: '0440'
    defer: true
    content: |
      freebsd ALL=(ALL) NOPASSWD:ALL
  - path: /etc/rc.conf.d/sshd
    owner: root:wheel
    permissions: '0644'
    content: |
      sshd_enable="YES"
runcmd:
  - service sshd enable
  - service sshd start
EOF
	log "Creating NoCloud seed ISO ${SEED_ISO}"
	genisoimage -quiet -output "${SEED_ISO}" -volid cidata -joliet -rock "${SEED_DIR}/meta-data" "${SEED_DIR}/user-data"
}

prepare() {
	require_host_tools
	download_image
	create_overlay
	create_seed_iso
}

reset_builder() {
	require_host_tools
	stop_vm
	log "Removing generated builder state ${STATE_DIR}"
	rm -rf "${STATE_DIR}"
}

qemu_is_running() {
	[ -f "${PID_FILE}" ] || return 1
	local pid
	pid="$(cat "${PID_FILE}")"
	[ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null
}

kvm_args() {
	if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
		printf '%s\n' -enable-kvm
	fi
}

start_vm() {
	prepare
	if qemu_is_running; then
		log "QEMU already running with pid $(cat "${PID_FILE}")"
		return 0
	fi

	rm -f "${PID_FILE}"
	: > "${SERIAL_LOG}"
	log "Starting ${FOJI_BUILDER_ARCH} QEMU builder on SSH port ${FOJI_SSH_PORT}"

	case "${FOJI_BUILDER_ARCH}" in
		amd64)
			local code_fd=/usr/share/edk2/x64/OVMF_CODE.4m.fd
			local vars_template=/usr/share/edk2/x64/OVMF_VARS.4m.fd
			[ -r "${code_fd}" ] || die "Missing amd64 OVMF code firmware: ${code_fd}"
			[ -r "${vars_template}" ] || die "Missing amd64 OVMF vars firmware: ${vars_template}"
			[ -f "${VARS_FD}" ] || cp "${vars_template}" "${VARS_FD}"
			qemu-system-x86_64 \
				$(kvm_args) \
				-machine q35 \
				-cpu max \
				-smp "${FOJI_VM_CPUS}" \
				-m "${FOJI_VM_MEM}" \
				-drive if=pflash,format=raw,readonly=on,file="${code_fd}" \
				-drive if=pflash,format=raw,file="${VARS_FD}" \
				-drive if=none,id=hd0,file="${OVERLAY_IMAGE}",format=qcow2 \
				-device virtio-blk-pci,drive=hd0 \
				-drive if=none,id=cidata,file="${SEED_ISO}",media=cdrom,readonly=on \
				-device virtio-blk-pci,drive=cidata \
				-netdev user,id=net0,hostfwd=tcp:127.0.0.1:${FOJI_SSH_PORT}-:22 \
				-device virtio-net-pci,netdev=net0 \
				-serial "file:${SERIAL_LOG}" \
				-display none \
				-daemonize \
				-pidfile "${PID_FILE}"
			;;
		aarch64)
			local code_fd=/usr/share/edk2/aarch64/QEMU_EFI.fd
			local vars_template=/usr/share/edk2/aarch64/QEMU_VARS.fd
			[ -r "${code_fd}" ] || die "Missing aarch64 EDK2 code firmware: ${code_fd}"
			[ -r "${vars_template}" ] || die "Missing aarch64 EDK2 vars firmware: ${vars_template}"
			[ -f "${VARS_FD}" ] || cp "${vars_template}" "${VARS_FD}"
			qemu-system-aarch64 \
				-machine virt \
				-cpu cortex-a72 \
				-smp "${FOJI_VM_CPUS}" \
				-m "${FOJI_VM_MEM}" \
				-drive if=pflash,format=raw,readonly=on,file="${code_fd}" \
				-drive if=pflash,format=raw,file="${VARS_FD}" \
				-drive if=none,id=hd0,file="${OVERLAY_IMAGE}",format=qcow2 \
				-device virtio-blk-device,drive=hd0 \
				-drive if=none,id=cidata,file="${SEED_ISO}",media=cdrom,readonly=on \
				-device virtio-blk-device,drive=cidata \
				-netdev user,id=net0,hostfwd=tcp:127.0.0.1:${FOJI_SSH_PORT}-:22 \
				-device virtio-net-device,netdev=net0 \
				-serial "file:${SERIAL_LOG}" \
				-display none \
				-daemonize \
				-pidfile "${PID_FILE}"
			;;
	esac
}

wait_for_ssh() {
	log "Waiting for SSH"
	local deadline=$((SECONDS + 900))
	while [ "${SECONDS}" -lt "${deadline}" ]; do
		if nc -z 127.0.0.1 "${FOJI_SSH_PORT}" >/dev/null 2>&1; then
			if ssh $(ssh_opts) "$(ssh_target)" true >/dev/null 2>&1; then
				log "SSH is ready"
				return 0
			fi
		fi
		sleep 5
	done

	tail -n 80 "${SERIAL_LOG}" >&2 || true
	die "Timed out waiting for SSH. Serial log: ${SERIAL_LOG}"
}

stop_vm() {
	if ! qemu_is_running; then
		log "QEMU builder is not running"
		return 0
	fi
	log "Stopping QEMU builder"
	ssh $(ssh_opts) "$(ssh_target)" 'sudo -n shutdown -p now' >/dev/null 2>&1 || true
	local pid
	pid="$(cat "${PID_FILE}")"
	for _ in $(seq 1 60); do
		if ! kill -0 "${pid}" 2>/dev/null; then
			rm -f "${PID_FILE}"
			return 0
		fi
		sleep 2
	done
	kill "${pid}" 2>/dev/null || true
	rm -f "${PID_FILE}"
}

sync_repo() {
	wait_for_ssh
	log "Ensuring guest sync prerequisites"
	ssh $(ssh_opts) "$(ssh_target)" 'sudo -n env ASSUME_ALWAYS_YES=yes pkg bootstrap -f >/dev/null 2>&1 || true; sudo -n pkg install -y rsync'
	log "Syncing ports tree into VM"
	ssh $(ssh_opts) "$(ssh_target)" "mkdir -p $(shell_quote "${FOJI_REMOTE_DIR}")"
	rsync -az --delete \
		--exclude .git \
		--exclude .jj \
		--exclude repo-output \
		-e "ssh $(ssh_opts | tr '\n' ' ')" \
		"${REPO_ROOT}/" \
		"$(ssh_target):${FOJI_REMOTE_DIR}/"
}

build_repo() {
	ensure_signing_key
	sync_repo

	local env_file
	env_file="$(mktemp)"
	chmod 0600 "${env_file}"
	{
		write_env_line PKG_REPO_SIGNING_KEY_B64 "${PKG_REPO_SIGNING_KEY_B64}"
		write_env_line FREEBSD_RELEASE "${FREEBSD_RELEASE}"
		write_env_line FREEBSD_MAJOR "${FREEBSD_MAJOR}"
		write_env_line PKG_ABI "${PKG_ABI}"
		write_env_line POUDRIERE_ARCH "${POUDRIERE_ARCH}"
		write_env_line TARGET_ARCH "${TARGET_ARCH}"
		write_env_line JAIL_NAME "${JAIL_NAME}"
		write_env_line PORTS_TREE "${PORTS_TREE}"
		write_env_line PORTS_BRANCH "${PORTS_BRANCH}"
		write_env_line PORTS_REF "${PORTS_REF}"
		write_env_line SET_NAME "${SET_NAME}"
		write_env_line REQUESTED_PORTS "${REQUESTED_PORTS}"
		write_env_line REPO_PACKAGE_ORIGINS "${REPO_PACKAGE_ORIGINS}"
		write_env_line PACKAGE_FETCH_BRANCH "${PACKAGE_FETCH_BRANCH}"
		write_env_line PACKAGE_FETCH_URL "${PACKAGE_FETCH_URL}"
		write_env_line PACKAGE_FETCH_WHITELIST "${PACKAGE_FETCH_WHITELIST}"
		write_env_line POUDRIERE_BULK_FLAGS "${POUDRIERE_BULK_FLAGS}"
		write_env_line POUDRIERE_JAIL_FLAGS "${POUDRIERE_JAIL_FLAGS}"
		write_env_line REPO_OUT "${REPO_OUT}"
		write_env_line SIGNING_TYPE "${SIGNING_TYPE}"
	} > "${env_file}"

	log "Running poudriere build inside VM"
	scp $(scp_opts) "${env_file}" "$(ssh_target):${FOJI_REMOTE_DIR}/.foji-builder-env" >/dev/null
	rm -f "${env_file}"
	ssh $(ssh_opts) "$(ssh_target)" \
		"sudo -n sh -c 'cd $(shell_quote "${FOJI_REMOTE_DIR}") && trap \"rm -f .foji-builder-env\" EXIT && set -a && . ./.foji-builder-env && set +a && sh scripts/build-poudriere-repo.sh'"
}

fetch_repo() {
	wait_for_ssh
	log "Fetching repository output"
	mkdir -p "${REPO_ROOT}/repo-output"
	rsync -az --delete \
		-e "ssh $(ssh_opts | tr '\n' ' ')" \
		"$(ssh_target):${FOJI_REMOTE_DIR}/repo-output/" \
		"${REPO_ROOT}/repo-output/"
}

write_release_notes() {
	local repo_url
	repo_url="$(package_repo_url)"
	cat > "${REPO_ROOT}/release-notes.md" <<EOF
Last updated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

FreeBSD package repository for \`${PKG_ABI}\`.

## Usage

Install the foji public key on the target system through sysbsd, then add:

\`\`\`conf
foji: {
  url: "${repo_url}",
  mirror_type: "none",
  signature_type: "pubkey",
  pubkey: "/usr/local/etc/pkg/keys/foji.pub",
  enabled: yes
}
\`\`\`
EOF
}

write_repo_index() {
	local output_dir="$1"
	local repo_url
	repo_url="$(package_repo_url)"

	cat > "${output_dir}/index.html" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>foji-bsd ${PKG_ABI}</title>
</head>
<body>
  <h1>foji-bsd ${PKG_ABI}</h1>
  <p>This directory is a FreeBSD pkg repository.</p>
  <pre>foji: {
  url: "${repo_url}",
  mirror_type: "none",
  signature_type: "pubkey",
  pubkey: "/usr/local/etc/pkg/keys/foji.pub",
  enabled: yes
}</pre>
  <h2>Repository files</h2>
  <ul>
EOF

	(
		cd "${output_dir}"
		for file in *; do
			[ -f "${file}" ] || continue
			[ "${file}" != index.html ] || continue
			printf '%s\n' "${file}"
		done
	) |
		sort |
		while IFS= read -r file; do
			printf '    <li><a href="%s">%s</a></li>\n' "${file}" "${file}" >> "${output_dir}/index.html"
		done

	cat >> "${output_dir}/index.html" <<EOF
  </ul>
</body>
</html>
EOF
}

package_repo_url() {
	case "${RELEASE_TARGET}" in
		sourcehut-pages)
			printf 'https://%s%s' "${SOURCEHUT_PAGES_DOMAIN}" "${SOURCEHUT_PAGES_SUBDIR}"
			;;
		github)
			printf 'https://github.com/%s/releases/download/%s' "${GITHUB_REPOSITORY}" "${RELEASE_TAG}"
			;;
		*)
			die "Unsupported RELEASE_TARGET: ${RELEASE_TARGET}"
			;;
	esac
}

publish_github_release() {
	require_cmd gh
	local output_dir="${REPO_ROOT}/${REPO_OUT}"
	[ -d "${output_dir}" ] || die "Repository output directory does not exist: ${output_dir}"
	mapfile -t uploads < <(find "${output_dir}" -maxdepth 1 -type f -print | sort)
	[ "${#uploads[@]}" -gt 0 ] || die "No repository files to upload from ${output_dir}"
	write_release_notes
	log "Publishing ${RELEASE_TAG} to ${GITHUB_REPOSITORY}"
	if gh release view "${RELEASE_TAG}" --repo "${GITHUB_REPOSITORY}" >/dev/null 2>&1; then
		gh release edit "${RELEASE_TAG}" \
			--repo "${GITHUB_REPOSITORY}" \
			--title "Package Repository ${PKG_ABI}" \
			--notes-file "${REPO_ROOT}/release-notes.md"
	else
		gh release create "${RELEASE_TAG}" \
			--repo "${GITHUB_REPOSITORY}" \
			--title "Package Repository ${PKG_ABI}" \
			--notes-file "${REPO_ROOT}/release-notes.md"
	fi

	gh release upload "${RELEASE_TAG}" --repo "${GITHUB_REPOSITORY}" "${uploads[@]}" --clobber

	local current_assets
	current_assets="$(mktemp)"
	printf '%s\n' "${uploads[@]##*/}" > "${current_assets}"
	gh release view "${RELEASE_TAG}" --repo "${GITHUB_REPOSITORY}" --json assets -q '.assets[].name' |
		while IFS= read -r asset; do
			if ! grep -qxF "${asset}" "${current_assets}"; then
				log "Deleting obsolete release asset: ${asset}"
				gh release delete-asset "${RELEASE_TAG}" "${asset}" --repo "${GITHUB_REPOSITORY}" --yes
			fi
		done
	rm -f "${current_assets}"
}

publish_sourcehut_pages() {
	require_cmd hut
	require_cmd tar
	local output_dir="${REPO_ROOT}/${REPO_OUT}"
	[ -d "${output_dir}" ] || die "Repository output directory does not exist: ${output_dir}"
	if ! find "${output_dir}" -maxdepth 1 -type f -print -quit | grep -q .; then
		die "No repository files to publish from ${output_dir}"
	fi

	write_release_notes
	write_repo_index "${output_dir}"
	local tmpdir archive
	tmpdir="$(mktemp -d)"
	archive="${tmpdir}/repo.tar.gz"
	(
		cd "${output_dir}"
		tar -czf "${archive}" .
	)
	log "Publishing ${RELEASE_TAG} to SourceHut Pages at https://${SOURCEHUT_PAGES_DOMAIN}${SOURCEHUT_PAGES_SUBDIR}"
	hut pages publish \
		-d "${SOURCEHUT_PAGES_DOMAIN}" \
		--subdirectory "${SOURCEHUT_PAGES_SUBDIR}" \
		"${archive}"
	rm -rf "${tmpdir}"
}

publish_release() {
	case "${RELEASE_TARGET}" in
		sourcehut-pages)
			publish_sourcehut_pages
			;;
		github)
			publish_github_release
			;;
		*)
			die "Unsupported RELEASE_TARGET: ${RELEASE_TARGET}"
			;;
	esac
}

all() {
	start_vm
	build_repo
	fetch_repo
	if [ "${PUBLISH}" = yes ]; then
		publish_release
	else
		log "Skipping release upload because PUBLISH=${PUBLISH}"
	fi
}

usage() {
	cat <<EOF
Usage: $0 <command>

Commands:
  prepare   Download the cloud-init image, create the overlay, and create seed ISO
  reset     Stop the VM and remove generated builder state, preserving downloads
  start     Start the persistent QEMU builder VM
  wait      Wait until SSH is available
  sync      Rsync the ports tree into the VM
  build     Run poudriere build in the VM
  fetch     Fetch repo-output from the VM
  publish   Upload the fetched repository to RELEASE_TARGET
  all       start, build, fetch, and optionally publish when PUBLISH=yes
  stop      Shut down the VM

Important environment:
  FOJI_FORGE_DIR=${FOJI_FORGE_DIR}
  FOJI_BUILDER_ARCH=${FOJI_BUILDER_ARCH}
  FOJI_BUILD_PROFILE=${FOJI_BUILD_PROFILE}
  FOJI_VM_DISK_SIZE=${FOJI_VM_DISK_SIZE}
  FREEBSD_IMAGE_SHA512=${FREEBSD_IMAGE_SHA512}
  REQUESTED_PORTS=${REQUESTED_PORTS}
  REPO_PACKAGE_ORIGINS=${REPO_PACKAGE_ORIGINS}
  RELEASE_TARGET=${RELEASE_TARGET}
  SOURCEHUT_PAGES_DOMAIN=${SOURCEHUT_PAGES_DOMAIN}
  SOURCEHUT_PAGES_SUBDIR=${SOURCEHUT_PAGES_SUBDIR}
  PUBLISH=${PUBLISH}
EOF
}

command="${1:-}"
case "${command}" in
	prepare) prepare ;;
	reset) reset_builder ;;
	start) start_vm ;;
	wait) wait_for_ssh ;;
	sync) sync_repo ;;
	build) build_repo ;;
	fetch) fetch_repo ;;
	publish) publish_release ;;
	all) all ;;
	stop) stop_vm ;;
	"" | -h | --help | help) usage ;;
	*) usage >&2; exit 1 ;;
esac
