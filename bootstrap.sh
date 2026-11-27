#!/bin/sh
# {{SCRIPT}}
#
# Description:
#   Bootstrap a machine with herd: clone the dotfiles into ~/dotfiles and link
#   them into $HOME, install the packages for its form factor, install the
#   system files from root/, configure git, and set zsh as the login shell.
#   Safe to run again.
#
#   The package table is ~/.config/herd/packages.tsv when the dotfiles provide
#   one, and herd's packages.tsv otherwise.
#   A dry run prints the commands that would change the system instead.
#
#   It asks for the git identity and the dotfiles repository before changing
#   anything; the environment variables below are the defaults. The
#   repository is asked for only when ~/dotfiles does not exist yet.
#
# Usage:
#   {{SCRIPT}} [-h] [-n] [-y] [--] FORM_FACTOR
#
# Arguments:
#   FORM_FACTOR  Machine form factor: desktop, laptop, or server
#
# Options:
#   -h           Show this help message
#   -n           Dry run: print the commands that change the system
#   -y           Do not prompt: take the values from the environment
#
# Environment:
#   HERD_GIT_NAME       Git user.name (default: the current global value)
#   HERD_GIT_EMAIL      Git user.email (default: the current global value)
#   HERD_DOTFILES_REPO  Dotfiles repository URL; empty skips the dotfiles
#
# Requirements:
#   Arch Linux, Void Linux, or OpenBSD; doas or sudo; an SSH key with access
#   to the upkg and dotfiles repos
#
# Exit codes:
#   0  Success or help displayed
#   1  Unsupported OS, or a step failed (the run stops at the first failure;
#      fix it and run again: completed steps are skipped)
#   2  No doas or sudo found
#   3  Invalid usage, or a required value is missing

# ==== Parameters ==============================================================
# Defaults
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
DOTFILES_DIR="$HOME/dotfiles"
UPKG_REPO="git@github.com:sobh/upkg"

OS=""
DOAS=""
dry_run=false
prompt=true

BASE_PKGS="git"
ARCH_PKGS="openssh fakeroot"
ARCH_AUR_HELPER="yay-bin"

# ==== Constants ===============================================================
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$SCRIPT_DIR/lib.sh"
REPOS_DIR="$HOME/repos"
PERSONAL_REPOS="$REPOS_DIR/$(whoami)"

SUPPORTED_DOAS="doas, sudo"
SUPPORTED_OS="Alpine Linux, Arch Linux, Void Linux, OpenBSD"
SUPPORTED_FF="desktop, laptop, server"

# ==== Functions ===============================================================

# -------- Commands --------------------

# Stop the run after a failed command. Every step is safe to repeat, so the
# next run picks up where this one stopped.
# $1: exit status; $2: the command, as shell words
fail() {
	error "Failed with status $1: $2"
	error "Fix the problem and run again; completed steps are skipped."
	exit 1
}

# Run a command that changes the system; in a dry run, only print it. A
# failure stops the run.
run() {
	if [ "$dry_run" = true ]; then
		printf "${HERD_PREFIX}${FG_CYAN}%-8s$RESET: %s\n" "Dry run" "$(quote_args "$@")"
		return 0
	fi
	"$@" || fail "$?" "$(quote_args "$@")"
}

# Run a command in a directory, like run.
# $1: directory; remaining arguments: the command
run_in() {
	dir=$1
	shift
	if [ "$dry_run" = true ]; then
		printf "${HERD_PREFIX}${FG_CYAN}%-8s$RESET: %s\n" "Dry run" \
			"cd $(quote_args "$dir") && $(quote_args "$@")"
		return 0
	fi
	(cd "$dir" && "$@") || fail "$?" "cd $(quote_args "$dir") && $(quote_args "$@")"
}

# -------- Values ----------------------

