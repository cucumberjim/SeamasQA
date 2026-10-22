# Section 01: Foundation

## Overview

This section creates the repo skeleton that every other section builds on:

- the directory layout
- `.gitattributes` and `LINT-EXCEPTIONS.md`
- vendored bats placeholders
- the shared bats test helper (isolation setup)
- stub executables for `claude`, `cookstyle`, `chef`, `pwsh` and `wsl.exe`
- "not implemented" guard functions in the lib files

**This is a training exercise.** Claude and the plan writes no production logic. The skeleton holds empty functions that print "not implemented" and exit non-zero. The learner implements against failing tests. Do not add real behavior to the lib files here.

**Dependencies:** none. This section blocks all others.

**Platform conventions:** Windows (Git Bash) and Linux (bash/zsh) only, with no macOS. Every file must pass linters or be listed in `LINT-EXCEPTIONS.md`. Third-party FOSS must be license-compatible and vendored with its license files kept.

## Background

The repo ships a git `pre-commit` hook that runs deterministic linters and then asks Claude Code for a review. It also ships a `code-review` Claude Code skill and an installer. Later sections fill in the hook core, checks, WSL, review/verdict, skill, build script, installer and guide. This section only lays out the files they will edit.

Design facts that affect the foundation:

- `hooks/pre-commit` is POSIX sh. The `lib/*.sh` files are sourced by it, so they must be POSIX sh too.
- Tests use bats-core with bats-support and bats-assert, vendored under `vendor/`. Pester 5 covers PowerShell.
- Each bats test builds a temp git repo, copies the hook, and puts stubs on PATH. Tests must not touch the developer's real HOME or git config.
- All tests start **failing**, because they call not-implemented stubs.

## Tests First

Create these tests before the skeleton files, and confirm they fail first. Use bats with `bats-support` and `bats-assert`. These are prose stubs, so write the bodies yourself.

### `test/bats/foundation.bats`

```bash
# Test: required files exist
#   hooks/pre-commit, lib/common.sh, lib/staged.sh, lib/checks.sh,
#   lib/wsl.sh, lib/review.sh, docs/WSL2-INSTALL.md, LINT-EXCEPTIONS.md,
#   .gitattributes, scripts/install.sh, scripts/install.ps1, scripts/build-skill.sh

# Test: .gitattributes forces LF for hook and *.sh
#   (grep for "hooks/pre-commit text eol=lf" and "*.sh text eol=lf")

# Test: every skeleton function exits non-zero with "not implemented"
#   (guards that the skeleton is truly empty). Source each lib/*.sh, then call every
#   function in the not-implemented list below; assert status != 0 and
#   output contains "not implemented".
#   Remove entries from this list as the learner implements functions.

# Test: LINT-EXCEPTIONS.md lists vendor/
```

### `test/bats/helpers_isolation.bats`

```bash
# Test: bats helper setup sets HOME=$BATS_TEST_TMPDIR/home, GIT_CONFIG_GLOBAL=/dev/null,
#   GIT_CONFIG_NOSYSTEM=1, repo-local user.name/email;
#   GIT_DIR and GIT_INDEX_FILE are unset even if exported before calling the helper

# Test: make_repo creates a git repo with the hook copied in, and stubs dir first on PATH
```

### `test/bats/stubs.bats`

```bash
# Test: stub `claude` with CLAUDE_STUB_MODE in {pass, fail, is_error, nonsuccess, hang, garbage}
#   emits the canned output for that mode, with fixed session_id
#   (a valid UUID) and records invocation count and stdin
# Test: stub `claude` with unset mode defaults to "pass"
# Test: stubs for cookstyle, chef, pwsh, wsl.exe record cwd and args to a log file
#   and exit with their configured status
```

Note: the dogfood shellcheck test over `hooks/ lib/ scripts/ test/*.bats` belongs to section-09-guide-and-dogfood. Keep your files shellcheck-clean anyway.

## Implementation

### 1. Directory skeleton

Create this layout. Files marked (empty) are placeholders that later sections fill in.

```
code_quality/
  README.md  REQUIREMENTS.md                    # already exist
  GUIDE.md                                      # (empty placeholder; written in section-09)
  docs/WSL2-INSTALL.md                          # (empty placeholder; section-04)
  hooks/pre-commit                              # POSIX sh entrypoint (skeleton)
  lib/common.sh staged.sh checks.sh wsl.sh review.sh
  skill/code-review/SKILL.md                    # (empty placeholder; section-06)
  skill/code-review/prompts/  references/       # (.gitkeep)
  scripts/install.sh install.ps1 build-skill.sh # (skeletons)
  vendor/bats-core/ bats-support/ bats-assert/  # vendored placeholders
  test/bats/  test/pester/  test/fixtures/  test/stubs/
  .gitattributes
  LINT-EXCEPTIONS.md
```

Add `.gitkeep` to otherwise-empty directories (`skill/code-review/prompts`, `skill/code-review/references`, `test/pester`, `test/fixtures`).

### 2. `.gitattributes`

Force LF so the sh hook works on Windows checkouts under Git for Windows:

```
hooks/pre-commit text eol=lf
*.sh text eol=lf
*.bats text eol=lf
test/stubs/* text eol=lf
```

### 3. `LINT-EXCEPTIONS.md`

A short table with the columns Path, Tool, Reason. Initial entry: `vendor/` (all linters), because it is third-party vendored code kept verbatim with its license. Later sections append entries. Explain that any file failing a linter must be listed here.

### 4. Vendored bats

Vendor `bats-core`, `bats-support` and `bats-assert` (all MIT/CC0-style licenses) under `vendor/`. Keep each project's `LICENSE` file. Use `git subtree` or a plain copy of a pinned release, not a submodule, so a plain clone works. Record the pinned versions in `vendor/README.md`. The test command is `vendor/bats-core/bin/bats test/bats`. If the learner cannot fetch them yet, leave a `vendor/README.md` listing the exact upstream repos and tags to copy, plus the empty directories. The exercise cannot run tests until they are present.

