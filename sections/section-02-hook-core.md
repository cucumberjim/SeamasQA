# Section 02: Hook Core

## Purpose

This section builds the skeleton and failing tests for the hook entrypoint and its two foundational libraries. It covers `hooks/pre-commit`, `lib/common.sh` and `lib/staged.sh`. Together they own everything in the commit flow except the individual linters (section 03), the WSL layer (section 04) and the review stage (section 05).

**Training exercise.** Claude does not write production logic. The deliverable here is:

- Contract-only skeleton files whose functions are empty and exit "not implemented".
- Failing bats tests that define the behavior.

The learner implements against the tests.

## Dependencies

- **section-01-foundation** must be complete. It provides:
  - The directory skeleton.
  - `.gitattributes` (LF for sh and hook files).
  - The vendored bats-core, bats-support and bats-assert.
  - The test helper that does isolation setup.
  - The stubs in `test/stubs/` (`claude`, `cookstyle`, `chef`, `pwsh`, `wsl.exe`).
  - The not-implemented guard convention.
- This section blocks section-03, section-04 and section-05. They source `lib/common.sh` and `lib/staged.sh` and are called from `hooks/pre-commit`.

Foundation convention reused here: a skeleton function body calls a helper that prints `not implemented: <function name>` to stderr and returns non-zero. If section-01 named this helper differently, use its name. Otherwise define it once in `lib/common.sh` as `cq_not_implemented`.

## Files to Create or Modify

| File | Action |
|------|--------|
| `/home/jhodgins/build/code_quality/hooks/pre-commit` | Replace the foundation placeholder with the POSIX sh entrypoint skeleton |
| `/home/jhodgins/build/code_quality/lib/common.sh` | Skeleton functions |
| `/home/jhodgins/build/code_quality/lib/staged.sh` | Skeleton functions |
| `/home/jhodgins/build/code_quality/test/bats/hook-core.bats` | New: entrypoint, chaining, sink, ordering, jq tests |
| `/home/jhodgins/build/code_quality/test/bats/common.bats` | New: skip-var semantics, platform detect |
| `/home/jhodgins/build/code_quality/test/bats/staged.bats` | New: staged list, index export, chef-root helper |

Unit tests source the libs directly. Integration tests copy the hook into a temp repo and run a real `git commit`.

## Tests First

All tests start failing because they call not-implemented stubs. Use the foundation test helper for isolation. Its setup sets:

- `HOME=$BATS_TEST_TMPDIR/home`
- `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`
- repo-local `user.name` and `user.email`
- `GIT_DIR` and `GIT_INDEX_FILE` unset

Every integration test builds a temp git repo, copies in the hook and `lib/`, and puts `test/stubs/` first on `PATH`.

### `test/bats/common.bats`

```bash
# Test: skip-var truthiness — unset, empty, and "0" are NOT skip; "1", "yes", "true" ARE skip
#   (call cq_skip_enabled SKIP_JSON with each value; assert return code)
# Test: skip name is derived from the check name — cq_skip_enabled json reads SKIP_JSON
#   (and chef→SKIP_CHEF, yaml→SKIP_YAML, ps1→SKIP_PS1, sh→SKIP_SH, py→SKIP_PY)
# Test: cq_run_check wrapper — failing check without skip → returns non-zero
# Test: cq_run_check wrapper — failing check with SKIP_<NAME>=1 → prints "WARNING" to stderr, returns 0
# Test: cq_run_check wrapper — passing check → returns 0, no WARNING
# Test: cq_run_check wrapper with SKIP_<NAME>=0 and failing check → still fails
# Test: cq_platform returns "windows" when uname reports MINGW*/MSYS*, "linux" otherwise
#   (stub `uname` on PATH)
# Test: cq_require_jq with jq missing from PATH → non-zero, stderr contains an install hint
#   (mentions "jq" and a package manager command)
# Test: cq_require_jq with jq present → returns 0
```

### `test/bats/staged.bats`

