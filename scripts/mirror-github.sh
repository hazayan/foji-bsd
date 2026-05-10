#!/usr/bin/env bash
set -euo pipefail

GITHUB_MIRROR_URL="${GITHUB_MIRROR_URL:-git@github.com:hazayan/foji-bsd.git}"
GITHUB_MIRROR_BRANCH="${GITHUB_MIRROR_BRANCH:-main}"

die() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

git diff --quiet || die "Working tree has unstaged changes"
git diff --cached --quiet || die "Index has staged changes"

# Run this manually on the agreed weekly cadence. Keep GitHub an exact
# read-only mirror of the SourceHut history. Rewriting
# commit timestamps would create different object IDs and break provenance
# between the primary source and its mirror.
git fetch zung "${GITHUB_MIRROR_BRANCH}"
git push "${GITHUB_MIRROR_URL}" "refs/remotes/zung/${GITHUB_MIRROR_BRANCH}:refs/heads/${GITHUB_MIRROR_BRANCH}"
git push "${GITHUB_MIRROR_URL}" --tags
