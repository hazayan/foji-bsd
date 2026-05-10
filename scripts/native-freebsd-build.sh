#!/usr/bin/env bash
set -euo pipefail

FREEBSD_RELEASE="${FREEBSD_RELEASE:-15.0-RELEASE}"
FREEBSD_MAJOR="${FREEBSD_MAJOR:-15}"
FOJI_BUILDER_ARCH="${FOJI_BUILDER_ARCH:-amd64}"
FOJI_BUILD_PROFILE="${FOJI_BUILD_PROFILE:-foji-amd64}"
REQUESTED_PORTS="${REQUESTED_PORTS:-auto}"
REPO_PACKAGE_ORIGINS="${REPO_PACKAGE_ORIGINS:-}"
PACKAGE_FETCH_BRANCH="${PACKAGE_FETCH_BRANCH:-quarterly}"
PACKAGE_FETCH_URL="${PACKAGE_FETCH_URL:-}"
PACKAGE_FETCH_WHITELIST="${PACKAGE_FETCH_WHITELIST:-}"
POUDRIERE_BULK_FLAGS="${POUDRIERE_BULK_FLAGS:--v}"
POUDRIERE_JAIL_FLAGS="${POUDRIERE_JAIL_FLAGS:--X}"
PORTS_BRANCH="${PORTS_BRANCH:-2026Q2}"
PORTS_REF="${PORTS_REF:-}"
PORTS_TREE="${PORTS_TREE:-foji}"
SET_NAME="${SET_NAME:-default}"
SIGNING_TYPE="${SIGNING_TYPE:-ecdsa}"
RELEASE_TARGET="${RELEASE_TARGET:-sourcehut-pages}"
PUBLISH="${PUBLISH:-no}"
POUDRIERE_BASE="${POUDRIERE_BASE:-/usr/local/poudriere}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

case "${FOJI_BUILDER_ARCH}" in
	amd64)
		PKG_ABI="${PKG_ABI:-FreeBSD:${FREEBSD_MAJOR}:amd64}"
		POUDRIERE_ARCH="${POUDRIERE_ARCH:-amd64}"
		TARGET_ARCH="${TARGET_ARCH:-amd64}"
		JAIL_NAME="${JAIL_NAME:-freebsd${FREEBSD_MAJOR}-amd64}"
		PORTS_REF="${PORTS_REF:-f724b00b1bf27db4605258801fbe8f21a537178a}"
		;;
	aarch64)
		PKG_ABI="${PKG_ABI:-FreeBSD:${FREEBSD_MAJOR}:aarch64}"
		POUDRIERE_ARCH="${POUDRIERE_ARCH:-arm64.aarch64}"
		TARGET_ARCH="${TARGET_ARCH:-aarch64}"
		JAIL_NAME="${JAIL_NAME:-freebsd${FREEBSD_MAJOR}-aarch64}"
		PORTS_REF="${PORTS_REF:-f724b00b1bf27db4605258801fbe8f21a537178a}"
		;;
	*)
		printf 'Unsupported FOJI_BUILDER_ARCH: %s\n' "${FOJI_BUILDER_ARCH}" >&2
		exit 2
		;;
esac

case "${FOJI_BUILD_PROFILE}" in
	"")
		;;
	kunci)
		REQUESTED_PORTS="kunci"
		REPO_PACKAGE_ORIGINS="sysutils/kunci"
		;;
	sysbsd-amd64)
		[ "${FOJI_BUILDER_ARCH}" = amd64 ] || {
			printf 'FOJI_BUILD_PROFILE=sysbsd-amd64 requires FOJI_BUILDER_ARCH=amd64\n' >&2
			exit 2
		}
		REQUESTED_PORTS="kunci zhamel zhamel-zfskey-kmod"
		REPO_PACKAGE_ORIGINS="sysutils/kunci sysutils/zhamel sysutils/zhamel-zfskey-kmod"
		;;
	foji-amd64)
		[ "${FOJI_BUILDER_ARCH}" = amd64 ] || {
			printf 'FOJI_BUILD_PROFILE=foji-amd64 requires FOJI_BUILDER_ARCH=amd64\n' >&2
			exit 2
		}
		REQUESTED_PORTS="kunci zhamel zhamel-zfskey-kmod manticore nomad-pot-driver knox"
		REPO_PACKAGE_ORIGINS="sysutils/kunci sysutils/zhamel sysutils/zhamel-zfskey-kmod databases/manticore sysutils/nomad-pot-driver security/knox"
		;;
	manticore-amd64)
		[ "${FOJI_BUILDER_ARCH}" = amd64 ] || {
			printf 'FOJI_BUILD_PROFILE=manticore-amd64 requires FOJI_BUILDER_ARCH=amd64\n' >&2
			exit 2
		}
		REQUESTED_PORTS="manticore"
		REPO_PACKAGE_ORIGINS="databases/manticore"
		;;
	changed)
		REQUESTED_PORTS="$("${SCRIPT_DIR}/list-changed-ports.sh")"
		[ -n "${REQUESTED_PORTS}" ] || {
			printf 'No changed custom ports found. Set CHANGED_SINCE or REQUESTED_PORTS explicitly.\n' >&2
			exit 2
		}
		REPO_PACKAGE_ORIGINS="${REPO_PACKAGE_ORIGINS:-${REQUESTED_PORTS}}"
		;;
	*)
		printf 'Unsupported FOJI_BUILD_PROFILE: %s\n' "${FOJI_BUILD_PROFILE}" >&2
		exit 2
		;;