# Set git_name, git_email, and dotfiles_repo from the environment, the
# current git configuration, and the answers to the prompts.
get_values() {
	git_name=${HERD_GIT_NAME:-$(git config --global user.name 2>/dev/null)}
	git_email=${HERD_GIT_EMAIL:-$(git config --global user.email 2>/dev/null)}
	dotfiles_repo=${HERD_DOTFILES_REPO-}

	if [ "$prompt" = true ]; then
		ask_required git_name "Git user name" "$git_name" || return 1
		ask_required git_email "Git user email" "$git_email" || return 1
		if [ ! -e "$DOTFILES_DIR" ]; then
			ask dotfiles_repo "Dotfiles repository (empty to skip)" \
				"$dotfiles_repo" || return 1
		fi
	fi

	if [ -z "$git_name" ] || [ -z "$git_email" ]; then
		error "Set HERD_GIT_NAME and HERD_GIT_EMAIL, or run without -y."
		return 1
	fi
}

# -------- OS Probing ------------------
getos() {
	# For our purpose we only care about the upstream indenpendant distros.
	command -v apk >/dev/null 2>&1 && {
		echo alpine
		return 0
	}
	command -v pacman >/dev/null 2>&1 && {
		echo arch
		return 0
	}
	command -v pkg_add >/dev/null 2>&1 && {
		echo openbsd
		return 0
	}
	command -v xbps-install >/dev/null 2>&1 && {
		echo void
		return 0
	}
	echo unknown
	return 1
}
getdoas() {
	command -v doas >/dev/null 2>&1 && {
		echo doas
		return 0
	}
	command -v sudo >/dev/null 2>&1 && {
		echo sudo
		return 0
	}
	echo unknown
	return 1
}

# -------- Bootstrap -------------------

bootstrap_alpine() {
	error "Alpine Linux bootstrap is WIP."
	exit 1
}

bootstrap_arch() {
	info "Updating Package Cache..."
	run $DOAS pacman -Sy

	info "Installing crucial packages..."
	# shellcheck disable=SC2086 # split intended: one package per word
	run $DOAS pacman -S --needed --noconfirm $BASE_PKGS $ARCH_PKGS

	if command -v yay >/dev/null 2>&1; then
		info "The AUR helper is already installed."
		return 0
	fi
	info "Installing the AUR Helper '$ARCH_AUR_HELPER'."
	helper_repo="https://aur.archlinux.org/$ARCH_AUR_HELPER"
	helper_dir="$XDG_CACHE_HOME/aur/$ARCH_AUR_HELPER"
	if [ -d "$helper_dir" ]; then
		run git -C "$helper_dir" pull
	else
		run git clone "$helper_repo" "$helper_dir"
	fi
	run_in "$helper_dir" makepkg -si --noconfirm --needed
}

bootstrap_openbsd() {
	info "Installing crucial packages..."
	# shellcheck disable=SC2086 # split intended: one package per word
	run $DOAS pkg_add -I $BASE_PKGS
}

bootstrap_void() {
	info "Installing crucial packages..."
	# shellcheck disable=SC2086 # split intended: one package per word
	run $DOAS xbps-install -Sy $BASE_PKGS
}

bootstrap() {
	# Insure that the repos directory exists.
	run mkdir -p "$PERSONAL_REPOS"
	os=$1
	case $os in
	alpine) bootstrap_alpine ;;
	arch) bootstrap_arch ;;
	openbsd) bootstrap_openbsd ;;
	void) bootstrap_void ;;
	*)
		error "Operating System $os is not supported."
		exit 1
		;;
	esac

	# Install `upkg`
	info "Installing the Universal Package Manager 'upkg'."
	if [ ! -d "$PERSONAL_REPOS/upkg" ]; then
		run git clone "$UPKG_REPO" "$PERSONAL_REPOS/upkg"
	fi
	run $DOAS install "$PERSONAL_REPOS/upkg/upkg-$os" /usr/local/bin/upkg
}

# -------- Packages --------------------
# The package table: the dotfiles' copy when present, else herd's own.
packages_file() {
	user_file="${XDG_CONFIG_HOME:-$HOME/.config}/herd/packages.tsv"
	if [ -f "$user_file" ]; then
		printf '%s\n' "$user_file"
	else
		printf '%s\n' "$SCRIPT_DIR/packages.tsv"
	fi
}

