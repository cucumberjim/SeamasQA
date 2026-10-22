load helpers

@test "common_setup isolates HOME and git config" {
  export GIT_DIR=/x GIT_INDEX_FILE=/y
  common_setup
  [ "$HOME" = "$BATS_TEST_TMPDIR/home" ]
  [ "$GIT_CONFIG_GLOBAL" = /dev/null ]
  [ "$GIT_CONFIG_NOSYSTEM" = 1 ]
  [ -z "${GIT_DIR:-}" ]
  [ -z "${GIT_INDEX_FILE:-}" ]
}

@test "make_repo creates repo with hook, user config, stubs first on PATH" {
  common_setup
  repo="$(make_repo)"
  [ -d "$repo/.git" ]
  [ -f "$repo/.git/hooks/pre-commit" ]
  [ "$(git -C "$repo" config user.name)" = "Test User" ]
  [ "$(git -C "$repo" config user.email)" = "test@example.com" ]
  [ "${PATH%%:*}" = "$CQ_ROOT/test/stubs" ]
}
