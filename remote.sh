#!/bin/sh
# {{SCRIPT}}
#
# Description:
#   Provision remote machines over SSH: copy herd to each host and run its
#   bootstrap.sh there, one host at a time. Hosts and their form factors come
#   from an inventory. The git identity and dotfiles repository are asked for
#   once, here, and passed to every host. A failed host does not stop the
#   others; a summary lists each host's result.
#
# Usage:
#   {{SCRIPT}} [-h] [-n] [-y] [-i INVENTORY] [--] [HOST...]
#
# Arguments:
#   HOST          Inventory hosts to provision (default: all of them)
#
# Options:
#   -h            Show this help message
#   -i INVENTORY  Inventory file (default: ~/.config/herd/inventory)
#   -n            Dry run on each host (herd is still copied to the host)
#   -y            Do not prompt: take the values from the environment
#
# Inventory:
#   One host per line: DESTINATION FORM_FACTOR. DESTINATION is anything ssh
#   accepts, such as user@host or a Host alias from ~/.ssh/config, and
#   FORM_FACTOR is desktop, laptop, or server. "#" starts a comment.
#
# Environment:
#   HERD_GIT_NAME       Git user.name (default: the current global value here)
#   HERD_GIT_EMAIL      Git user.email (default: the current global value here)
#   HERD_DOTFILES_REPO  Dotfiles repository URL; empty skips the dotfiles
#
# Requirements:
#   ssh and tar here; sh, tar, and doas or sudo on each host
#
# Exit codes:
#   0  Every host succeeded, or help displayed
#   1  At least one host failed
#   3  Invalid usage, a bad inventory, or a required value is missing

# ==== Constants ===============================================================
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# What a host needs to run bootstrap.sh, and where it goes (under its $HOME).
HERD_FILES="bootstrap.sh lib.sh list_pkgs.awk packages.tsv root"
REMOTE_DIR=.cache/herd

# ==== Parameters ==============================================================
inventory="${XDG_CONFIG_HOME:-$HOME/.config}/herd/inventory"
dry_run=false
prompt=true

# ==== Functions ===============================================================

# -------- Inventory -------------------
# Print the inventory as "DESTINATION FORM_FACTOR" lines, without comments and
# blank lines. Fails on a malformed line or an unknown form factor.
# $1: inventory file
read_inventory() {
	awk '
		{ sub(/\r$/, ""); sub(/#.*/, "") }
		NF == 0 { next }
		NF != 2 {
			printf "%s:%d: expected DESTINATION FORM_FACTOR\n", FILENAME, FNR > "/dev/stderr"
			bad = 1
			next
		}
		$2 !~ /^(desktop|laptop|server)$/ {
			printf "%s:%d: unknown form factor: %s\n", FILENAME, FNR, $2 > "/dev/stderr"
			bad = 1
			next
		}
		{ print $1, $2 }
		END { exit bad }
	' "$1"
}

# -------- Values ----------------------
# Set git_name, git_email, and dotfiles_repo from the environment, the git
# configuration here, and the answers to the prompts.
get_values() {
	git_name=${HERD_GIT_NAME:-$(git config --global user.name 2>/dev/null)}
	git_email=${HERD_GIT_EMAIL:-$(git config --global user.email 2>/dev/null)}
	dotfiles_repo=${HERD_DOTFILES_REPO-}

	if [ "$prompt" = true ]; then
		ask_required git_name "Git user name" "$git_name" || return 1
		ask_required git_email "Git user email" "$git_email" || return 1
		ask dotfiles_repo \
			"Dotfiles repository for hosts without ~/dotfiles (empty to skip)" \
			"$dotfiles_repo" || return 1
	fi

	if [ -z "$git_name" ] || [ -z "$git_email" ]; then
		error "Set HERD_GIT_NAME and HERD_GIT_EMAIL, or run without -y."
		return 1
	fi
}

# -------- Hosts -----------------------
# ssh, sharing one connection per host, so a host asks for a password once.
ssh_host() {
	ssh -o ControlMaster=auto -o "ControlPath=$HOME/.ssh/herd-%C" \
		-o ControlPersist=60 "$@"
}

# Copy herd to a host, then run bootstrap.sh there.
# $1: ssh destination; $2: form factor
provision_host() {
	info "Copying herd to '$1'..."
	# shellcheck disable=SC2086 # split intended: one file name per word
	tar -C "$SCRIPT_DIR" -cf - $HERD_FILES |
		ssh_host -T "$1" "rm -rf $REMOTE_DIR && mkdir -p $REMOTE_DIR &&
			tar -xf - -C $REMOTE_DIR" || return

	bootstrap_options=-y
	[ "$dry_run" = true ] && bootstrap_options="$bootstrap_options -n"
	remote_command="cd $REMOTE_DIR && env \
HERD_GIT_NAME=$(quote_args "$git_name") \
HERD_GIT_EMAIL=$(quote_args "$git_email") \
HERD_DOTFILES_REPO=$(quote_args "$dotfiles_repo") \
sh bootstrap.sh $bootstrap_options -- $2"

	# A terminal lets doas or sudo ask for a password on the host.
	if [ -t 0 ] && [ -t 1 ]; then
		terminal=-t
	else
		terminal=-T
	fi
	info "Running bootstrap.sh on '$1' as a $2..."
	ssh_host "$terminal" "$1" "$remote_command"
}

# ==== Main ====================================================================
# ---- Options -------------------------
while getopts ':hi:ny' opt; do
	case $opt in
	h)
		usage
		exit 0
		;;
	i) inventory=$OPTARG ;;
	n) dry_run=true ;;
	y) prompt=false ;;
	:)
		error "Option -$OPTARG needs a value."
		usage >&2
		exit 3
		;;
	*)
		error "Unknown option: -$OPTARG"
		usage >&2
		exit 3
		;;
	esac
done
shift "$((OPTIND - 1))"

# ---- Inventory -----------------------
if [ ! -r "$inventory" ]; then
	error "Cannot read the inventory '$inventory'."
	exit 3
fi
hosts=$(read_inventory "$inventory") || exit 3
if [ -z "$hosts" ]; then
	error "The inventory '$inventory' lists no hosts."
	exit 3
fi

# Keep only the hosts named on the command line, in inventory order.
if [ "$#" -gt 0 ]; then
	for host; do
		if ! printf '%s\n' "$hosts" | grep -q -- "^$host "; then
			error "Host '$host' is not in the inventory '$inventory'."
			exit 3
		fi
	done
	hosts=$(printf '%s\n' "$hosts" | while read -r destination form_factor; do
		for host; do
			if [ "$destination" = "$host" ]; then
				printf '%s %s\n' "$destination" "$form_factor"
			fi
		done
	done)
fi

# ---- Values --------------------------
# Ask everything up front, so the hosts run without input except passwords.
get_values || exit 3

# ---- Provision -----------------------
# A for loop, not "while read": ssh would read the rest of the list from
# stdin, which must stay the terminal for password prompts.
results=""
failed=0
old_ifs=$IFS
IFS='
'
for line in $hosts; do
	IFS=$old_ifs
	destination=${line% *}
	form_factor=${line##* }
	if provision_host "$destination" "$form_factor"; then
		results="${results}OK      $destination ($form_factor)
"
	else
		status=$?
		results="${results}FAILED  $destination ($form_factor), status $status
"
		failed=$((failed + 1))
		error "'$destination' failed; continuing with the next host."
	fi
done
IFS=$old_ifs

info "Summary:"
printf '%s' "$results"
if [ "$failed" -gt 0 ]; then
	error "$failed host(s) failed. Fix them and run again for those hosts."
	exit 1
fi
info "Done."
