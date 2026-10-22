# shellcheck shell=sh
# Module: staged. Staged-file listing and the index export that checks run against.
# Contract: POSIX sh, sourced.
#
# Pinned decisions (carry into GUIDE.md):
#   - Checks cover STAGED files only (--diff-filter=ACMR); .yaml counts as well as .yml.
#   - Chef root = nearest ancestor with metadata.rb or Policyfile.rb, per staged path.
#   - Untracked files are intentionally absent from the export.
#   - `git stash --keep-index` is FORBIDDEN.

# stdout: NUL-separated staged paths (git diff --cached --name-only -z --diff-filter=ACMR).
# Renames appear under the new name; deletions are excluded. Never split on newline.
cq_staged_files() { cq_not_implemented "cq_staged_files"; }

# cq_staged_matches <glob>...   Return 0 if any staged path matches any glob.
# Embedded newlines in a path must not cause false matches.
cq_staged_matches() { cq_not_implemented "cq_staged_matches"; }

# Creates ONE temp dir holding the staged content (git checkout-index -a --prefix),
# SETS $CQ_EXPORT (prints nothing; must be called in the current shell, not $(...)),
# and registers cleanup for EXIT INT TERM HUP. Honors GIT_INDEX_FILE as git set it.
cq_export_index() { cq_not_implemented "cq_export_index"; }

# rm -rf "$CQ_EXPORT" when set, non-empty and a directory. Idempotent.
cq_export_cleanup() { cq_not_implemented "cq_export_cleanup"; }

# cq_find_chef_root <path-relative-to-repo-root>
# stdout: absolute dir inside $CQ_EXPORT of the nearest ancestor holding metadata.rb or
# Policyfile.rb. Non-zero if none. Searches the export, not the working tree.
cq_find_chef_root() { cq_not_implemented "cq_find_chef_root"; }
