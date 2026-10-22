load helpers

# Integration tests: real `git commit` in a temp repo with the real hook. Fake
# checks.sh / review.sh replace the lib copies so these tests don't depend on sections 03/05.
# Everything the fakes do is logged to $STUB_LOG_DIR/order.log.

setup() {
  common_setup
  repo="$(make_repo)"
  cd "$repo"
  LOG="$STUB_LOG_DIR/order.log"
  cat > .git/hooks/lib/checks.sh <<'FAKE'
check_json() {
  echo linter >> "$STUB_LOG_DIR/order.log"
  echo "$CQ_EXPORT" > "$STUB_LOG_DIR/export.path"
  for f in "$CQ_EXPORT"/*.json; do
    [ -e "$f" ] || continue
    grep -q BAD "$f" && return 1
  done
  return 0
}
FAKE
  cat > .git/hooks/lib/review.sh <<'FAKE'
cq_review() {
  echo review >> "$STUB_LOG_DIR/order.log"
  claude -p < /dev/null > /dev/null
}
FAKE
}

stage_json() { printf '%s\n' "$2" > "$1"; git add "$1"; }

make_sink() {
  cat > "$BATS_TEST_TMPDIR/sink.sh" <<'SINK'
#!/bin/sh
echo sink >> "$STUB_LOG_DIR/order.log"
pwd > "$STUB_LOG_DIR/sink.cwd"
cat > "$STUB_LOG_DIR/sink.stdin"
exit "${SINK_STATUS:-0}"
SINK
  chmod +x "$BATS_TEST_TMPDIR/sink.sh"
  export CODE_QUALITY_SINK="$BATS_TEST_TMPDIR/sink.sh"
}

claude_count() { if [ -f "$STUB_LOG_DIR/claude.log" ]; then wc -l < "$STUB_LOG_DIR/claude.log"; else echo 0; fi; }

@test "hook is executable POSIX sh" {
  [ -x "$CQ_ROOT/hooks/pre-commit" ]
  [ "$(head -n1 "$CQ_ROOT/hooks/pre-commit")" = '#!/bin/sh' ]
  run sh -n "$CQ_ROOT/hooks/pre-commit"
  assert_success
}

@test "missing jq: hook fails with an install hint before any check or claude" {
  stage_json a.json ok
  run env PATH="$(path_without jq)" .git/hooks/pre-commit
  assert_failure
  assert_output --partial jq
  [ ! -e "$LOG" ]
  [ "$(claude_count)" -eq 0 ]
}

@test "CODE_QUALITY_LIB selects the lib directory" {
  stage_json a.json ok
  mv .git/hooks/lib "$BATS_TEST_TMPDIR/elsewhere"
  CODE_QUALITY_LIB="$BATS_TEST_TMPDIR/elsewhere" run git commit -q -m x
  assert_success
  [ "$(cat "$LOG")" = $'linter\nreview' ]
}

@test "pre-commit.local runs FIRST and receives the hook's arguments" {
  printf '#!/bin/sh\necho "local $*" >> "$STUB_LOG_DIR/order.log"\n' > .git/hooks/pre-commit.local
  chmod +x .git/hooks/pre-commit.local
  stage_json a.json ok
  run .git/hooks/pre-commit one two
  assert_success
  [ "$(head -n1 "$LOG")" = "local one two" ]
  [ "$(sed -n 2p "$LOG")" = linter ]
}

@test "pre-commit.local non-zero: hook exits with that status, nothing else runs" {
  printf '#!/bin/sh\nexit 7\n' > .git/hooks/pre-commit.local
  chmod +x .git/hooks/pre-commit.local
  stage_json a.json ok
  run .git/hooks/pre-commit
  assert_failure 7
  [ ! -e "$LOG" ]
  [ "$(claude_count)" -eq 0 ]
}

@test "pre-commit.local absent: hook proceeds normally" {
  stage_json a.json ok
  run git commit -q -m x
  assert_success
  [ "$(cat "$LOG")" = $'linter\nreview' ]
}

@test "nothing staged: exit 0 without any check or claude" {
  run .git/hooks/pre-commit
  assert_success
  [ ! -e "$LOG" ]
  [ "$(claude_count)" -eq 0 ]
}

@test "CODE_QUALITY_SINK unset is a no-op" {
  unset CODE_QUALITY_SINK
  stage_json a.json ok
  run git commit -q -m x
  assert_success
  [ "$(cat "$LOG")" = $'linter\nreview' ]
}

@test "sink receives staged files NUL-delimited on stdin, cwd is the export" {
  make_sink
  stage_json "a b.json" ok; stage_json c.json ok
  run git commit -q -m x
  assert_success
  [ "$(tr '\0' '@' < "$STUB_LOG_DIR/sink.stdin")" = 'a b.json@c.json@' ]
  [ "$(cat "$STUB_LOG_DIR/sink.cwd")" = "$(cat "$STUB_LOG_DIR/export.path")" ]
}

@test "sink non-zero fails the commit and claude never runs" {
  make_sink
  stage_json a.json ok
  SINK_STATUS=1 run git commit -q -m x
  assert_failure
  [ "$(cat "$LOG")" = $'linter\nsink' ]
  [ "$(claude_count)" -eq 0 ]
}

@test "CODE_QUALITY_SINK not executable: clear error, commit fails" {
  echo '#!/bin/sh' > "$BATS_TEST_TMPDIR/noexec.sh"
  export CODE_QUALITY_SINK="$BATS_TEST_TMPDIR/noexec.sh"
  stage_json a.json ok
  run git commit -q -m x
  assert_failure
  [[ "${output,,}" == *sink* ]]
  [ "$(claude_count)" -eq 0 ]
}

@test "CODE_QUALITY_SINK nonexistent: clear error, commit fails" {
  export CODE_QUALITY_SINK="$BATS_TEST_TMPDIR/nope.sh"
  stage_json a.json ok
  run git commit -q -m x
  assert_failure
  [[ "${output,,}" == *sink* ]]
  [ "$(claude_count)" -eq 0 ]
}

@test "ordering on success: linters -> sink -> review" {
  make_sink
  stage_json a.json ok
  run git commit -q -m x
  assert_success
  [ "$(cat "$LOG")" = $'linter\nsink\nreview' ]
}

@test "linter failure prevents sink and claude" {
  make_sink
  stage_json a.json BAD
  run git commit -q -m x
  assert_failure
  [ "$(cat "$LOG")" = linter ]
  [ "$(claude_count)" -eq 0 ]
}

@test "SKIP_JSON=1 downgrades a failing linter; sink and review proceed" {
  make_sink
  stage_json a.json BAD
  SKIP_JSON=1 run git commit -q -m x
  assert_success
  assert_output --partial WARNING
  [ "$(cat "$LOG")" = $'linter\nsink\nreview' ]
}

@test "sink is read from the environment only, not from repo files" {
  make_sink
  unset CODE_QUALITY_SINK
  echo "CODE_QUALITY_SINK=$BATS_TEST_TMPDIR/sink.sh" > .env
  echo "CODE_QUALITY_SINK=$BATS_TEST_TMPDIR/sink.sh" > .code-quality
  git add .env .code-quality
  stage_json a.json ok
  run git commit -q -m x
  assert_success
  [ "$(cat "$LOG")" = $'linter\nreview' ]
}

@test "export dir is cleaned up after success and after failure" {
  stage_json a.json ok
  run git commit -q -m x
  assert_success
  [ -n "$(cat "$STUB_LOG_DIR/export.path")" ]
  [ ! -d "$(cat "$STUB_LOG_DIR/export.path")" ]
  stage_json b.json BAD
  run git commit -q -m y
  assert_failure
  [ -n "$(cat "$STUB_LOG_DIR/export.path")" ]
  [ ! -d "$(cat "$STUB_LOG_DIR/export.path")" ]
}
