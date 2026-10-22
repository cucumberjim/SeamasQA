# Section 03: Checks (`lib/checks.sh`)

## Goal

Create the skeleton of `lib/checks.sh` and a failing bats suite (`test/bats/checks.bats`) that defines the behavior of every per-file-type linter check. This is a training exercise. Do not write the production logic. Write contracts, empty functions that exit "not implemented", and tests that fail against them. The learner implements against the tests later.

## Dependencies

- **section-01-foundation**: directory skeleton, test helper (isolation setup in `test/bats/` helpers), stubs for `cookstyle`, `chef`, `pwsh` in `test/stubs/`, and the not-implemented guard function.
- **section-02-hook-core**: `lib/common.sh` (logging, `is_skip` truthiness helper, platform detect) and `lib/staged.sh` (NUL-safe staged list with `--diff-filter=ACMR`, one index export per run into `$CQ_EXPORT`). This section consumes them and does not redefine them. If their exact function names differ, adapt the calls. The contract below only needs "staged file list", "export dir", "is skip var truthy", and "warn/log".

Section-04 (WSL) provides the wrapper that runs `sh` and `py` checks inside WSL on Windows. Here, call the tools directly from PATH. Leave a single, clearly named seam (`run_tool`) so the WSL section can reroute it.

## Tests (write first)

File: `/home/jhodgins/build/code_quality/test/bats/checks.bats`. Load the foundation helper (HOME/GIT_CONFIG_GLOBAL/GIT_CONFIG_NOSYSTEM isolation, unset GIT_DIR/GIT_INDEX_FILE), put `test/stubs/` on PATH, and build a temp git repo per test. Every test must fail against the skeleton, because the functions return "not implemented".

Stub tests (bodies are the learner's or the section implementer's to flesh out, with the assertions described):

```bash
# --- Selection ---
@test "json check runs only when a staged .json file exists"
@test "yaml check matches both .yml and .yaml"
@test "only ACMR files are considered (deleted .json does not trigger json check)"
@test "staged filename with spaces and a newline survives into the check"   # NUL-safe

# --- JSON ---
@test "invalid staged json fails; valid passes"
@test "json check falls back to python3 -m json.tool when jq is absent from PATH"

# --- YAML ---
@test "invalid .yml fails; valid passes"
@test "invalid .yaml fails; valid passes"

# --- Index, not working tree ---
@test "good staged / bad unstaged json passes"
@test "bad staged / good unstaged json fails"

# --- PowerShell ---
@test ".ps1 staged with pwsh missing from PATH fails (hard fail)"
@test ".ps1 staged with pwsh missing and SKIP_PS1=1 warns and passes"
@test "pwsh stub failure (PSScriptAnalyzer exit non-zero) fails the check"

# --- Shell / Python ---
@test "invalid staged .sh fails shellcheck; valid passes"
@test "invalid staged .py fails ruff; valid passes"

# --- Chef ---
@test "chef detection finds the nearest metadata.rb for a nested cookbook"
@test "chef detection also accepts Policyfile.rb"
@test "chef check runs 'cookstyle .' and 'chef exec rspec' in the cookbook dir (stubs record cwd and args)"
@test "staged .rb outside any cookbook does not trigger chef check"

# --- Skip semantics (per-check wrapper) ---
@test "skip var truthiness: unset, empty and '0' are not skips; '1' and 'yes' are"
@test "each of SKIP_CHEF SKIP_JSON SKIP_YAML SKIP_PS1 SKIP_SH SKIP_PY downgrades a failing check to WARNING and exit 0"
@test "skip var does not suppress a passing check's output or run"

# --- Missing tools ---
@test "missing tool prints an install hint and fails unless skipped"
@test "missing tool with its SKIP_ var set warns and passes"
```

Fixtures live in `/home/jhodgins/build/code_quality/test/fixtures/` (valid/invalid json, yml, sh, py, ps1, a nested chef cookbook). Section-01 creates the directory. Add any missing fixture files here. The `claude` stub is not needed in these tests. Call `run_checks` (or each `check_*` function) directly with `CQ_EXPORT` pointing at a temp export, plus a few full `git commit` runs for the index-vs-working-tree cases.

## Implementation (skeleton only)

File: `/home/jhodgins/build/code_quality/lib/checks.sh` (sourced, no shebang execution, no top-level side effects). Every body below calls the foundation's not-implemented guard (for example `not_implemented "<fn>"`), which prints "not implemented" and returns non-zero.

