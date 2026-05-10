#!/usr/bin/env bash
set -euo pipefail

arch="${1:-all}"
ports_branch="${PORTS_BRANCH:-2026Q2}"
ports_remote="${PORTS_REMOTE:-https://git.FreeBSD.org/ports.git}"
validation_profile="${VALIDATION_PROFILE:-kunci}"
selected_arches=""

pin_for_arch() {
	case "$1" in
		amd64)
			printf '%s\n' f724b00b1bf27db4605258801fbe8f21a537178a
			;;
		aarch64)
			printf '%s\n' f724b00b1bf27db4605258801fbe8f21a537178a
			;;
		*)
			printf 'unsupported arch: %s\n' "$1" >&2
			return 2
			;;
	esac
}

arches_for_arg() {
	case "$1" in
		all)
			printf '%s\n' amd64 aarch64
			;;
		amd64 | aarch64)
			printf '%s\n' "$1"
			;;
		*)
			printf 'Usage: %s [all|amd64|aarch64]\n' "$0" >&2
			exit 2
			;;
	esac
}

selected_arches="$(arches_for_arg "${arch}")"

if ! branch_line="$(git ls-remote "${ports_remote}" "refs/heads/${ports_branch}")"; then
	printf 'Could not query %s from %s\n' "${ports_branch}" "${ports_remote}" >&2
	exit 1
fi
branch_head="$(printf '%s\n' "${branch_line}" | awk '{ print $1 }')"
[ -n "${branch_head}" ] || {
	printf 'Could not resolve %s from %s\n' "${ports_branch}" "${ports_remote}" >&2
	exit 1
}

printf 'ports_remote  %s\n' "${ports_remote}"
printf 'ports_branch  %s\n' "${ports_branch}"
printf 'candidate     %s\n' "${branch_head}"
printf '\n'

printf '%s\n' "${selected_arches}" | while IFS= read -r selected_arch; do
	current_pin="$(pin_for_arch "${selected_arch}")"
	status=behind
	if [ "${current_pin}" = "${branch_head}" ]; then
		status=current
	fi

	printf '%s\n' "${selected_arch}"
	printf '  current_pin %s\n' "${current_pin}"
	printf '  candidate   %s\n' "${branch_head}"
	printf '  status      %s\n' "${status}"
	printf '  validate    FOJI_BUILDER_ARCH=%s FOJI_BUILD_PROFILE=%s PORTS_REF=%s PUBLISH=no scripts/native-freebsd-build.sh build\n' \
		"${selected_arch}" \
		"${validation_profile}" \
		"${branch_head}"
	printf '\n'
done

printf 'This is a dry run. After validation passes, update PORTS_REF defaults in scripts/local-qemu-build.sh and scripts/native-freebsd-build.sh.\n'
