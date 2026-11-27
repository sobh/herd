# 🚀 Bootstrap

`bootstrap.sh` turns a fresh install into a working machine. Run it as your
normal user from a console; it calls `doas` or `sudo` when it needs root.

```sh
./bootstrap.sh [-n] [-y] FORM_FACTOR
```

`FORM_FACTOR` is one of `desktop`, `laptop`, or `server`. It selects the
packages from [`packages.tsv`](packages.md). A missing or unknown form factor
exits with code 3; `./bootstrap.sh -h` lists all exit codes.

## 👀 Dry run

`-n` prints the commands that would change the system, in order, without running
them. Checks that only read the system still run, so the output matches what a
real run would do on that machine.

```sh
./bootstrap.sh -n laptop
```

Example output (shortened):

```text
herd | Dry run : doas pacman -Sy
herd | Dry run : doas pacman -S --needed --noconfirm git openssh fakeroot
herd | Dry run : git config --global user.name 'Mohamed Sobh'
herd | Info    : The default shell is already /bin/zsh.
```

## ✅ Prerequisites

- A supported system: Arch, Void, or OpenBSD. Alpine is detected, but its
  bootstrap is not written yet.
- `doas` or `sudo` configured for your user.
- An SSH key with access to `git@github.com:sobh/upkg`, and to your dotfiles
  repository if it uses SSH.

## 🔄 Steps

1. **Detect the system.** The OS comes from the package manager present (`apk`,
   `pacman`, `pkg_add`, `xbps-install`), then `doas` is preferred over `sudo`.
   Unsupported systems exit with code 1; no escalation command exits with code
   2.
2. **Install the crucial packages** for the OS:
   - Arch: syncs the package database, installs `git`, `openssh`, and
     `fakeroot`, then builds and installs the `yay-bin` AUR helper under
     `$XDG_CACHE_HOME/aur`.
   - Void: `xbps-install -Sy git`.
   - OpenBSD: `pkg_add -I git`.
3. **Install `upkg`.** Clones it into `~/repos/$USER/upkg` and installs
   `upkg-<os>` as `/usr/local/bin/upkg`, a single package command for every OS.
4. **Clone the dotfiles,** when you gave a repository, into `~/dotfiles` and run
   their `bootstrap.sh`, which symlinks each dotfile into `$HOME`. Files it
   replaces are moved to `~/dotfiles_backup/<date>/`.
5. **Install the essential packages** for the form factor with `upkg install`,
   from the [package table](packages.md#-package-table). On Arch, packages in
   the `aur` column are then installed with `yay`.
6. **Install the system files** from `root/` (see
   [Provisioning](provisioning.md#-root)), backing up files they replace, and
   rebuild the hardware database when a udev hwdb file changed.
7. **Configure git** with the name and email you gave, as global `user.name` and
   `user.email`.
8. **Set zsh as the login shell,** using the first zsh in `/etc/shells`.

> [!WARNING]
> The linking runs only right after the first clone. On a machine where a
> directory such as `~/.config` already links into `~/dotfiles`, running the
> dotfiles `bootstrap.sh` again would move repository files into the backup.

## 🔁 Re-running

Running `bootstrap.sh` again is safe and is how you bring a machine up to date
with `packages.tsv`:

- Package installs skip what is already installed.
- The AUR helper repo is pulled again; `makepkg --needed` does not reinstall an
  unchanged version.
- `upkg` is not cloned again, but its script is reinstalled.
- System files that are already identical are skipped.
- `chsh` runs only when the login shell is not zsh yet.
- The dotfiles step is skipped once `~/dotfiles` exists; run
  `~/dotfiles/bootstrap.sh` yourself to link newly added dotfiles.

> [!NOTE]
> `upkg install` on Arch runs `pacman -S --needed` without `--noconfirm`, so it
> asks for confirmation when there is something to install.

## 🧪 Smoke test

`test.sh` checks that `ssh` and `git` are available after a bootstrap:

```sh
./test.sh
```

It uses `status` from `~/lib/sh/log.sh` in the dotfiles when present, and plain
output otherwise.

## 💬 Prompts and environment

Before changing anything, `bootstrap.sh` asks for your git name and email, and,
when `~/dotfiles` does not exist yet, your dotfiles repository. Press Enter to
keep the default shown in brackets; leave the repository empty to skip the
dotfiles, for example on a server.

| Variable             | Value                   | Default                         |
| -------------------- | ----------------------- | ------------------------------- |
| `HERD_GIT_NAME`      | Git `user.name`         | The current global `user.name`  |
| `HERD_GIT_EMAIL`     | Git `user.email`        | The current global `user.email` |
| `HERD_DOTFILES_REPO` | Dotfiles repository URL | None: skip the dotfiles         |

With `-y`, `bootstrap.sh` does not prompt and takes these values as they are. A
missing name or email then exits with code 3 before any change:

```sh
HERD_GIT_NAME='Jane Doe' HERD_GIT_EMAIL=jane@example.org \
	HERD_DOTFILES_REPO=git@github.com:jane/dotfiles \
	./bootstrap.sh -y laptop
```

## ⚙️ Settings

Edit the parameters at the top of `bootstrap.sh`:

| Variable                       | Purpose                                      |
| ------------------------------ | -------------------------------------------- |
| `UPKG_REPO`                    | The upkg repository to clone                 |
| `DOTFILES_DIR`                 | Where the dotfiles are cloned                |
| `BASE_PKGS`                    | Packages installed on every OS before `upkg` |
| `ARCH_PKGS`, `ARCH_AUR_HELPER` | Arch-only packages and the AUR helper        |