```bash
# Test: cq_staged_files emits NUL-separated paths (compare with `tr '\0' '\n'` for simple names)
# Test: cq_staged_files handles filenames with spaces and an embedded newline intact
# Test: cq_staged_files uses --diff-filter=ACMR — added, copied, modified, and renamed
#   files are listed; deleted files are not
# Test: cq_staged_files lists a renamed file under its NEW name only
# Test: cq_staged_matches '*.json' is true only if a staged file matches the extension
#   (and .yaml counts alongside .yml when asked for both)
# Test: cq_export_index creates a temp dir containing the STAGED content
#   (good staged / bad unstaged → exported file is the good one)
# Test: cq_export_index reverse (bad staged / good unstaged → exported file is bad)
# Test: cq_export_index does not touch the working tree or the real index
#   (`git status --porcelain` identical before and after; no `git stash` used)
# Test: cq_export_index temp dir is removed on exit (trap) and on SIGINT/SIGTERM
# Test: with `git commit -a`, the export reflects the files git is about to commit
#   (run from inside a real pre-commit invocation; hook sees updated index)
# Test: with `git commit <path>`, the export reflects the index git passes to the hook
#   (hook must honor GIT_INDEX_FILE as set by git; do not unset it inside the hook)
# Test: untracked files (e.g. Berksfile.lock, .kitchen/) are absent from the export
# Test: cq_find_chef_root <staged path> returns the nearest ancestor dir containing
#   metadata.rb or Policyfile.rb; returns non-zero if none
# Test: cq_find_chef_root with two nested cookbooks resolves each file to its own cookbook
#   (monorepo-safe)
# Test: cq_find_chef_root searches within the exported tree, not the working tree
```

### `test/bats/hook-core.bats`

```bash
# Test: hook is executable POSIX sh (shebang #!/bin/sh) and passes `sh -n`
# Test: missing jq → hook exits non-zero, message names jq and gives an install hint,
#   before any check or claude invocation
# Test: pre-commit.local present → runs FIRST and receives the hook's arguments
#   (local script records "$@" to a file; assert order via timestamps or a log file)
# Test: pre-commit.local non-zero → hook exits with that status; no check runs;
#   claude stub invocation count = 0
# Test: pre-commit.local absent → hook proceeds normally
# Test: hook with nothing staged → exits 0 without invoking any check or claude
# Test: CODE_QUALITY_SINK unset → no-op
# Test: CODE_QUALITY_SINK names an executable → it runs after linters and receives
#   the staged file list via NUL-delimited stdin (assert exact content,
#   including a filename with a space)
# Test: sink non-zero → commit fails; claude stub invocation count = 0
# Test: CODE_QUALITY_SINK set but not executable / nonexistent → clear error, commit fails
# Test: ordering — linters → sink → review. A log written by each stub/sink shows that
#   sequence on success
# Test: a linter failure prevents both the sink and claude from running
# Test: a sink failure prevents claude from running
# Test: SKIP_<NAME> downgrade on a failing linter lets the sink and review proceed
# Test: sink is read from the environment only — a CODE_QUALITY_SINK entry in a
#   repo-committed file (e.g. .env, .code-quality) is ignored
# Test: temp export dir is cleaned up after success and after failure
```

Integration tests that need a linter to pass or fail can use the `.json` check. Section 03 owns the real check logic. Until then, tests in this file may register a trivial fake check via an override hook (see "Check registry" below) so they do not depend on section 03.

## Implementation Details

### `hooks/pre-commit` (POSIX sh)

Contract: no bashisms. It must run under `/bin/sh` (dash) and Git for Windows' sh. Keep it thin: orchestration only, with logic in the libs.

Responsibilities, in order:

