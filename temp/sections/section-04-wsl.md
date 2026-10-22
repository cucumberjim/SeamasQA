# Section 04: WSL Ephemeral Linting Environment (Windows)

## Overview

This section covers the Windows-only path where the `sh` and `py` checks run inside an ephemeral Rocky Linux WSL2 distro. It delivers:

- `lib/wsl.sh`: skeleton functions (contracts only, each fails "not implemented")
- `docs/WSL2-INSTALL.md`: terse real documentation, echoed by the hook when WSL is missing
- Pester 5 tests (`test/pester/Wsl.Tests.ps1`) that define the behavior and start out failing
- A small bats test for the docs file

This is a training exercise. Claude writes the skeleton, docs and failing tests. The learner writes the logic. Do not implement the function bodies.

**Dependencies (reference only):**
- section-01-foundation: directory skeleton, the `wsl.exe` stub in `test/stubs/`, the not-implemented guard helper, bats helper setup.
- section-02-hook-core: `lib/common.sh` (logging helpers, platform detection via `uname` MINGW/MSYS, skip handling). `wsl.sh` is sourced by the hook and used by `check_sh` and `check_py` (section-03) on Windows only. Section 03 calls into `wsl.sh`. This section must not edit `checks.sh`.

## Background

On Windows (Git for Windows, bash from MSYS), shellcheck and ruff are not readily available. The hook therefore runs those tools in a throwaway Linux environment. Rocky Linux under WSL2 is the chosen base. The design is fragile for these reasons, and the tests should pin each one:

- Traps do not fire on SIGKILL, so a startup sweep of stale `cq-*` distros is required.
- `wsl -l` and `wsl --status` print UTF-16LE. Embedded NULs must be stripped before parsing.
- WSL1 does not work. WSL2 is required.
- Git Bash (MSYS) rewrites argument paths such as `/mnt/c`. Set `MSYS_NO_PATHCONV=1` and `MSYS2_ARG_CONV_EXCL='*'`.
- `wsl --unregister` does not always remove the import directory. Delete it explicitly.
- Failure to create the instance fails the check. It is not a warning.

## Tests First

File: `/home/jhodgins/build/code_quality/test/pester/Wsl.Tests.ps1` (Pester 5). The PowerShell tests mock `wsl` (a function or `Mock wsl`). They exercise the logic through a PowerShell-callable surface for `wsl.sh`. Choose one approach and document it at the top of the test file. The simplest is invoking bash on `lib/wsl.sh` with the `wsl.exe` stub from `test/stubs/` on PATH, and asserting on the stub's recorded call log. The stub must record its args to a log file so tests can assert on calls.

Test stubs (prose only, as listed in the TDD plan):

```
# Pester: WSL absent → doc content echoed, check fails
#   Arrange: no wsl.exe on PATH (or stub exits non-zero for --status).
#   Assert: output contains the text of docs/WSL2-INSTALL.md; function returns non-zero.

# Pester: distro name matches cq-<pid>-<rand>; unregister and import dir removal called on success and on failure
#   Assert: name matches ^cq-\d+-[A-Za-z0-9]+$.
#   Assert: stub log shows terminate + unregister, and the import directory is deleted,
#   both when the tool run succeeds and when it fails (and on trapped signal).

# Pester: stale cq-* sweep at start; UTF-16 `wsl -l` output parsed; WSL1 rejected
#   Arrange: stub `wsl -l -q` emits UTF-16LE listing containing cq-111-abc, cq-222-def, and Ubuntu.
#   Assert: only the cq-* names are unregistered; non-cq distros are never touched.
#   Assert: a distro/status reporting WSL version 1 is rejected (non-zero, message mentions WSL2).

# Pester: MSYS_NO_PATHCONV set; paths converted via wslpath
#   Assert: MSYS_NO_PATHCONV=1 and MSYS2_ARG_CONV_EXCL='*' are exported before any wsl call;
#   the Windows path of the staged export is mapped with wslpath / a /mnt/c path.
```

Additional tests worth adding, still prose:

```
# Pester: cache miss provisions the Rocky base once and `wsl --export`s it under %LOCALAPPDATA%\code_quality\; cache hit skips provisioning.
# Pester: instance creation failure (import returns non-zero) → check fails, nothing left registered.
# Pester: tools are run via `wsl -d <name> -u root -- bash -lc`.
```

Bats test (in `/home/jhodgins/build/code_quality/test/bats/docs.bats`, or appended if section-09 already created it):

```
# Test: WSL2-INSTALL.md contains the install commands
#   Assert it contains: wsl --install --no-distribution, wsl --set-default-version 2, wsl --update
```

Also, every function in `lib/wsl.sh` must be covered by the foundation's "skeleton functions exit non-zero with 'not implemented'" guard test, so use the foundation's not-implemented helper rather than inventing a new one.

## Implementation: `lib/wsl.sh`

Skeleton only: POSIX sh, sourced (not executed), no top-level side effects. Each function body calls the foundation's not-implemented helper. Document each contract in a docstring comment. Suggested functions and contracts:

```sh
# wsl_available
#   0 if wsl.exe is on PATH and `wsl --status` succeeds and default version is 2.
#   Otherwise prints the contents of docs/WSL2-INSTALL.md (installed copy resolved
#   relative to the lib dir) and returns non-zero. Output of wsl is UTF-16: pipe through wsl_decode.
wsl_available() { not_implemented wsl_available; }

# wsl_decode
#   stdin: UTF-16LE text from wsl.exe. stdout: UTF-8 with NULs (and CRs) stripped (tr -d '\0\r').
wsl_decode() { not_implemented wsl_decode; }

# wsl_sweep_stale
#   Lists distros (`wsl -l -q`, decoded), unregisters every name matching ^cq-, and
#   removes their import dirs. Never touches non-cq names. Run at the start of every WSL use.
wsl_sweep_stale() { not_implemented wsl_sweep_stale; }

# wsl_ensure_base
#   Ensures the cached Rocky base tarball exists at "$LOCALAPPDATA/code_quality/rocky-base.tar".
#   If missing: download the Rocky WSL image from
#   https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-WSL-Base.latest.x86_64.wsl
#   (override with CODE_QUALITY_ROCKY_URL; cache the download under $LOCALAPPDATA/code_quality/), import it temporarily, install shellcheck
#   (via EPEL) and ruff (pip), `wsl --export` it to the cache, then unregister the temp distro.
#   Returns non-zero if provisioning fails.
wsl_ensure_base() { not_implemented wsl_ensure_base; }

# wsl_create <name>
#   `wsl --import <name> <install_dir> <cache tarball> --version 2`. Sets a trap on
#   EXIT/INT/TERM/HUP that calls wsl_destroy. Non-zero on failure (the check then fails).
wsl_create() { not_implemented wsl_create; }

# wsl_destroy <name>
#   `wsl --terminate <name>`, `wsl --unregister <name>`, and delete the import
#   directory (rm -rf). Idempotent; safe to call twice.
wsl_destroy() { not_implemented wsl_destroy; }

# wsl_path <windows-or-msys-path>
#   Echoes the in-distro path (via `wslpath -u`, or /mnt/<drive>/... mapping).
wsl_path() { not_implemented wsl_path; }

# wsl_run <name> <command...>
#   Runs `wsl -d <name> -u root -- bash -lc "<command>"`, with
#   MSYS_NO_PATHCONV=1 and MSYS2_ARG_CONV_EXCL='*' exported. Returns the tool's exit status.
wsl_run() { not_implemented wsl_run; }

# wsl_with_instance <command...>
#   Top-level entry used by check_sh / check_py (section-03):
#   wsl_available -> wsl_sweep_stale -> wsl_ensure_base -> name=cq-$$-<rand> -> wsl_create
#   -> wsl_run -> wsl_destroy (always, success or failure). Returns the tool's status;
#   non-zero if any setup step failed.
wsl_with_instance() { not_implemented wsl_with_instance; }
```

Name format is `cq-<pid>-<rand>`. `<rand>` is alphanumeric (for example `$RANDOM`, or the first 6 chars of `/dev/urandom` through `tr`).

Requirements recap for the learner (put these in the file header comment):
1. Check WSL2, not just WSL.
2. Strip NULs from every `wsl` text output.
3. Always clean up: terminate, unregister, and delete the import dir. Trap EXIT/INT/TERM/HUP.
4. Sweep stale `cq-*` at startup, since SIGKILL leaves orphans.
5. Export the MSYS variables before any `wsl` call and map paths with `wslpath`.
6. Instance creation failure means the check fails.

## Implementation: `docs/WSL2-INSTALL.md`

This one is real content, not a stub. Keep it terse. Required content:

```markdown
# WSL2 setup for code_quality (Windows)

The pre-commit hook runs shellcheck and ruff inside a temporary Rocky Linux WSL2
instance. You need WSL2 installed once per machine.

1. Open PowerShell **as Administrator** and run:

       wsl --install --no-distribution

2. Reboot when prompted.
3. Make sure hardware virtualization is enabled in BIOS/UEFI (Intel VT-x / AMD-V,
   and "Virtual Machine Platform" in Windows Features).
4. Set WSL2 as the default and update:

       wsl --set-default-version 2
       wsl --update

5. Verify:

       wsl --status

   The default version must be 2. No distro needs to be installed; the hook
   creates and removes its own (`cq-*` names) per commit.

To skip these checks instead: `SKIP_SH=1` and `SKIP_PY=1` downgrade failures to warnings.
```

The hook echoes this file verbatim when WSL is unavailable, so keep it plain text with no relative links.

## Files to Create or Modify

- `/home/jhodgins/build/code_quality/lib/wsl.sh` (skeleton, above)
- `/home/jhodgins/build/code_quality/docs/WSL2-INSTALL.md` (real content)
- `/home/jhodgins/build/code_quality/test/pester/Wsl.Tests.ps1` (failing Pester tests)
- `/home/jhodgins/build/code_quality/test/bats/docs.bats` (WSL2-INSTALL.md assertions)
- `/home/jhodgins/build/code_quality/test/stubs/wsl.exe`: extend the foundation stub if needed so it logs args and can emit UTF-16LE for `-l -q`, report WSL version 1 or 2 for `--status`, and fail `--import` on demand through env vars.

`lib/wsl.sh` must pass shellcheck (dogfood test). It is POSIX sh, LF line endings, and carries the `# shellcheck shell=sh` directive.

## Done Criteria

- `docs.bats` WSL2 test passes. The Pester tests and the not-implemented guard fail or pass as designed (Pester failing against the skeleton).
- Every function in `wsl.sh` is documented with its contract and exits "not implemented".
- No logic written beyond the stubs.