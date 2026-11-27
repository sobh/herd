#!/bin/sh
#
# Description: Bootstrap a machine with herd
#

#---- Parameters ---------------------------------------------------------------
# Defaults
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
USERNAME="Mohamed Sobh"
EMAIL="m@sobh.dev"
DOTFILES_REPO="git@github.com:sobh/dotfiles"
UPKG_REPO="git@github.com:sobh/upkg"

OS=""
DOAS=""

BASE_PKGS="git"
ARCH_PKGS="openssh fakeroot"
ARCH_AUR_HELPER="yay-bin"

#---- Constants ----------------------------------------------------------------
MY_DIR=$(cd "$(dirname "$0")" && pwd)
REPOS_DIR="$HOME/repos"
PERSONAL_REPOS="$REPOS_DIR/$(whoami)"

SUPPORTED_DOAS="doas, sudo"
SUPPORTED_OS="Alpine Linux, Arch Linux, Void Linux, OpenBSD"
SUPPORTED_FF="desktop, laptop, server"

# Escape Colors
ESC="\033"
RESET="$ESC[0m"
FG_RED="$ESC[91m"
FG_GREEN="$ESC[92m"
FG_YELLOW="$ESC[93m"
FG_BLUE="$ESC[94m"
FG_MAGENTA="$ESC[95m"
FG_CYAN="$ESC[96m"

#---- Functions ----------------------------------------------------------------

#-------- Status -----------------------
HERD_PREFIX="${FG_MAGENTA}herd | "
info()		{ printf "${HERD_PREFIX}${FG_BLUE}%-8s$RESET: %s\n" "Info" "$*"; }
warning()	{ printf "${HERD_PREFIX}${FG_YELLOW}%-8s$RESET: %s\n" "Warning" "$*"; }
error()		{ printf "${HERD_PREFIX}${FG_RED}%-8s$RESET: %s\n" "Error" "$*"; }

#-------- Usage ------------------------
usage()
{
	cat << _EOF

$(basename $0)  FORM_FACTOR

Parameters:
	FORM_FACTOR     The machine form factor. One of: $SUPPORTED_FF

_EOF
}
#-------- OS Probing -------------------
getos()
{
	# For our purpose we only care about the upstream indenpendant distros.
	command -v apk >/dev/null 2>&1 && { echo alpine; return 0;}
	command -v pacman >/dev/null 2>&1 && { echo arch; return 0;}
	command -v pkg_add >/dev/null 2>&1 && { echo openbsd; return 0;}
	command -v xbps-install >/dev/null 2>&1 && { echo void; return 0;}
	echo unknown
	return 1
}
getdoas()
{
	command -v doas >/dev/null 2>&1 && { echo doas; return 0;}
	command -v sudo >/dev/null 2>&1 && { echo sudo; return 0;}
	echo unknown
	return 1
}

#-------- Bootstrap --------------------

bootstrap_alpine()
{
	error "Alpine Linux bootstrap is WIP."
}

bootstrap_arch()
{
	info "Updating Package Cache..."
	$DOAS pacman -Sy

	info "Installing crucial packages..."
	$DOAS pacman -S --needed --noconfirm $BASE_PKGS $ARCH_PKGS

	info "Installing the AUR Helper '$ARCH_AUR_HELPER'."
	helper_repo="https://aur.archlinux.org/$ARCH_AUR_HELPER"
	aur_cache="$XDG_CACHE_HOME/aur"
	mkdir -p "$aur_cache"
	cd "$aur_cache" || return 1
	[ ! -d "$ARCH_AUR_HELPER" ] && git clone "$helper_repo"
	cd "$ARCH_AUR_HELPER" && git pull
	makepkg -si --noconfirm --needed
}

bootstrap_openbsd()
{
	info "Installing crucial packages..."
	$DOAS pkg_add -I $BASE_PKGS
}

bootstrap_void()
{
	info "Installing crucial packages..."
	$DOAS xbps-install -Sy $BASE_PKGS
}

bootstrap()
{
	# Insure that the repos directory exists.
	mkdir -p "$PERSONAL_REPOS" >/dev/null 2>&1
	os=$1
	case $os in
		alpine)		bootstrap_alpine ;;
		arch)		bootstrap_arch ;;
		openbsd)	bootstrap_openbsd ;;
		void)		bootstrap_void ;;
		*)
			error "Operating System $os is not supported."
			exit 1
			;;
	esac
	formfactor=$2

	# Install `upkg`
	info "Installing the Universal Package Manager 'upkg'."
	_cw=$(pwd)
	cd "$PERSONAL_REPOS" || exit 1
	[ ! -d upkg ] && git clone "$UPKG_REPO"
	(set -x; $DOAS install "$PERSONAL_REPOS/upkg/upkg-$os" /usr/local/bin/upkg)
	cd "$_cw" || exit 1

	# Intall the essential packages
	info "Installing the essential packages for a '$formfactor'..."
	pkgs=$("$MY_DIR/list_pkgs.awk" -v os="$os" -v machine="$formfactor" < "$MY_DIR/pkgs.tsv")
	# Word splitting of $pkgs into package names is intended.
	$DOAS upkg install $pkgs

	# `upkg` uses pacman, so install the AUR packages with the AUR helper.
	if [ "$os" = arch ]; then
		aur_pkgs=$("$MY_DIR/list_pkgs.awk" -v os=aur -v machine="$formfactor" < "$MY_DIR/pkgs.tsv")
		if [ -n "$aur_pkgs" ]; then
			info "Installing the essential AUR packages for a '$formfactor'..."
			yay -S --needed --noconfirm $aur_pkgs
		fi
	fi
}

#-------- dotfiles ---------------------
summon_dotfiles ()
{
	dir=$1
	repo=$2
	if [ ! -d "$dir" ]; then
		error "$dir directory does not exist."
		return 1
	fi
	# Re-runs find the dotfiles already checked out; that is not an error.
	if [ -d "$dir/.git" ]; then
		info "There is already a '.git' in '$dir'. Skipping dotfiles setup..."
		return 0
	fi
	cd "$dir" || return 1
	git init --initial-branch=master
	git remote add origin "$repo"
	git fetch
	git checkout --force master
}
#---- Main ---------------------------------------------------------------------
#---- Sanity Check ---------------------
FORM_FACTOR="$1"

if [ -z "$FORM_FACTOR" ]; then
	error "Please specify the machine form factor."
	usage
	exit 3
else
	case $FORM_FACTOR in
		desktop)    ;;
		laptop)     ;;
		server)     ;;
		*)
			error "Form Factor: '$FORM_FACTOR' is not supported. Not in ($SUPPORTED_FF)."
			usage
			exit 3
			;;
	esac
fi

#---- Probe System ---------------------
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

#---- Bootstrap ------------------------
bootstrap $OS $FORM_FACTOR

info "Configuring git..."
( set -x; git config --global user.name "$USERNAME"; )
( set -x; git config --global user.email "$EMAIL"; )

#---- Set Default Shell ----------------
zsh_path=$(grep zsh /etc/shells | head -n1)
current_shell=$(getent passwd "$USER" | cut -d: -f7)
if [ -z "$zsh_path" ]; then
	warning "zsh is not listed in /etc/shells. Skipping default shell setup..."
elif [ "$current_shell" = "$zsh_path" ]; then
	info "The default shell is already $zsh_path."
else
	info "Setting the default shell to zsh..."
	chsh -s "$zsh_path" "$USER"
fi

#---- Dotfiles -------------------------
summon_dotfiles "$HOME" "$DOTFILES_REPO"
