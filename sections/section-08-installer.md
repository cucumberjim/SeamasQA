# Section 08: Installer

## Purpose

Wire the hook and the `code-review` skill into a developer's machine. This section produces the **skeleton** (contracts, not-implemented stubs) for `scripts/install.sh` (Linux and Git Bash) and `scripts/install.ps1` (Windows), plus **failing** tests: bats for `install.sh`, Pester 5 for `install.ps1`. This is a training exercise. Do not write the real installer logic. The learner implements it against the tests.

## Dependencies

- **section-05-review-verdict**: defines the hook behavior that the shim sources, and the `lib/` files that get installed.
- **section-06-skill**: provides `skill/code-review/`, which the installer copies.
- **section-01-foundation** (transitive): the directory skeleton, the bats isolation helper, `test/stubs/`, and the "not implemented" guard convention.

Reference only. Do not duplicate those sections' content here.

## Background

The repo ships a git `pre-commit` hook (`hooks/pre-commit`, POSIX sh) that sources libraries from `lib/` (`common.sh`, `staged.sh`, `checks.sh`, `wsl.sh`, `review.sh`). A per-repo copy of everything would make fixes hard to roll out. Instead the installer:

1. Installs `lib/` **once** to a per-user location.
2. Writes a **thin shim** as the repo's `pre-commit` hook. The shim sources the user-level lib, so a fix reaches every repo.
3. Copies the skill to `~/.claude/skills/code-review/`.

Hook chaining (already designed in the hook): `hooks/pre-commit` runs `pre-commit.local` first if present. The installer's backup step is what creates that file.

Conventions that apply: Windows + Linux (no macOS). Every file must pass shellcheck or be listed in `LINT-EXCEPTIONS.md`. LF line endings are enforced by `.gitattributes`.

## Files to Create or Modify

| Path | Action |
|------|--------|
| `scripts/install.sh` | Create: skeleton with contract and not-implemented body |
| `scripts/install.ps1` | Create: skeleton with contract and not-implemented body |
| `test/bats/installer.bats` | Create: failing tests |
| `test/pester/install.Tests.ps1` | Create: failing Pester tests |

## Tests (write first)

All tests must **fail** against the skeleton, because the skeleton exits non-zero with "not implemented". Each bats test uses the shared isolation helper from section-01: `HOME=$BATS_TEST_TMPDIR/home`, `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1`, repo-local `user.name/email`, and `GIT_DIR`/`GIT_INDEX_FILE` unset. Every test builds a temp git repo and runs the installer against it with the user location under the temp HOME. The installer must never touch the real HOME in tests.

### `test/bats/installer.bats`

