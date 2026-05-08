#!/usr/bin/env bash
set -euo pipefail

base="${1:-${CHANGED_SINCE:-zung/main}}"

if ! git rev-parse --verify "${base}" >/dev/null 2>&1; then
	printf 'Unknown base revision for changed-port detection: %s\n' "${base}" >&2
	exit 2
fi

{
	git diff --name-only --diff-filter=ACMRT "${base}"...HEAD
	git diff --name-only --diff-filter=ACMRT
	git diff --cached --name-only --diff-filter=ACMRT
} |
	awk -F/ 'NF >= 3 { print $1 "/" $2 }' |
	while IFS= read -r origin; do
		if [ -f "${origin}/Makefile" ]; then
			printf '%s\n' "${origin}"
		fi
	done |
	sort -u
