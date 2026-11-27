# 🪝 Git hooks

The hooks live in `scripts/githooks/`. Point git at them once per clone:

```sh
scripts/install-git-hooks.sh
```

This sets `core.hooksPath`, so later changes to the hooks apply without
installing again.

## pre-commit

Formats and checks **staged** files, and stages the formatter changes again:

| Check         | Staged files    | Tool                  |
| ------------- | --------------- | --------------------- |
| 🔎 Filenames  | newly added     | ASCII, no spaces      |
| 🧹 Whitespace | all             | strip trailing spaces |
| 📝 Markdown   | `*.md`          | `rumdl check --fix`   |
| 🐚 Shell      | `*.sh`, hooks   | `shfmt`, `shellcheck` |
| 🔤 Spelling   | all             | `typos`               |

A missing tool skips its check with a warning. Full tool output goes to
`.git/pre-commit.log`. Settings are in `.editorconfig`, `.rumdl.toml`, and
`.typos.toml`; add spelling false positives to `.typos.toml`.

> [!NOTE]
> A file with unstaged changes is never staged again by the hook. If a formatter
> changes such a file, the commit is rejected; stage it fully or stash the rest
> with `git stash -k`.

Run the checks on the staged files without committing:

```sh
scripts/githooks/pre-commit
```

## commit-msg

Commit subjects must follow
[Conventional Commits](https://www.conventionalcommits.org/):
`type(scope): subject`, with the scope optional.

- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`,
  `ci`, `chore`, `revert`.
- The subject starts in lowercase, has no trailing period, and the whole line is
  at most 72 characters.
- Merge, revert, fixup, and squash subjects made by git are accepted.

```text
feat(bootstrap): add a router form factor
docs: describe the git hooks
```
