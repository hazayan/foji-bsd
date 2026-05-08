#!/usr/bin/env bash
set -euo pipefail

FOJI_BUILDER_ARCH="${FOJI_BUILDER_ARCH:-amd64}"

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
check_cmd genisoimage
check_cmd hut
check_cmd nc
check_cmd qemu-img
check_cmd rsync
check_cmd scp
check_cmd sha512sum
check_cmd ssh
check_cmd tar
check_cmd xz

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

exit "${missing}"