# Install the essential packages for the OS and form factor.
# $1: OS name; $2: form factor
install_packages() {
	os=$1
	formfactor=$2
	table=$(packages_file)
	info "Using the package table '$table'."

	info "Installing the essential packages for a '$formfactor'..."
	pkgs=$("$SCRIPT_DIR/list_pkgs.awk" -v os="$os" -v machine="$formfactor" <"$table") ||
		fail "$?" "list_pkgs.awk for '$os' and '$formfactor' in '$table'"
	# shellcheck disable=SC2086 # split intended: one package per word
	run $DOAS upkg install $pkgs

	# `upkg` uses pacman, so install the AUR packages with the AUR helper.
	if [ "$os" = arch ]; then
		aur_pkgs=$("$SCRIPT_DIR/list_pkgs.awk" -v os=aur -v machine="$formfactor" <"$table") ||
			fail "$?" "list_pkgs.awk for 'aur' and '$formfactor' in '$table'"
		if [ -n "$aur_pkgs" ]; then
			info "Installing the essential AUR packages for a '$formfactor'..."
			# shellcheck disable=SC2086 # split intended: one package per word
			run yay -S --needed --noconfirm $aur_pkgs
		fi
	fi
}

# -------- System files ----------------
# Succeed when the installed file has the same content as the source.
# $1: source file; $2: installed file
same_file() {
	[ -e "$2" ] || return 1
	if [ -r "$2" ]; then
		cmp -s "$1" "$2"
	elif [ "$dry_run" = true ]; then
		warning "Cannot read '$2' without root; assuming it differs."
		return 1
	else
		$DOAS cmp -s "$1" "$2"
	fi
}

# Install the files under root/<tree>/ to the same paths under /. When trees
# share a path, the last tree's file wins and is the only one installed. A
# file that differs is backed up as <file>.herd-<timestamp> first; identical
# files are skipped, so a re-run changes nothing. Sets changed_files, one per
# line.
# $@: tree names under root/, e.g. unix linux
install_root_files() {
	changed_files=""
	seen_files=""
	stamp=$(date +%Y%m%d%H%M%S)
	reversed_trees=""
	for tree; do
		reversed_trees="$tree $reversed_trees"
	done
	for tree in $reversed_trees; do
		tree_dir="$SCRIPT_DIR/root/$tree"
		[ -d "$tree_dir" ] || continue
		files=$(cd "$tree_dir" && find . -type f | sed 's|^\./||' | sort)
		while IFS= read -r file; do
			[ -z "$file" ] && continue
			# A later tree already provides this file.
			if printf '%s' "$seen_files" | grep -Fxq -- "$file"; then
				continue
			fi
			seen_files="$seen_files$file
"
			source_file="$tree_dir/$file"
			target_file="/$file"
			if same_file "$source_file" "$target_file"; then
				info "Up to date: $target_file"
				continue
			fi
			if [ -e "$target_file" ]; then
				run $DOAS cp -p "$target_file" "$target_file.herd-$stamp"
			fi
			mode=644
			[ -x "$source_file" ] && mode=755
			run $DOAS mkdir -p "$(dirname "$target_file")"
			run $DOAS install -m "$mode" "$source_file" "$target_file"
			changed_files="$changed_files$target_file
"
		done <<EOF
$files
EOF
	done
}

# Install the system files for the OS, then rebuild what reads them. Trees
# apply in order, so a later tree can replace a file from an earlier one:
# unix (every OS), then linux (Arch and Void), then the OS itself.
# $1: OS name
provision_root() {
	case $1 in
	arch | void) trees="unix linux $1" ;;
	*) trees="unix $1" ;;
	esac
	# shellcheck disable=SC2086 # split intended: one tree name per word
	install_root_files $trees || return 1

	case $changed_files in
	*/etc/udev/hwdb.d/*)
		info "Rebuilding the hardware database..."
		if command -v systemd-hwdb >/dev/null 2>&1; then
			run $DOAS systemd-hwdb update
		else
			run $DOAS udevadm hwdb --update
		fi
		# Not triggered here: re-adding the keyboards can break kanata.
		info "Keyboard maps apply at the next boot, or after:" \
			"$DOAS udevadm trigger --sysname-match='event*'" \
			"(then restart kanata)."
		;;
	esac
	case $changed_files in
	*/etc/wsconsctl.conf*)
		info "/etc/wsconsctl.conf applies at the next boot."
		;;
	esac
}

