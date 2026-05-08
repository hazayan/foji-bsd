#!/usr/bin/env bash
set -euo pipefail

ports_branch="${PORTS_BRANCH:-2026Q2}"
ports_remote="${PORTS_REMOTE:-https://git.FreeBSD.org/ports.git}"

pin_for_arch() {
	case "$1" in
		amd64)
			printf '%s\n' 7c7fc885b5f45096bd3fdad6ac1c43715111a4ef
			;;
		aarch64)
			printf '%s\n' 52322f7d7b98a6556700411ffdccbe2473fd1386
			;;
		*)
			printf 'unsupported arch: %s\n' "$1" >&2
			return 2
			;;
	esac
}

branch_head="$(git ls-remote "${ports_remote}" "refs/heads/${ports_branch}" | awk '{ print $1 }')"
[ -n "${branch_head}" ] || {
	printf 'Could not resolve %s from %s\n' "${ports_branch}" "${ports_remote}" >&2
	exit 1
}

printf 'ports_branch %s\n' "${ports_branch}"
printf 'branch_head  %s\n' "${branch_head}"
for arch in amd64 aarch64; do
	pin="$(pin_for_arch "${arch}")"
	status=behind
	if [ "${pin}" = "${branch_head}" ]; then
		status=current
	fi
	printf '%-12s %s %s\n' "${arch}" "${pin}" "${status}"
done
