# 🔧 Provisioning

Some programs need system configuration beyond a package install: groups, udev
rules, or files under `/etc`. herd keeps that work in two places.

> [!NOTE]
>
> `bootstrap.sh` installs the `root/` files. It does not run the provisioning
> scripts yet; run those by hand after a bootstrap.

## 📜 `provisioning_scripts/`

One script per program, under a directory for the systems it supports: `linux/`
for any Linux, or an OS name such as `arch/`.

| Script            | Does                                                                    |
| ----------------- | ----------------------------------------------------------------------- |
| `linux/kanata.sh` | Sets up the [kanata](https://github.com/jtroo/kanata) keyboard remapper |

`kanata.sh` adds the `uinput` group, adds your user to the `input` and `uinput`
groups, writes `/etc/udev/rules.d/90-kanata.rules`, and reloads udev. Run it as
your normal user:

```sh
./provisioning_scripts/linux/kanata.sh
```

Log out and back in for the new groups to apply.

## 🌳 `root/`

Each tree under `root/` mirrors the file system root: a file at
`root/linux/etc/udev/hwdb.d/90-keyboard.hwdb` belongs at
`/etc/udev/hwdb.d/90-keyboard.hwdb`. `bootstrap.sh` installs these trees, in
order:

1. `unix/`: every OS.
2. `linux/`: Arch and Void.
3. `<os>/`: only that OS, such as `arch/`, `void/`, or `openbsd/`.

When trees share a path, the last one wins. A file that is already identical is
skipped, so a re-run changes nothing; a file that differs is kept as
`<file>.herd-<timestamp>` before it is replaced. `bootstrap.sh -n` lists what
would be installed.

| File                                     | Does                                          |
| ---------------------------------------- | --------------------------------------------- |
| `linux/etc/udev/hwdb.d/90-keyboard.hwdb` | Key swaps in the kernel keymap, all sessions  |
| `openbsd/etc/wsconsctl.conf`             | The same key swaps, on the OpenBSD console    |

## ⌨️ Key swaps

Escape and Caps Lock, and left Alt and left Super, are swapped below XKB and
kanata, so the swap is the same on the console, X11, and Wayland.

### 🐧 Linux: udev hwdb

`90-keyboard.hwdb` remaps built-in laptop keyboards, and every USB and Bluetooth
keyboard. Ergonomic keyboards (ZSA, such as the ErgoDox EZ) remap in their
firmware, so a later record restores their default keys.

When it installs a changed hwdb file, `bootstrap.sh` rebuilds the hardware
database (`systemd-hwdb update`, or `udevadm hwdb --update` on Void). The new
keymap applies at the next boot. It does not re-add the keyboards; to apply the
keymap right away:

```sh
doas udevadm trigger --sysname-match="event*"
systemctl --user restart kanata   # if kanata runs; see below
```

> [!WARNING]
>
> `udevadm trigger` re-adds the keyboards. kanata can lose its grab on them, and
> X can disable kanata's output keyboard, which stops the keyboards kanata
> handles. Restart kanata afterwards; if a keyboard still types nothing, run
> `xinput enable "keyboard:kanata"`.

To keep the defaults on another ergonomic keyboard, such as a Kinesis Advantage
360 or a MoErgo Go60, add its modalias to the last record. The comments in the
file show how to read it.

Check a keyboard after a change; this lists its `KEYBOARD_KEY_*` values:

```sh
systemd-hwdb query "evdev:$(cat /sys/class/input/event3/device/modalias)"
```

> [!IMPORTANT]
>
> On laptops, confirm with `evtest` that left Super sends scancode `db`.

### 🐡 OpenBSD: wsconsctl

`wsconsctl.conf` swaps the keys on the console at boot. It cannot leave out a
single keyboard, and X11 reads keyboards raw, so under X the swap needs XKB.

> [!WARNING]
>
> `bootstrap.sh` replaces `/etc/wsconsctl.conf` with herd's copy, keeping the
> old one as a backup. Put any other `wsconsctl` settings for the machine in
> `root/openbsd/etc/wsconsctl.conf`.

To apply the map before the next boot:

```sh
doas sh -c 'grep "^keyboard.map" /etc/wsconsctl.conf | xargs -n1 wsconsctl'
```

## ✍️ Writing a provisioning script

- Use POSIX `sh` and find `doas` or `sudo` the way `kanata.sh` does.
- Make it safe to run twice: `groupadd -f`, overwrite generated files whole, and
  check before changing state.
- Mark generated files with a comment naming the script, as `kanata.sh` does in
  its udev rule.
