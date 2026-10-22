# Section 07: Build Script (`scripts/build-skill.sh`)

## Purpose

`scripts/build-skill.sh` regenerates the per-language checklist files in `skill/code-review/references/<lang>.md` by running `claude -p` once per prompt template in `skill/code-review/prompts/<lang>.md`. The generated references are committed to the repo, so the build is a maintainer tool and not part of a normal commit. This section delivers:

- the script skeleton, with a contract and a "not implemented" body;
- the failing bats tests that define its behavior.

**Training-exercise rule:** Claude writes the skeleton and tests only. The learner writes the logic.

## Dependencies

- **section-05-review-verdict:** the `claude` invocation conventions (`claude -p --output-format json`, the JSON result field, `SKIP_CODE_REVIEW`). The build script reuses the same stub-friendly invocation style.
- **section-06-skill:** the `skill/code-review/prompts/` directory with eight prompt templates, and the `references/` directory (committed placeholders). The line budget used for validation is the same one the skill tests enforce.
- **section-01-foundation:** test helpers (isolation `setup`), the `claude` stub in `test/stubs/`, and the not-implemented guard convention.

Do not duplicate those sections' content. Use their outputs.

## Languages

The eight languages, each one prompt and one reference file:

`ruby`, `chef`, `powershell`, `python`, `shell`, `cmd`, `csharp`, `javascript`

If section-06 chose different file basenames, use those. The script derives the language list from the `prompts/*.md` filenames and never hard-codes it.

## Tests First

File: `/home/jhodgins/build/code_quality/test/bats/build-skill.bats`

All tests must fail initially, because the script body only prints "not implemented" and exits non-zero. Load the vendored bats-support/assert helpers and the shared isolation helper from section-01 (HOME, `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_NOSYSTEM`, repo-local git identity, `GIT_DIR`/`GIT_INDEX_FILE` unset).

### Test environment (`setup`)

Each test builds a throwaway git repo under `$BATS_TEST_TMPDIR` and copies in `scripts/build-skill.sh` and a minimal `skill/code-review/{prompts,references}` tree, usually two or three prompt files (for example `python.md`, `shell.md`) rather than all eight, to keep tests fast. It puts `test/stubs/` first on PATH. The `claude` stub is driven by an env var for its mode. The build tests need these stub modes, which the stub must support or be extended to support:

- `good`: emits JSON whose result text is a valid checklist (non-empty, under budget).
- `empty`: result text is empty.
- `overbudget`: result text exceeds the line budget (for example 200 lines).
- `error`: `is_error: true` or a non-zero exit.

Make the stub's output include the language name taken from the prompt on stdin or in an argument. That lets a test assert that each file got its own content. The stub also appends one line per invocation to a log file (`$STUB_LOG`), so tests can count calls and see which prompt was used.

### Test stubs (prose; implement as bats `@test` blocks)

```bash
# Test: generates references/<lang>.md for every prompts/<lang>.md using stub claude
#   - run build-skill.sh with no args in the temp repo
#   - assert status 0; one references/<lang>.md exists per prompt; each is non-empty
#   - assert stub log shows one invocation per prompt

# Test: --lang python regenerates only python
#   - pre-populate references/shell.md with sentinel text
#   - run build-skill.sh --lang python
#   - assert references/python.md written; references/shell.md still has the sentinel; stub log has exactly one call

# Test: unknown --lang (no matching prompt) exits non-zero with a clear message, writes nothing

# Test: empty generated output leaves existing reference file untouched
#   - sentinel in references/python.md; stub mode=empty
#   - assert file unchanged; script reports the failure (non-zero exit or clear warning per contract below)

# Test: over-budget generated output leaves existing reference file untouched
#   - same as above with stub mode=overbudget

# Test: claude error (is_error / non-zero exit) leaves existing file untouched; no partial/temp file left behind in references/

# Test: one language failing does not stop the others from being generated; overall exit is non-zero

# Test: --commit commits only the reference paths
#   - stage an unrelated file (other.txt) before running build-skill.sh --commit
#   - after run: the new commit contains only references/*.md; other.txt is still staged and uncommitted
#   - the repo's pre-commit hook (if installed in the temp repo; use a hook that fails if SKIP_CODE_REVIEW is unset) is not blocking, which shows SKIP_CODE_REVIEW=1 was set for the commit

# Test: --commit with nothing changed (references identical) exits 0 and creates no commit

# Test: script does not read model/strictness config from files in the repo (only env), same rule as the hook
```

