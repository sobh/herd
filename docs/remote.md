# 🌐 Remote machines

`remote.sh` provisions machines over SSH from an inventory. For each host, one
at a time, it copies herd to `~/.cache/herd` on the host and runs `bootstrap.sh`
there, with that host's form factor.

```sh
./remote.sh                 # every host in the inventory
./remote.sh laptop1 desk1   # only these hosts
./remote.sh -n              # dry run on every host
```

## 📋 Inventory

The inventory lists one host per line: an SSH destination and a form factor. The
default is `~/.config/herd/inventory`; pass another file with `-i`.

```text
# DESTINATION   FORM_FACTOR
desk1           desktop
laptop1         laptop
me@server1      server
router1         server   # routers are servers to herd
```

`DESTINATION` is anything `ssh` accepts: `user@host`, `host`, or a `Host` alias
from `~/.ssh/config`, which can also set the port, user, and key.
`inventory.example` is a starting point.

> [!NOTE]
>
> Keep the inventory out of public repositories if host names are private. An
> `inventory` file in the herd repository is ignored by git.

## 💬 Values and prompts

`remote.sh` asks once for the git name and email and the dotfiles repository,
with the same defaults as `bootstrap.sh` (the `HERD_*` variables, then the git
configuration on this machine). It passes them to every host, so hosts run with
`-y`. Use `-y` on `remote.sh` too to skip the prompts.

The dotfiles repository is used only by hosts without `~/dotfiles`; leave it
empty to skip the dotfiles everywhere.

## 🔐 Passwords and connections

Each host gets a terminal (`ssh -t`), so `doas` or `sudo` can ask for a password
there. One SSH connection is shared per host for the copy and the run, so SSH
asks for a password at most once per host.

## 🧾 Results

A failed host does not stop the others. The run ends with a summary:

```text
OK      desk1 (desktop)
OK      srv1 (server)
FAILED  down1 (laptop), status 255
```

`remote.sh` exits with 1 when a host failed; run it again for those hosts, since
completed steps are skipped. Status 255 means SSH could not connect.

## ✅ Host requirements

- An SSH server, `sh`, and `tar`: all in the base systems of Arch, Void, and
  OpenBSD.
- `doas` or `sudo` for your user.
- For SSH clones of upkg or the dotfiles: a key on the host with access to them.
