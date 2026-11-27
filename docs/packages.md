# 📦 Packages

`packages.tsv` lists every package once, with its name on each OS. One table
covers all machines, so a package added there reaches every OS and form factor
that should have it.

## 📍 Package table

`bootstrap.sh` reads `~/.config/herd/packages.tsv` (under `$XDG_CONFIG_HOME`
when set) when that file exists, and herd's `packages.tsv` otherwise. Keep your
own list in your dotfiles at `.config/herd/packages.tsv`: the dotfiles are
cloned and linked before the packages are installed, so a fresh machine uses it
too. The log names the table in use: `Using the package table '...'`.

## 🧾 Columns

The file is tab-separated with LF line endings and a header row.

| Column                        | Values                                         | Use                                     |
| ----------------------------- | ---------------------------------------------- | --------------------------------------- |
| `name`                        | Display name                                   | Sorting and reading                     |
| `description`                 | Free text                                      | Reading                                 |
| `category`, `short`           | e.g. `dev` and `pager`                         | Grouping when sorting                   |
| `url`, `repo`, `size`, `loc`  | Optional                                       | Reference only                          |
| `ui`                          | `cli`, `tui`, `gui`, `doc`, `service`, `other` | Grouping when sorting                   |
| `essential`                   | `TRUE` or `FALSE`                              | Installed by `bootstrap.sh` when `TRUE` |
| `desktop`, `laptop`, `server` | `TRUE` or `FALSE`                              | Form factors that get the package       |
| `tags`                        | Comma-separated                                | Reference only                          |
| `openbsd`, `arch`, `void`     | Package name, or empty                         | Name on that OS; empty means skip       |
| `aur`                         | Package name, or empty                         | Arch package from the AUR               |

> [!IMPORTANT]
> Prefer LF line endings. `list_pkgs.awk` strips CRLF line endings, but other
> tools may not.

A cell in an OS column may hold several names separated by spaces; each is
installed.

## 🔍 Selecting packages

`list_pkgs.awk` prints the names for one OS and form factor. A row is listed
when its OS column is not empty, its form factor column is `TRUE`, and
`essential` is `TRUE`. Set `extra` to also list the non-essential rows.

```sh
./list_pkgs.awk -v os=void -v machine=laptop < packages.tsv
./list_pkgs.awk -v os=arch -v machine=desktop -v extra=1 < packages.tsv
./list_pkgs.awk -v os=aur -v machine=desktop < packages.tsv
```

`os` is any OS column name, including `aur`. `bootstrap.sh` installs only the
essential packages; install the extras by hand:

```sh
upkg install $(./list_pkgs.awk -v os=void -v machine=laptop -v extra=1 \
	< packages.tsv)
```

## ➕ Adding a package

1. Add a row with the name on each OS where it exists, and leave the other OS
   columns empty.
2. Set `essential` and the form factor columns.
3. Sort the table and check it reads well:

   ```sh
   ./sort_pkgs.sh packages.tsv > packages.sorted && mv packages.sorted packages.tsv
   ./view_pkgs.sh packages.tsv | less -S
   ```

`sort_pkgs.sh` keeps the header first and sorts by `essential` and `server`
(`TRUE` first), then `ui`, `category`, `short`, and `name`. `view_pkgs.sh`
aligns the columns with `column -t`.

## 🖥️ Adding an OS

1. Add a column named after the OS to `packages.tsv`.
2. Detect it in `getos` in `bootstrap.sh`, and add a `bootstrap_<os>` function
   that installs `BASE_PKGS`.
3. Add an `upkg-<os>` script to the upkg repo.