## Implementation Contract

File to create: `/home/jhodgins/build/code_quality/scripts/build-skill.sh` (POSIX sh or bash, LF line endings, executable bit, must pass shellcheck: it is covered by the dogfood test).

### Skeleton

Create only the interface and a not-implemented body, following the foundation convention:

```sh
#!/usr/bin/env bash
# build-skill.sh - regenerate skill/code-review/references/<lang>.md via `claude -p`.
#
# Usage: build-skill.sh [--lang <name>] [--commit]
# Exit:  0 all requested languages generated (and committed if --commit)
#        1 at least one language failed (existing files left untouched)
#        2 usage error
set -eu

parse_args()        { echo "not implemented" >&2; return 1; }   # sets LANG_FILTER, DO_COMMIT
list_languages()    { echo "not implemented" >&2; return 1; }   # prompts/*.md basenames, or the single --lang
generate_reference(){ echo "not implemented" >&2; return 1; }   # $1=lang -> candidate text on stdout
validate_reference(){ echo "not implemented" >&2; return 1; }   # $1=candidate file; non-empty and within budget
install_reference() { echo "not implemented" >&2; return 1; }   # atomically replace references/<lang>.md
commit_references() { echo "not implemented" >&2; return 1; }   # git commit -- <ref paths> with SKIP_CODE_REVIEW=1

main() { echo "not implemented" >&2; exit 1; }
main "$@"
```

### Behavior to implement (learner's job)

1. **Inputs and outputs.** For each `skill/code-review/prompts/<lang>.md`, produce `skill/code-review/references/<lang>.md`. Resolve paths relative to the script's own repo root, not the cwd.
2. **Generation.** The prompt template is piped to `claude -p --output-format json` over stdin. Parse the result text with `jq`. Check `is_error` and a non-success `subtype`, as the hook does. Use the same `REVIEW_MODEL` env var if set. Use a read-only or no-tool invocation, because generation needs no tools. Apply a `timeout`.
3. **Output shape.** The prompt asks for a condensed checklist with security items first and nit items marked, with a hard budget of at most 60 lines. Put the budget in one named constant. The skill tests from section-06 assert the same limit.
4. **Validation before writing.** Write the candidate to a temp file inside `references/` (same filesystem) and check that it is non-empty (ignore whitespace-only) and has at most the budgeted number of lines. Only if valid, `mv` it over the target. On any failure, delete the temp file, leave the existing reference untouched, print a clear message naming the language, and record the failure.
5. **Failure isolation.** Failure of one language must not stop the rest. Exit 1 at the end if any failed. LLM output is nondeterministic, so never assume the same output twice.
6. **`--lang <x>`.** Only that language. If `prompts/<x>.md` does not exist, exit 2 with a message that lists the available languages.
7. **`--commit`.** After generation, commit only the reference paths: `git commit -m "<msg>" -- <paths>`. The `--` path form leaves other staged files alone. Set `SKIP_CODE_REVIEW=1` in the environment of that commit only, because the repo's own hook would otherwise spend a review on generated files. If nothing changed (`git diff --quiet` on those paths, and no untracked new references), do not commit and exit 0. Include newly created references (`git add -N`, or add the paths explicitly, before the path-limited commit).
8. **Trust boundary.** Model and strictness come from the environment only, never from repo files.

### Open design questions (note in GUIDE.md; do not decide here)

- Should `--commit` fail if some languages failed, or commit the ones that succeeded? Suggested default: commit the successful ones and exit 1.
- Is a cheaper model appropriate for generation than for review? This is the single `REVIEW_MODEL` variable, so there is no separate knob for now (YAGNI).

## Files Touched by This Section

- Create `/home/jhodgins/build/code_quality/scripts/build-skill.sh` (skeleton, executable).
- Create `/home/jhodgins/build/code_quality/test/bats/build-skill.bats` (failing tests above).
- Extend `/home/jhodgins/build/code_quality/test/stubs/claude` with the `good`, `empty`, `overbudget` and `error` build modes and the `$STUB_LOG` invocation log, if the section-01 stub lacks them. Keep the pass/fail/is_error/hang/garbage review modes working.

## Done Criteria

- `vendor/bats-core/bin/bats test/bats/build-skill.bats` runs, and every test fails because the script is not implemented. None fail from syntax errors or missing fixtures.
- The script passes shellcheck.
- The skeleton contains no production logic.