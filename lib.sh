#!/bin/sh
# Shared helpers for herd's scripts: colored status lines, shell quoting,
# prompts, and the help text. Sourced, not run.

# Escape Colors
ESC="\033"
RESET="${ESC}[0m"
FG_RED="${ESC}[91m"
FG_YELLOW="${ESC}[93m"
FG_BLUE="${ESC}[94m"
FG_MAGENTA="${ESC}[95m"
# shellcheck disable=SC2034 # used by the scripts that source this file
FG_CYAN="${ESC}[96m"

# -------- Status ----------------------
HERD_PREFIX="${FG_MAGENTA}herd | ${RESET}"
info() { printf "${HERD_PREFIX}${FG_BLUE}%-8s$RESET: %s\n" "Info" "$*"; }
warning() { printf "${HERD_PREFIX}${FG_YELLOW}%-8s$RESET: %s\n" "Warning" "$*"; }
error() { printf "${HERD_PREFIX}${FG_RED}%-8s$RESET: %s\n" "Error" "$*" >&2; }

# -------- Commands --------------------
# Print the arguments as shell words, quoting those that need it.
quote_args() {
	quoted=""
	for arg; do
		case $arg in
		'' | *[!A-Za-z0-9_./:=@%+,-]*)
			arg="'$(printf '%s' "$arg" | sed "s/'/'\\\\''/g")'"
			;;
		esac
		quoted="$quoted $arg"
	done
	printf '%s' "${quoted# }"
}

# -------- Values ----------------------
# Ask for a value on the terminal, keeping the default on an empty answer.
# Fails when input ends, so a closed stdin cannot loop forever.
# $1: variable to set; $2: question; $3: default
ask() {
	if [ -n "$3" ]; then
		printf '%s [%s]: ' "$2" "$3" >&2
	else
		printf '%s: ' "$2" >&2
	fi
	# shellcheck disable=SC2034 # answer is read by the eval below
	IFS= read -r answer || return 1
	eval "$1=\${answer:-\$3}"
}

# Ask until the answer is not empty.
# $1: variable to set; $2: question; $3: default
ask_required() {
	while :; do
		ask "$@" || return 1
		eval "value=\$$1"
		[ -n "$value" ] && return 0
		warning "A value is required."
	done
}

# -------- Usage -----------------------
usage() {
	sed -n '2,/^$/s/^#[[:space:]]\{0,1\}//p' "$0" |
		sed "s/{{SCRIPT}}/$(basename "$0")/g"
}
