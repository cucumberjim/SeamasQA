<!-- PROJECT_CONFIG
runtime: bash-bats
test_command: vendor/bats-core/bin/bats test/bats
END_PROJECT_CONFIG -->

<!-- SECTION_MANIFEST
section-01-foundation
section-02-hook-core
section-03-checks
section-04-wsl
section-05-review-verdict
section-06-skill
section-07-build-script
section-08-installer
section-09-guide-and-dogfood
END_MANIFEST -->

# Implementation Sections Index

Training exercise: sections produce skeleton + docs + failing tests only (no implementation logic).

## Dependency Graph

| Section | Depends On | Blocks | Parallelizable |
|---------|------------|--------|----------------|
| section-01-foundation | - | all | Yes |
| section-02-hook-core | 01 | 03, 04, 05 | No |
| section-03-checks | 02 | 09 | Yes |
| section-04-wsl | 02 | 09 | Yes |
| section-05-review-verdict | 02 | 07, 08, 09 | Yes |
| section-06-skill | 01 | 07, 09 | Yes |
| section-07-build-script | 05, 06 | 09 | Yes |
| section-08-installer | 05, 06 | 09 | Yes |
| section-09-guide-and-dogfood | 03, 04, 05, 07, 08 | - | No |

## Execution Order

1. section-01-foundation
2. section-02-hook-core, section-06-skill (parallel after 01)
3. section-03-checks, section-04-wsl, section-05-review-verdict (parallel after 02)
4. section-07-build-script, section-08-installer (parallel after 05 and 06)
5. section-09-guide-and-dogfood

## Section Summaries

### section-01-foundation
Directory skeleton, .gitattributes, LINT-EXCEPTIONS.md, vendored bats (+support/assert) placeholders, test helpers (isolation setup), stubs for claude/cookstyle/chef/pwsh/wsl.exe, not-implemented guard functions. Plan sections 1, 3, 10.

### section-02-hook-core
hooks/pre-commit, lib/common.sh, lib/staged.sh: jq check, pre-commit.local chaining, staged list (ACMR, NUL-safe), checkout-index export, skip-var semantics, sink, ordering. Plan sections 2, 4 (non-WSL, non-check parts).

### section-03-checks
lib/checks.sh: chef (nearest metadata.rb), json, yaml/yml, ps1, sh, py checks, tool-missing handling, per-check skip. Plan section 4 Tools/contract.

### section-04-wsl
lib/wsl.sh, docs/WSL2-INSTALL.md, Pester tests: ephemeral Rocky lifecycle, cache tarball, sweep, UTF-16, MSYS path handling.

### section-05-review-verdict
lib/review.sh: write-tree hash, verdict/pending store, pass rules 1 and 2, claude invocation and failure modes, exclusions, UUID validation, opt-outs. Plan section 5.

### section-06-skill
skill/code-review/SKILL.md skeleton, strictness, security checklist, conventions file, references/ placeholders and prompts for eight languages. Plan section 6.

### section-07-build-script
scripts/build-skill.sh contract and tests. Plan section 7.

### section-08-installer
install.sh/install.ps1 contracts, marker shim, uninstall, tests (bats + Pester). Plan section 8.

### section-09-guide-and-dogfood
GUIDE.md (contracts, order, honour-system, open questions, recommendations), dogfood shellcheck test, integration end-to-end tests. Plan sections 9, 11, 12.
