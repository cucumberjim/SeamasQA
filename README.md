# Code Quality

An AI skill and supporting scripts and files to assist with code quality checks
as a `git commit` hook.

## Conventions

* Must support both Windows and Linux (bash/zsh)
* All files must pass linters or have exceptions captured in an exception file
  and documented so that they pass.
* Reusing FOSS code with an appropriate license is acceptable, but must be
  vendored as part of a build and code to reference the vendored copy when
  running.

## Running tests

Bats-core, bats-support and bats-assert are vendored under `vendor/`
(pinned versions in `vendor/README.md`), so nothing needs installing for bash
tests. Run from the repo root:

```sh
vendor/bats-core/bin/bats test/bats                 # all bash tests
vendor/bats-core/bin/bats test/bats/stubs.bats      # one file
vendor/bats-core/bin/bats -f "make_repo" test/bats  # tests matching a name
```

PowerShell tests use [Pester 5](https://pester.dev) (not vendored; install once
with `Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser`):

```sh
pwsh -NoProfile -Command "Invoke-Pester -Path test/pester -Output Detailed"
```

Tests start out failing by design: they call not-implemented stubs until you
implement them. On Windows, run the bats commands from Git Bash.

## Running linters

Every file must pass these or be listed in `LINT-EXCEPTIONS.md` (`vendor/` is
excluded). Install the tools from your package manager or from PyPI/PSGallery.

```sh
shellcheck hooks/pre-commit lib/*.sh scripts/*.sh test/stubs/*   # shell
shellcheck -s bats test/bats/*.bats                              # bats files
shellcheck -s bash test/bats/helpers.bash
jq empty file.json            # JSON (or: python3 -m json.tool file.json)
yamllint .                    # YAML (or: yq . file.yml)
ruff check .                  # Python (alternative: flake8)
cookstyle .                   # Chef/Ruby, in a cookbook directory
pwsh -NoProfile -Command "Invoke-ScriptAnalyzer -Path scripts -Recurse -EnableExit"  # PowerShell
```

## REQUIREMENTS.md

This file is used to create the roadmap for use with the Deep Plan skill.