### 5. Skeleton scripts and libs

Every lib function body is a single call to a shared guard defined in `lib/common.sh`:

```sh
# lib/common.sh
cq_not_implemented() {
    # Print "not implemented: <caller name>" to stderr and return 1.
    :
}
```

`cq_not_implemented` is the one function with real (tiny) behavior. It prints `not implemented: <name>` on stderr and returns 1. Every other function is a stub of the form:

```sh
check_json() { cq_not_implemented "check_json"; }
```

Each lib file starts with a header comment stating the module contract (inputs, outputs, exit codes). The signatures below are the not-implemented list for the guard test. Later sections own the contracts in detail.

| File | Stub functions |
|------|----------------|
| `lib/common.sh` | `cq_log`, `cq_warn`, `cq_die`, `cq_is_skip`, `cq_detect_platform`, `cq_load_strictness` |
| `lib/staged.sh` | `staged_files`, `staged_export`, `staged_tree_hash` |
| `lib/checks.sh` | `run_check`, `check_chef`, `check_json`, `check_yaml`, `check_ps1`, `check_sh`, `check_py`, `run_sink` |
| `lib/wsl.sh` | `wsl_available`, `wsl_sweep_stale`, `wsl_create`, `wsl_run`, `wsl_destroy` |
| `lib/review.sh` | `review_lookup_verdict`, `review_invoke_claude`, `review_write_pending`, `review_try_resolved`, `review_run` |

`cq_not_implemented` itself is excluded from the guard test, since it has real behavior.

`hooks/pre-commit`:
- shebang `#!/bin/sh`
- sources the libs from the directory next to it
- calls `cq_not_implemented "pre-commit"` and exits with its status
- carries the marker line `# code_quality-hook v1` near the top (the installer, section-08, relies on this marker)

`scripts/install.sh`, `scripts/build-skill.sh`: `#!/usr/bin/env bash`, `set -eu`, header comment with the contract, body prints "not implemented" and `exit 1`.
`scripts/install.ps1`: same idea, `Write-Error 'not implemented'; exit 1`.

Set the exec bit on `hooks/pre-commit`, `scripts/*.sh` and `test/stubs/*`.

### 6. Test helper: `test/bats/helpers.bash`

Loaded by every `.bats` file via `load helpers`. Contract:

```bash
# test/bats/helpers.bash
common_setup() {
  # Loads vendor bats-support and bats-assert.
  # export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
  # export GIT_CONFIG_GLOBAL=/dev/null  GIT_CONFIG_NOSYSTEM=1
  # unset GIT_DIR GIT_INDEX_FILE
  # export CQ_ROOT=<repo root>
  # Prepend "$CQ_ROOT/test/stubs" to PATH; export STUB_LOG_DIR="$BATS_TEST_TMPDIR/stublog"
}

make_repo() {
  # Create "$BATS_TEST_TMPDIR/repo" via git init, set repo-local user.name/user.email,
  # copy hooks/pre-commit into .git/hooks/ along with lib/ (where the hook can source it),
  # cd into it, and echo the path. No commits yet unless asked.
}
```

Every bats `setup()` must call `common_setup`. This isolation prevents tests from reading the developer's global git config and from being polluted by `GIT_DIR`/`GIT_INDEX_FILE` leaking in from a running git hook.

### 7. Stubs in `test/stubs/`

All are POSIX sh scripts. Each appends one line (`cwd=<pwd> args=<"$@">`) to `$STUB_LOG_DIR/<name>.log`, so tests can assert on invocation count, cwd and arguments. When stdin is piped, the claude stub also saves it to `$STUB_LOG_DIR/claude.stdin`.

- `claude`: behavior is selected by `CLAUDE_STUB_MODE` (default `pass`). The session_id is always the fixed UUID `11111111-2222-4333-8444-555555555555`, unless the test overrides it with `CLAUDE_STUB_SESSION_ID`.
  - `pass`: JSON `{"type":"result","subtype":"success","is_error":false,"session_id":"<id>","structured_output":{"decision":"pass","findings":[]}}`
  - `fail`: same shell, with `decision: "fail"` and one finding object such as `{"id":"F1","location":"a.sh:1","explanation":"example finding","severity":"correctness"}`
  - `is_error`: `is_error: true`, `subtype: "success"`, no structured output
  - `nonsuccess`: `is_error: false`, `subtype: "error_max_turns"`
  - `hang`: `sleep 300` (for tests of the `timeout` path)
  - `garbage`: prints non-JSON text
  - The result field name (`structured_output`) is to be verified against the installed CLI in section-05. Keep it in one place in the stub so it is easy to change.
- `cookstyle`, `chef`, `pwsh`, `wsl.exe`: log invocation; exit status from `<NAME>_STUB_STATUS` (default 0), e.g. `COOKSTYLE_STUB_STATUS`, `CHEF_STUB_STATUS`, `PWSH_STUB_STATUS`, `WSL_STUB_STATUS`. `wsl.exe` may print nothing by default. Section-04 extends it as needed.

## Done Criteria

- All files and directories above exist with the stated placeholders and contents.
- `vendor/bats-core/bin/bats test/bats` runs, and `foundation.bats` passes for the file-existence, `.gitattributes`, `LINT-EXCEPTIONS` and guard tests.
- The isolation and stub tests pass.
- The hook and every stub function print "not implemented" and exit non-zero.
- `shellcheck` is clean on `hooks/ lib/ scripts/*.sh test/stubs/*`, or each failing path is listed in `LINT-EXCEPTIONS.md`.