### Contract: per-check function

Each check is `check_<name>` and takes no arguments. It reads the staged list and export dir from the section-02 libs, and returns 0 for pass or non-zero for fail. It must not decide about skipping. The wrapper does.

```sh
check_json()   { not_implemented check_json; }
check_yaml()   { not_implemented check_yaml; }
check_ps1()    { not_implemented check_ps1; }
check_sh()     { not_implemented check_sh; }
check_py()     { not_implemented check_py; }
check_chef()   { not_implemented check_chef; }
```

### Contract: wrapper and runner

```sh
# run_check <name>: consults SKIP_<NAME> (upper-cased). Runs check_<name> only if
# it applies (see Selection). On failure: if skip var is truthy, print WARNING and
# return 0; else return the check's non-zero status.
run_check()  { not_implemented run_check; }

# run_checks: runs json yaml ps1 sh py chef via run_check. Runs ALL checks, then
# returns non-zero if any failed (so the developer sees every problem at once).
run_checks() { not_implemented run_checks; }

# run_tool <cmd> [args...]: the single seam where tools are executed.
# Direct exec here. Section-04 reroutes sh/py through WSL on Windows.
run_tool()   { not_implemented run_tool; }
```

### Behavior to implement against the tests

**Selection.** A check applies when at least one staged file (added/copied/modified/renamed, `--diff-filter=ACMR`, NUL-separated) matches its extension: `.json`; `.yml`/`.yaml`; `.ps1`; `.sh`; `.py`. The chef check applies when a staged path has a nearest ancestor containing `metadata.rb` or `Policyfile.rb`. Find the nearest one by walking up from each staged path to the repo root, which is monorepo-safe. Run the chef tools once per distinct cookbook directory. A `.rb` file outside any cookbook does not trigger chef.

**Content source.** Every check runs on the index export (`$CQ_EXPORT`), never the working tree. Lint the exported copies of the staged files, and for tree-wide tools run with cwd in the export (for example `cd "$CQ_EXPORT/<cookbook>" && cookstyle .`).

**Tools** (from PATH; nothing vendored):

| Check | Tool |
|-------|------|
| json | `jq empty`, fallback `python3 -m json.tool` if `jq` is not on PATH |
| yaml | `yq` if present, else `python3 -c 'import sys,yaml; yaml.safe_load(sys.stdin)'` |
| ps1 | `pwsh` with PSScriptAnalyzer: `Invoke-ScriptAnalyzer -EnableExit -Severity Error,Warning` |
| sh | `shellcheck` |
| py | `ruff check` (documented alternative: flake8) |
| chef | `cookstyle .` then `chef exec rspec`, both from the cookbook dir |

Pass file names to tools NUL-safely (`xargs -0` or a `while IFS= read -r -d ''` loop). Never word-split.

**Missing tools.** If the tool is absent, print an install hint naming the tool (and the platform's usual package), then fail, unless the check's skip var is set. `pwsh` missing for a staged `.ps1` is a hard fail like any other missing tool, with no special exemption. `SKIP_PS1=1` downgrades it to a warning.

**Skip semantics.** `SKIP_<NAME>` is truthy when non-empty and not `0`. Use the section-02 helper and do not reimplement it. Names: `SKIP_CHEF`, `SKIP_JSON`, `SKIP_YAML`, `SKIP_PS1`, `SKIP_SH`, `SKIP_PY`. A skipped check that fails prints a line beginning `WARNING` naming the check and counts as pass.

**Output.** Failures print the file (or cookbook dir) and the tool's message to stderr. Keep output terse.

### Out of scope here

- WSL execution of sh/py on Windows (section-04; use `run_tool` as the seam).
- Sink and review ordering (section-02 / section-05). `run_checks` only reports pass/fail to the hook.
- Dogfood shellcheck of `lib/checks.sh` itself (section-09). Write the skeleton so it passes shellcheck anyway.

## Done when

- `lib/checks.sh` exists with the functions above, all returning "not implemented", and passes `shellcheck`.
- `test/bats/checks.bats` contains every test listed above, and every one fails for the right reason (not-implemented, not a syntax error or missing fixture).
- Needed fixtures exist under `test/fixtures/` (valid and invalid json, yml, yaml, sh, py, ps1, plus a nested cookbook with `metadata.rb`).