Stub shape (bodies are the learner's to flesh out):

```bash
setup() {
  # load shared helper: isolation env, temp git repo at $REPO, HOME under tmp
}

@test "install creates marker shim and installs lib under temp HOME" { ... }
```

Tests, in prose:

- **install creates marker shim, lib to user location**: run `scripts/install.sh "$REPO"`. Assert `$REPO/.git/hooks/pre-commit` exists, contains the exact marker line `# code_quality-hook v1`, and sources the user-level lib. Assert `lib/*.sh` now exists under `$HOME/.local/share/code_quality`.
- **existing unmarked pre-commit is backed up**: pre-seed `$REPO/.git/hooks/pre-commit` with an arbitrary script (no marker). After install, that content lives at `pre-commit.local` and `pre-commit` is the marker shim.
- **second install does not overwrite `.local`**: after the previous scenario, run install again. `pre-commit.local` is byte-identical to the original. The hook is still the marker shim. Also test that an existing `.local` with a new unmarked `pre-commit` makes the installer refuse (non-zero exit, `.local` untouched).
- **idempotent**: running install twice on a fresh repo yields the same state, with no `.local` created, since the existing hook carries the marker.
- **install twice then `--uninstall` restores the original hook**: pre-seed an unmarked hook, install, install, then `--uninstall`. `pre-commit` equals the original content and `pre-commit.local` is gone. Uninstall on a repo with no marker shim does nothing destructive (exit 0 with message, or documented non-zero; pick one in GUIDE.md and assert it).
- **`--hooks-path` sets core.hooksPath**: `install.sh --hooks-path "$dir" "$REPO"` sets `git config core.hooksPath` to `$dir` and writes the shim there. Backup and marker rules apply in that directory.
- **skill copied**: `$HOME/.claude/skills/code-review/SKILL.md` exists after install and matches the repo's `skill/code-review/SKILL.md`.
- **exec bit set on Linux**: the installed `pre-commit` shim is executable.
- **default target is cwd**: with no repo argument, running from inside `$REPO` installs into that repo.
- **next steps printed**: output mentions the conventions file location (`~/.config/code-review/conventions.md`) and the env vars (`REVIEW_STRICTNESS`, `SKIP_CODE_REVIEW`, `CODE_QUALITY_SINK`).
- **hooks dir resolved by git**: a repo where `git rev-parse --git-path hooks` is non-default (for example a worktree or an existing `core.hooksPath`) installs into the path git reports.

### `test/pester/install.Tests.ps1` (Pester 5)

Equivalents under a temp `$env:LOCALAPPDATA` and temp `$env:USERPROFILE`, with `git` operating on a temp repo:

- Install creates the marker shim and copies `lib/` to `%LOCALAPPDATA%\code_quality`.
- The shim written on Windows is still a **POSIX sh** script with LF endings (Git for Windows runs it with its own sh). Assert no CRLF in the written file.
- Unmarked existing hook is backed up to `pre-commit.local`. A second install does not overwrite it.
- Install twice then `-Uninstall` restores the original.
- `-HooksPath` sets `core.hooksPath`.
- Skill copied to `$env:USERPROFILE\.claude\skills\code-review`.

## Implementation Contract

### Skeleton (what the learner starts with)

Both scripts parse nothing and run nothing. They print `not implemented` to stderr and exit non-zero (the same guard convention as other skeleton functions). The header comment documents the contract below.

`scripts/install.sh` stub:

```sh
#!/bin/sh
# Contract: see below. Usage:
#   install.sh [--hooks-path DIR] [--uninstall] [REPO_DIR]
echo "install.sh: not implemented" >&2
exit 1
```

`scripts/install.ps1` stub: parameters `-RepoDir`, `-HooksPath`, `-Uninstall`, body `Write-Error "not implemented"; exit 1`.

### Behavior the tests define

**Arguments.** Optional target repo (positional, default current directory). `--hooks-path DIR` (`-HooksPath` on PowerShell). `--uninstall` (`-Uninstall`).

**Locating the hooks directory.** Run `git -C <repo> rev-parse --git-path hooks`. Do not assume `.git/hooks`. With `--hooks-path`, set `core.hooksPath` in the repo's local config and use that directory.

**User-level lib location.** Linux and Git Bash: `~/.local/share/code_quality`. Windows (PowerShell): `%LOCALAPPDATA%\code_quality`. Copy `lib/` there (overwrite on re-run so fixes propagate).

**Shim.** A short POSIX sh file, LF endings, whose first non-shebang content includes the marker line exactly:

```
# code_quality-hook v1
```

It locates the user-level lib and hands off to the real hook logic. The learner decides whether the hook body also lives in the user location or the shim embeds it. Document that choice in GUIDE.md. The shim is what carries the marker.

**Backup rule.**
- Existing `pre-commit` without the marker: move to `pre-commit.local`, then write the shim.
- Existing `pre-commit` with the marker: replace in place (upgrade), no backup.
- Backup needed but `pre-commit.local` already exists: **refuse** (non-zero exit, clear message, nothing modified). Never overwrite `.local`.

**Permissions.** Set the exec bit on Linux (`chmod +x`). Windows relies on Git for Windows treating hooks as executable.

**Skill.** Copy `skill/code-review/` to `~/.claude/skills/code-review/` (`%USERPROFILE%\.claude\skills\code-review\` on Windows), replacing existing contents.

**Idempotence.** Re-running changes nothing that is already correct and never produces a second backup.

**Uninstall.** If `pre-commit` carries the marker: remove it and, if `pre-commit.local` exists, move it back to `pre-commit`. If `--hooks-path` was used, also unset the `core.hooksPath` setting the installer added. Leave the user-level lib and the skill in place, because other repos use them. Document that choice.

**Next steps output.** Print: where the conventions file goes (`~/.config/code-review/conventions.md`, Windows `%USERPROFILE%\.config\code-review\conventions.md`), and the env vars `REVIEW_STRICTNESS` (lite|full|ultra), `REVIEW_MODEL`, `SKIP_CODE_REVIEW`, `CODE_QUALITY_SINK`, and the `SKIP_*` linter variables. Mention `git commit --no-verify`.

**Security notes for the learner.** Quote all paths (spaces are likely on Windows). Never `eval` arguments. Validate that the target is a git work tree before writing anything. Never read the sink, model or strictness from repo files.

### Lint

Both scripts must pass shellcheck (`install.sh`). `install.ps1` is covered by PSScriptAnalyzer. The dogfood test in section-09 runs shellcheck over `scripts/`.

## Done Criteria

- `scripts/install.sh` and `scripts/install.ps1` exist as not-implemented skeletons with the contract in their headers.
- `test/bats/installer.bats` and `test/pester/install.Tests.ps1` exist, cover every bullet above, and **all fail** against the skeleton.
- Running `vendor/vendor/bats-core/bin/bats test/bats/installer.bats` produces failures only for "not implemented" reasons, never for syntax or setup errors.

Correction to the last path: use `vendor/bats-core/bin/bats test/bats/installer.bats`.