esac

REPO_OUT="${REPO_OUT:-repo-output/${PKG_ABI}}"

run_build() {
	[ "$(uname -s)" = FreeBSD ] || {
		printf 'Native builder must run on FreeBSD.\n' >&2
		exit 2
	}
	[ -n "${PKG_REPO_SIGNING_KEY_B64:-}" ] || {
		printf 'PKG_REPO_SIGNING_KEY_B64 must be set.\n' >&2
		exit 2
	}

	sudo -n env \
		PKG_REPO_SIGNING_KEY_B64="${PKG_REPO_SIGNING_KEY_B64}" \
		FREEBSD_RELEASE="${FREEBSD_RELEASE}" \
		FREEBSD_MAJOR="${FREEBSD_MAJOR}" \
		PKG_ABI="${PKG_ABI}" \
		POUDRIERE_ARCH="${POUDRIERE_ARCH}" \
		TARGET_ARCH="${TARGET_ARCH}" \
		JAIL_NAME="${JAIL_NAME}" \
		PORTS_TREE="${PORTS_TREE}" \
		PORTS_BRANCH="${PORTS_BRANCH}" \
		PORTS_REF="${PORTS_REF}" \
		SET_NAME="${SET_NAME}" \
		REQUESTED_PORTS="${REQUESTED_PORTS}" \
		REPO_PACKAGE_ORIGINS="${REPO_PACKAGE_ORIGINS}" \
		PACKAGE_FETCH_BRANCH="${PACKAGE_FETCH_BRANCH}" \
		PACKAGE_FETCH_URL="${PACKAGE_FETCH_URL}" \
		PACKAGE_FETCH_WHITELIST="${PACKAGE_FETCH_WHITELIST}" \
		POUDRIERE_BULK_FLAGS="${POUDRIERE_BULK_FLAGS}" \
		POUDRIERE_JAIL_FLAGS="${POUDRIERE_JAIL_FLAGS}" \
		POUDRIERE_BASE="${POUDRIERE_BASE}" \
		REPO_OUT="${REPO_OUT}" \
		SIGNING_TYPE="${SIGNING_TYPE}" \
		sh "${SCRIPT_DIR}/build-poudriere-repo.sh" all
}

publish_repo() {
	FOJI_BUILDER_ARCH="${FOJI_BUILDER_ARCH}" \
	RELEASE_TARGET="${RELEASE_TARGET}" \
	REPO_OUT="${REPO_OUT}" \
	PUBLISH=yes \
	"${SCRIPT_DIR}/local-qemu-build.sh" publish
}

usage() {
	cat <<EOF
Usage: $0 <command>

Commands:
  check    Validate the native FreeBSD host prerequisites
  build    Run poudriere directly on the FreeBSD host
  publish  Publish existing repo-output through RELEASE_TARGET
  all      Run build, then publish when PUBLISH=yes

Important environment:
  FOJI_BUILDER_ARCH=${FOJI_BUILDER_ARCH}
  FOJI_BUILD_PROFILE=${FOJI_BUILD_PROFILE}
  POUDRIERE_BASE=${POUDRIERE_BASE}
  REQUESTED_PORTS=${REQUESTED_PORTS}
  REPO_PACKAGE_ORIGINS=${REPO_PACKAGE_ORIGINS}
  RELEASE_TARGET=${RELEASE_TARGET}
  PUBLISH=${PUBLISH}
EOF
}

case "${1:-help}" in
	check)
		FOJI_BUILDER_MODE=native-freebsd FOJI_BUILDER_ARCH="${FOJI_BUILDER_ARCH}" "${SCRIPT_DIR}/check-builder-host.sh"
		;;
	build)
		run_build
		;;
	publish)
		publish_repo
		;;
	all)
		run_build
		if [ "${PUBLISH}" = yes ]; then
			publish_repo
		else
			printf '\n==> Skipping publication because PUBLISH=%s\n' "${PUBLISH}"
		fi
		;;
	"" | -h | --help | help)
		usage
		;;
	*)
		usage >&2
		exit 2
		;;
esac
