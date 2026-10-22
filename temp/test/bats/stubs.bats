load helpers
setup() { common_setup; }

UUID=11111111-2222-4333-8444-555555555555

@test "claude stub emits canned output per mode" {
  for m in pass fail is_error nonsuccess garbage; do
    CLAUDE_STUB_MODE=$m run claude -p x
    assert_success
    case $m in
      garbage) refute_output --partial session_id ;;
      *) assert_output --partial "$UUID" ;;
    esac
  done
  CLAUDE_STUB_MODE=pass run claude
  assert_output --partial '"decision":"pass"'
  CLAUDE_STUB_MODE=fail run claude
  assert_output --partial '"decision":"fail"'
  assert_output --partial '"id":"F1"'
  CLAUDE_STUB_MODE=is_error run claude
  assert_output --partial '"is_error":true'
  CLAUDE_STUB_MODE=nonsuccess run claude
  assert_output --partial error_max_turns
}

@test "claude stub hang mode sleeps (killed by timeout)" {
  CLAUDE_STUB_MODE=hang run timeout 1 claude
  [ "$status" -eq 124 ]
}

@test "claude stub defaults to pass, logs invocation and stdin" {
  run bash -c 'echo hello | claude -p'
  assert_success
  assert_output --partial '"decision":"pass"'
  [ "$(wc -l < "$STUB_LOG_DIR/claude.log")" -eq 1 ]
  [ "$(cat "$STUB_LOG_DIR/claude.stdin")" = hello ]
}

@test "other stubs log cwd/args and honor status" {
  for n in cookstyle chef pwsh wsl.exe; do
    run "$n" a b
    assert_success
    grep -q "cwd=$PWD args=a b" "$STUB_LOG_DIR/$n.log"
  done
  COOKSTYLE_STUB_STATUS=3 run cookstyle
  [ "$status" -eq 3 ]
  WSL_STUB_STATUS=4 run wsl.exe
  [ "$status" -eq 4 ]
}
