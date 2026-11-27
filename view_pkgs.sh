#!/bin/sh
# {{SCRIPT}}
#
# Description:
#   Print the tab-separated package table with aligned columns.
#
# Usage:
#   {{SCRIPT}} [-h] [--] [file]
#
# Arguments:
#   file       Package table to view (default: standard input)
#
# Options:
#   -h         Show this help message
#
# Requirements:
#   POSIX sh, sed, basename, and column
#
# Exit codes:
#   0  Success or help displayed
#   1  Invalid usage
#   2  The file cannot be read

usage() {
	sed -n '2,/^$/s/^#[[:space:]]\{0,1\}//p' "$0" |
		sed "s/{{SCRIPT}}/$(basename "$0")/g"
}

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

if [ "$#" -gt 1 ]; then
	printf 'Expected at most one file\n' >&2
	usage >&2
	exit 1
fi

input=${1:-/dev/stdin}
if [ ! -r "$input" ]; then
	printf 'Cannot read: %s\n' "$input" >&2
	exit 2
fi

column -t -s "$(printf '\t')" <"$input"
