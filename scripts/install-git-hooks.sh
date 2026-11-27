#!/bin/sh
# {{SCRIPT}}
#
# Description:
#   Install this repository's git hooks by pointing core.hooksPath at the
#   tracked scripts/githooks directory. Hooks added, removed, or changed there
#   are picked up without re-running this script. In a linked worktree the
#   setting is stored per worktree.
#
# Usage:
#   {{SCRIPT}} [-h]
#
# Options:
#   -h         Show this help message
#
# Requirements:
#   POSIX sh, sed, basename, and git
#
# Exit codes:
#   0  Success, help displayed, or skipped (no git or not a repository)
#   1  Invalid usage

usage() {
	sed -n '2,/^$/s/^#[[:space:]]\{0,1\}//p' "$0" |
		sed "s/{{SCRIPT}}/$(basename "$0")/g"
}

# ---- Options -----------------------------------------------------------------

while getopts ':h' opt; do
	case $opt in
	h)
		usage
		exit 0
		;;
	*)
		echo "⛔ Unknown option: -$OPTARG" >&2
		usage >&2
		exit 1
		;;
	esac
done
shift "$((OPTIND - 1))"

if [ "$#" -gt 0 ]; then
	echo "⛔ Unexpected argument: $1" >&2
	usage >&2
	exit 1
fi

# ---- Validation --------------------------------------------------------------

# Hooks are a convenience: skip quietly instead of failing callers such as
# `make setup` when git or a repository is unavailable.
if ! command -v git >/dev/null 2>&1; then
	echo '⚠️  git is not installed; skipping hook installation' >&2
	exit 0
fi

script_dir=$(cd -P -- "$(dirname -- "$0")" && pwd)
if ! git -C "$script_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo '⚠️  Not inside a git repository; skipping hook installation' >&2
	exit 0
fi

# ---- Main workflow -----------------------------------------------------------

# A relative core.hooksPath resolves against the working tree root, so the
# setting survives moving or re-cloning the repository.
hooks_path=scripts/githooks

# Git reports some paths relative to the current directory; run from here.
cd -- "$script_dir" || exit 1

# A linked worktree has its own git dir, distinct from the shared common dir.
git_dir=$(git rev-parse --absolute-git-dir)
common_dir=$(cd -P -- "$(git rev-parse --git-common-dir)" && pwd)

if [ "$git_dir" != "$common_dir" ]; then
	git config extensions.worktreeConfig true
	git config --worktree core.hooksPath "$hooks_path"
else
	git config core.hooksPath "$hooks_path"
fi

echo "🪝 Git hooks path set to: $hooks_path"