1. Resolve the lib directory. Honor `CODE_QUALITY_LIB` if set (the installer's shim sets it). Otherwise use the path relative to the hook's own location. Source `common.sh` and `staged.sh`. The review lib (`review.sh`), checks lib (`checks.sh`) and WSL lib (`wsl.sh`) are sourced only if they exist, so this section works standalone. Sections 03 to 05 add them.
2. Run `cq_require_jq`. On failure exit non-zero with an install hint, before anything else.
3. **Chain `pre-commit.local`.** If an executable `pre-commit.local` sits next to the hook (same directory), run it with `"$@"`. A non-zero status short-circuits: exit with that same status and run nothing else.
4. Compute the staged list with `cq_staged_files`. If empty, exit 0.
5. Create the index export once with `cq_export_index` and install the cleanup trap (EXIT, INT, TERM, HUP). Every check runs against this export.
6. **Run linters** through the check registry, each wrapped with `cq_run_check`. Collect failures and do not stop at the first. The developer should see all problems at once.
7. If any linter failed, exit 1. The sink and review are skipped.
8. **Run the sink** (below). Non-zero fails the commit.
9. **Run review.** If `cq_review` is defined (section 05), call it. Its status is the hook's status. If it is not defined, skip silently.
10. Exit 0.

**Ordering invariant (pin in GUIDE.md):** chain local, then linters, then sink, then review. Each stage runs only if all earlier stages passed. This saves tokens.

**Check registry.** Define the list of checks in one place, a variable such as `CQ_CHECKS="chef json yaml ps1 sh py"`. For each name the hook calls `cq_run_check <name>`, which in turn calls `check_<name>` if that function is defined and skips the name if not. Section 03 defines the real `check_*` functions. Tests here may define fake `check_json` and similar functions before invoking the hook logic, or the stub-based integration tests exercise whichever checks exist by then.

**Sink contract (decision pinned here; mirror it in GUIDE.md).** If `CODE_QUALITY_SINK` is non-empty:

- It must be an executable file. Otherwise print a clear error and fail the commit.
- Run it with the repo export as the working directory.
- Feed it the staged file list as NUL-delimited paths on stdin. Paths are relative to the repo root.
- Do not pass paths as arguments, which avoids argument-length and quoting problems.
- A non-zero exit fails the commit.

The sink variable is read from the process environment only, never from repo-committed files.

### `lib/common.sh` (sourced, POSIX sh)

Function contracts. All are skeletons, so the body is the not-implemented guard.

```sh
cq_not_implemented() { :; }   # prints "not implemented: <caller>" to stderr, returns 1 (skip if foundation already provides it)

cq_log()  { :; }  # cq_log <level> <msg...> — writes "[code_quality] <LEVEL>: msg" to stderr; levels: INFO, WARNING, ERROR
cq_warn() { :; }  # shorthand for cq_log WARNING
cq_die()  { :; }  # cq_die <msg...> — log ERROR and exit 1

cq_platform() { :; }
# stdout: "windows" if `uname -s` matches MINGW*|MSYS*|CYGWIN*, else "linux". No macOS support.

cq_skip_enabled() { :; }
# cq_skip_enabled <name>  e.g. "json"
# Reads SKIP_<UPPERCASE NAME>. Returns 0 (skip is on) iff the value is non-empty and not exactly "0".
# Returns 1 otherwise. Must not use bash indirect expansion; use eval carefully or `printenv`.
# Validate <name> against [a-z0-9_]+ first (it is interpolated).

cq_run_check() { :; }
# cq_run_check <name>
# Runs check_<name> if defined. Return 0 pass.
# On failure: if cq_skip_enabled <name>, print "WARNING: check <name> failed but SKIP_<NAME> is set" and return 0.
# Otherwise return the check's non-zero status.
# A check that is not defined is silently treated as pass.

cq_require_jq() { :; }
# Returns 0 if `jq` is on PATH. Otherwise print an install hint
# (e.g. "jq is required: apt install jq | dnf install jq | winget install jqlang.jq")
# and return non-zero.
```

Notes for the learner:

- `cq_skip_enabled` is the semantics tested by `common.bats`. The truthiness rule (non-empty and not `0`) is pinned in GUIDE.md.
- Keep output on stderr so stdout stays clean for machine-readable results.

### `lib/staged.sh` (sourced, POSIX sh)

```sh
cq_staged_files() { :; }
# stdout: NUL-separated list of staged paths.
# Uses `git diff --cached --name-only -z --diff-filter=ACMR`. Never splits on newline.
# Renames appear under the new name. Deletions are excluded.

cq_staged_matches() { :; }
# cq_staged_matches <glob>...   (e.g. '*.json', or '*.yml' '*.yaml')
# Returns 0 if any staged path matches any glob. Iterate NUL-delimited with `read -r -d ''`
# only if the shell supports it; otherwise use `xargs -0` / `case`. POSIX sh has no `read -d`,
# so prefer `cq_staged_files | tr '\0' '\n'`-free approaches such as
# `git diff --cached --name-only -z ... | xargs -0 -n1` + `case`.
# Paths with an embedded newline must not cause false matches.

cq_export_index() { :; }
# Creates ONE temp dir (mktemp -d), runs `git checkout-index -a --prefix="$tmp/"`,
# and prints the temp dir path (or sets CQ_EXPORT). Registers cleanup for EXIT/INT/TERM/HUP.
# Must honor GIT_INDEX_FILE exactly as git set it for the hook (this is how `commit <path>`
# and `commit -a` give the hook the right index). Never touches the working tree.
# `git stash --keep-index` is FORBIDDEN (data loss with partial staging).
# Untracked files are intentionally absent from the export; this is documented.

cq_export_cleanup() { :; }
# rm -rf "$CQ_EXPORT" if set and non-empty and inside the temp root. Idempotent.

cq_find_chef_root() { :; }
# cq_find_chef_root <path-relative-to-repo-root>
# Walk up from the path's directory inside $CQ_EXPORT toward the export root.
# Return (stdout) the nearest directory containing metadata.rb or Policyfile.rb.
# Non-zero if none found before reaching the root. Monorepo-safe: each staged
# path resolves independently.
```

Scope notes:

- **Why export rather than test the working tree.** Unstaged edits can mask problems. Tree-wide tools (`cookstyle .`, rspec, shellcheck `source=`, ruff config) also need a real tree to run in.
- **Why `git checkout-index -a --prefix`.** It copies index content without disturbing the working tree or index. If the learner finds `--prefix` needs a trailing slash, the tests will show it.
- **Scope decisions (pin in GUIDE.md):**
  - Checks cover staged files only, with `--diff-filter=ACMR`.
  - `.yaml` counts as well as `.yml`.
  - Chef detection is per staged path to the nearest `metadata.rb` or `Policyfile.rb`.
  - Skip variables are truthy when non-empty and not `0`.
  - Platforms are Linux and Windows only.

### Interfaces handed to other sections

- **Section 03 (checks)** defines `check_chef`, `check_json`, `check_yaml`, `check_ps1`, `check_sh` and `check_py`. Each runs against `$CQ_EXPORT`, uses `cq_staged_matches` and `cq_find_chef_root`, and returns 0 or non-zero. `cq_run_check` handles skipping.
- **Section 04 (wsl)** needs `cq_platform` and `$CQ_EXPORT`.
- **Section 05 (review)** defines `cq_review`, called last by the hook. It needs `cq_skip_enabled`-style opt-out handling for `SKIP_CODE_REVIEW` and the staged export or index.

### Skeleton "not implemented" test

The foundation section has a guard test that every skeleton function exits non-zero with "not implemented". Make sure the functions above are covered. They are covered automatically if they use `cq_not_implemented` and the guard test enumerates `lib/*.sh`.

## Suggested Implementation Order (for the learner)

1. `cq_staged_files` (NUL-safe) and `cq_staged_matches`.
2. `cq_skip_enabled`, then `cq_run_check`.
3. `cq_export_index` plus cleanup traps, then `cq_find_chef_root`.
4. `cq_require_jq` and the hook entrypoint, ending with the `pre-commit.local` chain.
5. Sink and ordering.

## Acceptance Criteria

- Every test above exists and **fails** against the skeleton, because the functions are not implemented.
- `hooks/pre-commit` passes `sh -n` and `shellcheck -s sh`.
- No function in `lib/common.sh` or `lib/staged.sh` contains logic beyond the guard call.
- Pinned decisions are written as comments or notes ready for GUIDE.md (section 09):
  - the sink contract (NUL-delimited stdin)
  - the skip truthiness rule
  - staged-only scope
  - the ordering invariant