#!/bin/sh
# {{SCRIPT}}
#
# Description:
#   Smoke test a herd machine: check that the expected commands exist.
#
# Usage:
#   {{SCRIPT}} [-h]
#
# Options:
#   -h         Show this help message
#
# Requirements:
#   POSIX sh, sed, and basename; uses ~/lib/sh/log.sh when present
#
# Exit codes:
#   0  All commands found, or help displayed
#   1  Invalid usage, or a command is missing

usage() {
	sed -n '2,/^$/s/^#[[:space:]]\{0,1\}//p' "$0" |
		sed "s/{{SCRIPT}}/$(basename "$0")/g"
}

#---- Options ------------------------------------------------------------------
while getopts ':h' opt; do
	case $opt in
	h)
		usage
		exit 0
		;;
	*)
		printf 'Unknown option: -%s\n' "$OPTARG" >&2
		usage >&2
		exit 1
		;;
	esac
done
shift "$((OPTIND - 1))"

if [ "$#" -gt 0 ]; then
	printf 'Expected no arguments\n' >&2
	usage >&2
	exit 1
fi

#---- Includes -----------------------------------------------------------------
# Use status() from the dotfiles' log.sh, or a plain one. Call it directly:
# log.sh's success and failure are aliases, which sh scripts may not expand.
log_lib="$HOME/lib/sh/log.sh"
if [ -f "$log_lib" ]; then
	# shellcheck source=/dev/null
	. "$log_lib"
else
	status() {
		msg_type=$1
		shift
		printf '%-8s | %s\n' "$msg_type" "$*"
	}
fi
#---- Parameters ---------------------------------------------------------------
cmd_list=$(
	cat <<__EOF
ssh
git
__EOF
)

#---- Main ---------------------------------------------------------------------
status=0
for cmd in $cmd_list; do
	if command -v "$cmd" >/dev/null 2>&1; then
		status SUCCESS "Found command $cmd"
	else
		status FAILURE "Unable to find command $cmd"
		status=1
	fi
done
exit "$status"
