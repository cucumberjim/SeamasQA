# shellcheck shell=sh
# Module: common. Logging, skip-variable semantics, platform detect, jq check.
# Contract: POSIX sh, sourced. Diagnostics go to stderr; stdout stays clean.
#
# Pinned decisions (carry into GUIDE.md):
#   - Skip variables SKIP_<NAME> are truthy when non-empty and not exactly "0".

cq_not_implemented() {
    echo "not implemented: $1" >&2
    return 1
}

# cq_log <LEVEL> <msg...>  -> "[code_quality] <LEVEL>: msg" on stderr (INFO|WARNING|ERROR)
cq_log() { cq_not_implemented "cq_log"; }
# cq_warn <msg...>  -> cq_log WARNING
cq_warn() { cq_not_implemented "cq_warn"; }
# cq_die <msg...>  -> log ERROR, exit 1
cq_die() { cq_not_implemented "cq_die"; }

# stdout: "windows" if `uname -s` matches MINGW*|MSYS*|CYGWIN*, else "linux".
cq_platform() { cq_not_implemented "cq_platform"; }

# cq_skip_enabled <name>   e.g. json -> reads SKIP_JSON
# Return 0 iff SKIP_<NAME> is non-empty and not "0". <name> must match [a-z0-9_]+
# (it is interpolated); anything else returns non-zero. No bash indirect expansion.
cq_skip_enabled() { cq_not_implemented "cq_skip_enabled"; }

# cq_run_check <name>
# Runs check_<name> if defined (undefined = pass). On failure: if cq_skip_enabled <name>,
# print "WARNING: check <name> failed but SKIP_<NAME> is set" to stderr and return 0;
# otherwise return the check's own non-zero status.
cq_run_check() { cq_not_implemented "cq_run_check"; }

# Return 0 if jq is on PATH; else print an install hint naming jq and a package
# manager command on stderr and return non-zero.
cq_require_jq() { cq_not_implemented "cq_require_jq"; }
