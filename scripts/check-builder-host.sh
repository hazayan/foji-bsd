#!/usr/bin/env bash
set -euo pipefail

FOJI_BUILDER_ARCH="${FOJI_BUILDER_ARCH:-amd64}"
FOJI_BUILDER_MODE="${FOJI_BUILDER_MODE:-qemu}"

missing=0

check_cmd() {
	local cmd="$1"
	if command -v "${cmd}" >/dev/null 2>&1; then
		printf 'ok   command %s\n' "${cmd}"
	else
		printf 'miss command %s\n' "${cmd}"
		missing=1
	fi
}

check_path() {
	local path="$1"
	if [ -r "${path}" ]; then
		printf 'ok   path %s\n' "${path}"
	else
		printf 'miss path %s\n' "${path}"
		missing=1
	fi
}

check_cmd curl
check_cmd git
check_cmd hut
check_cmd rsync
check_cmd ssh
check_cmd tar
check_cmd xz

case "${FOJI_BUILDER_MODE}" in
	qemu)
		check_cmd genisoimage
		check_cmd nc
		check_cmd qemu-img
		check_cmd scp
		if command -v sha512sum >/dev/null 2>&1 || command -v sha512 >/dev/null 2>&1; then
			printf 'ok   command sha512 verifier\n'
		else
			printf 'miss command sha512sum or sha512\n'
			missing=1
		fi

		case "${FOJI_BUILDER_ARCH}" in
			amd64)
				check_cmd qemu-system-x86_64
				check_path /usr/share/edk2/x64/OVMF_CODE.4m.fd
				check_path /usr/share/edk2/x64/OVMF_VARS.4m.fd
				;;
			aarch64)
				check_cmd qemu-system-aarch64
				check_path /usr/share/edk2/aarch64/QEMU_EFI.fd
				check_path /usr/share/edk2/aarch64/QEMU_VARS.fd
				;;
			*)
				printf 'Unsupported FOJI_BUILDER_ARCH: %s\n' "${FOJI_BUILDER_ARCH}" >&2
				exit 2
				;;
		esac

		if [ -e /dev/kvm ]; then
			if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
				printf 'ok   path /dev/kvm\n'
			else
				printf 'miss writable /dev/kvm\n'
				missing=1
			fi
		else
			printf 'warn path /dev/kvm not present; QEMU will run without KVM acceleration\n'
		fi

		if pgrep -af 'VBoxHeadless|VirtualBoxVM' >/dev/null 2>&1; then
			printf 'warn active VirtualBox VM detected; QEMU KVM creation may fail\n'
		fi
		;;
	native-freebsd)
		if [ "$(uname -s)" = FreeBSD ]; then
			printf 'ok   host FreeBSD\n'
		else
			printf 'miss host FreeBSD\n'
			missing=1
		fi
		check_cmd openssl
		check_cmd pkg
		check_cmd poudriere
		check_cmd realpath
		check_cmd sudo
		if [ "${FOJI_BUILDER_ARCH}" != amd64 ]; then
			check_cmd qemu-aarch64-static
		fi
		;;
	*)
		printf 'Unsupported FOJI_BUILDER_MODE: %s\n' "${FOJI_BUILDER_MODE}" >&2
		exit 2
		;;
esac

exit "${missing}"
