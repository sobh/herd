# ⚖️ herd vs Ansible

herd is plain shell on purpose. This page compares it with an Ansible playbook
that does the same steps.

## 📊 Comparison

|               | herd                                          | Ansible                                       |
| ------------- | --------------------------------------------- | --------------------------------------------- |
| Dependencies  | `sh`, `awk`, `git`                            | Python on the control machine and the targets |
| Runs          | Locally, or over SSH with `remote.sh`         | Over SSH from one machine, or `ansible-pull`  |
| Fresh install | Works as is                                   | Needs Python installed first                  |
| Re-runs       | Written into each step                        | Built into most modules                       |
| Config files  | Not deployed yet ([`root/`](provisioning.md)) | Templates with per-host variables             |
| Preview       | None                                          | `--check --diff`                              |
| Many hosts    | One at a time, from an inventory              | In parallel                                   |
| Size          | 2 files, about 280 lines                      | 17 files, about 280 lines, plus its concepts  |

## 🎯 When to use which

**herd fits machines you set up at the console:** desktops and laptops, where
the job is packages and dotfiles, done once and re-run now and then. It needs
nothing beyond the base system on Arch, Void, and OpenBSD.

**Ansible pays off for machines managed remotely over time,** such as servers
and routers, where the job is mostly configuration files that differ per host:

- `--check --diff` shows what would change before touching a router.
- Templates fill per-host values (interfaces, addresses) into one file.
- `validate` checks a file before installing it, for example `pfctl -nf %s` for
  `pf.conf`.
- Handlers reload a service only when its configuration changed.

Much of such a playbook is spent working around Ansible itself: installing
Python with `raw`, building the AUR helper in two steps because `makepkg -si`
prompts for sudo, and re-implementing `list_pkgs.awk` in Jinja.

> [!TIP]
>
> A playbook can read the same `packages.tsv`, so both can run side by side:
> herd to bootstrap any machine, Ansible to manage the remote ones afterwards.