# -------- dotfiles --------------------
# Clone the dotfiles and link them into $HOME with their own bootstrap.sh.
# Link only right after the first clone: that script moves the files it
# replaces into a backup, which would move repository files out of the
# repository when a directory such as ~/.config already links into it.
# $1: clone directory; $2: repository URL
summon_dotfiles() {
	dir=$1
	repo=$2
	if [ -e "$dir" ]; then
		info "'$dir' already exists. Skipping dotfiles setup..."
		return 0
	fi
	if [ -z "$repo" ]; then
		info "No dotfiles repository given. Skipping dotfiles setup..."
		return 0
	fi
	info "Cloning the dotfiles into '$dir'..."
	run git clone "$repo" "$dir"
	if [ "$dry_run" = true ]; then
		run "$dir/bootstrap.sh"
		return 0
	fi
	if [ ! -x "$dir/bootstrap.sh" ]; then
		error "'$dir/bootstrap.sh' is missing or not executable."
		return 1
	fi
	info "Linking the dotfiles into '$HOME'..."
	"$dir/bootstrap.sh"
}

# ==== Main ====================================================================
# ---- Options -------------------------
while getopts ':hny' opt; do
	case $opt in
	h)
		usage
		exit 0
		;;
	n) dry_run=true ;;
	y) prompt=false ;;
	*)
		error "Unknown option: -$OPTARG"
		usage >&2
		exit 3
		;;
	esac
done
shift "$((OPTIND - 1))"

# ---- Sanity Check --------------------
if [ "$#" -ne 1 ]; then
	error "Expected exactly one machine form factor (one of $SUPPORTED_FF)."
	usage >&2
	exit 3
fi
FORM_FACTOR="$1"

case $FORM_FACTOR in
desktop) ;;
laptop) ;;
server) ;;
*)
	error "Form Factor: '$FORM_FACTOR' is not supported. Not in ($SUPPORTED_FF)."
	usage >&2
	exit 3
	;;
esac

# ---- Probe System --------------------
if [ "$dry_run" = true ]; then
	info "Dry run: printing the commands that change the system."
fi
OS=$(getos)
DOAS=$(getdoas)

if [ "$OS" = "unknown" ]; then
	error "System is not supported. Not in ($SUPPORTED_OS)."
	exit 1
fi
info "Detected Operating System $OS."

if [ "$DOAS" = "unknown" ]; then
	error "Unable to find a supported privilege escalation command. Not in ($SUPPORTED_DOAS)."
	exit 2
fi
info "Detected privilege escalation command $DOAS."

# ---- Values --------------------------
# Ask everything up front, so the rest of the run needs no input.
get_values || exit 3

# ---- Bootstrap -----------------------
bootstrap "$OS"

# Before the packages: the dotfiles may provide the package table.
summon_dotfiles "$DOTFILES_DIR" "$dotfiles_repo" || exit 1

install_packages "$OS" "$FORM_FACTOR"

info "Installing the system files..."
provision_root "$OS" || exit 1

info "Configuring git..."
run git config --global user.name "$git_name"
run git config --global user.email "$git_email"

# ---- Set Default Shell ---------------
zsh_path=$(grep zsh /etc/shells | head -n1)
current_shell=$(getent passwd "$USER" | cut -d: -f7)
if [ -z "$zsh_path" ]; then
	warning "zsh is not listed in /etc/shells. Skipping default shell setup..."
elif [ "$current_shell" = "$zsh_path" ]; then
	info "The default shell is already $zsh_path."
else
	info "Setting the default shell to zsh..."
	run chsh -s "$zsh_path" "$USER"
fi

info "Done."
