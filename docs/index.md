# 📚 herd documentation

herd sets up Arch, Void, and OpenBSD machines with plain POSIX shell. It needs
only `sh`, `awk`, and a privilege escalation command (`doas` or `sudo`).

| Guide                           | Covers                                                      |
| ------------------------------- | ----------------------------------------------------------- |
| [Bootstrap](bootstrap.md)       | Running `bootstrap.sh`, what each step does, re-runs        |
| [Remote machines](remote.md)    | Provisioning hosts over SSH from an inventory               |
| [Packages](packages.md)         | The `packages.tsv` table, package selection, helper scripts |
| [Provisioning](provisioning.md) | `provisioning_scripts/`, `root/`, and key swaps             |
| [herd vs Ansible](ansible.md)   | Why shell, and where Ansible would pay off                  |
| [Git hooks](hooks.md)           | pre-commit checks and commit message format                 |

Every shell script prints its usage, arguments, and exit codes with `-h`.

## 🗂️ Repository layout

| Path                           | Purpose                                                    |
| ------------------------------ | ---------------------------------------------------------- |
| `bootstrap.sh`                 | Main entry point: packages, git identity, shell, dotfiles  |
| `remote.sh`                    | Runs `bootstrap.sh` on the inventory's hosts over SSH      |
| `lib.sh`                       | Helpers shared by `bootstrap.sh` and `remote.sh`           |
| `inventory.example`            | Example inventory for `remote.sh`                          |
| `packages.tsv`                 | Package table: one row per package, one name column per OS |
| `list_pkgs.awk`                | Prints the package names for an OS and form factor         |
| `sort_pkgs.sh`, `view_pkgs.sh` | Keep `packages.tsv` sorted and readable                    |
| `test.sh`                      | Smoke test that expected commands exist                    |
| `provisioning_scripts/<os>/`   | One-off setup scripts for a single program                 |
| `root/<os>/`                   | Files to install under `/` on that OS                      |
