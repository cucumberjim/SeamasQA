# Shared bats helper. Every .bats file: load helpers; setup() { common_setup; }

common_setup() {
  CQ_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export CQ_ROOT
  load "$CQ_ROOT/vendor/bats-support/load"
  load "$CQ_ROOT/vendor/bats-assert/load"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  unset GIT_DIR GIT_INDEX_FILE
  export STUB_LOG_DIR="$BATS_TEST_TMPDIR/stublog"
  mkdir -p "$STUB_LOG_DIR"
  PATH="$CQ_ROOT/test/stubs:$PATH"
}

# Creates $BATS_TEST_TMPDIR/repo with the hook and lib/ installed; echoes its path.
make_repo() {
  local repo="$BATS_TEST_TMPDIR/repo"
  git init -q "$repo"
  git -C "$repo" config user.name "Test User"
  git -C "$repo" config user.email "test@example.com"
  cp "$CQ_ROOT/hooks/pre-commit" "$repo/.git/hooks/pre-commit"
  cp -r "$CQ_ROOT/lib" "$repo/.git/hooks/lib"
  cd "$repo" || return 1
  echo "$repo"
}

# cq_sh '<sh code>' [args...]: run code in a fresh sh with common.sh + staged.sh sourced.
# Fresh process so traps/exit in the libs never touch the bats shell.
cq_sh() {
  sh -c '. "$CQ_ROOT/lib/common.sh"; . "$CQ_ROOT/lib/staged.sh"; '"$1" _ "${@:2}"
}

# path_without <tool>: echo a dir of symlinks to every PATH executable except <tool>.
path_without() {
  local dir="$BATS_TEST_TMPDIR/path-without-$1" p f
  mkdir -p "$dir"
  local IFS=:
  for p in $PATH; do
    for f in "$p"/*; do
      [ -x "$f" ] && [ "${f##*/}" != "$1" ] && ln -sf "$f" "$dir/" 2>/dev/null
    done
  done
  echo "$dir"
}
