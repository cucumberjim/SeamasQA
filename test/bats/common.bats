load helpers
setup() { common_setup; }

@test "skip truthiness: unset, empty and 0 are NOT skip" {
  unset SKIP_JSON
  run cq_sh 'cq_skip_enabled json'
  assert_failure 1
  for v in "" 0; do
    SKIP_JSON="$v" run cq_sh 'cq_skip_enabled json'
    assert_failure 1
  done
  SKIP_JSON=1 run cq_sh 'cq_skip_enabled json'   # positive control
  assert_success
}

@test "skip truthiness: 1, yes, true ARE skip" {
  for v in 1 yes true; do
    SKIP_JSON="$v" run cq_sh 'cq_skip_enabled json'
    assert_success
  done
}

@test "skip name maps to SKIP_<UPPERCASE>" {
  for n in chef json yaml ps1 sh py; do
    export "SKIP_$(echo "$n" | tr a-z A-Z)=1"
    run cq_sh "cq_skip_enabled $n"
    assert_success
    unset "SKIP_$(echo "$n" | tr a-z A-Z)"
  done
}

@test "skip name is validated before interpolation" {
  SKIP_JSON=1 run cq_sh 'cq_skip_enabled json'   # positive control
  assert_success
  run cq_sh 'cq_skip_enabled "$1"' "json;touch $BATS_TEST_TMPDIR/pwned"
  assert_failure
  [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
}

@test "cq_run_check: failing check without skip returns the check's status" {
  unset SKIP_DEMO
  run cq_sh 'check_demo() { return 3; }; cq_run_check demo'
  assert_failure 3
}

@test "cq_run_check: failing check with SKIP_DEMO=1 warns on stderr and returns 0" {
  SKIP_DEMO=1 run --separate-stderr cq_sh 'check_demo() { return 3; }; cq_run_check demo'
  assert_success
  [[ "$stderr" == *WARNING* ]]
}

@test "cq_run_check: passing check returns 0 with no WARNING" {
  unset SKIP_DEMO
  run --separate-stderr cq_sh 'check_demo() { return 0; }; cq_run_check demo'
  assert_success
  [[ "$stderr" != *WARNING* ]]
}

@test "cq_run_check: SKIP_DEMO=0 does not skip a failing check" {
  SKIP_DEMO=0 run cq_sh 'check_demo() { return 3; }; cq_run_check demo'
  assert_failure 3
}

@test "cq_run_check: undefined check is a pass" {
  run cq_sh 'cq_run_check nosuchcheck'
  assert_success
}

@test "cq_platform: windows for MINGW/MSYS/CYGWIN, linux otherwise" {
  mkdir "$BATS_TEST_TMPDIR/fakebin"
  for u in MINGW64_NT-10.0 MSYS_NT-10.0 CYGWIN_NT-10.0; do
    printf '#!/bin/sh\necho %s\n' "$u" > "$BATS_TEST_TMPDIR/fakebin/uname"
    chmod +x "$BATS_TEST_TMPDIR/fakebin/uname"
    PATH="$BATS_TEST_TMPDIR/fakebin:$PATH" run cq_sh 'cq_platform'
    assert_output windows
  done
  printf '#!/bin/sh\necho Linux\n' > "$BATS_TEST_TMPDIR/fakebin/uname"
  PATH="$BATS_TEST_TMPDIR/fakebin:$PATH" run cq_sh 'cq_platform'
  assert_output linux
}

@test "cq_require_jq: missing jq -> non-zero with install hint on stderr" {
  PATH="$(path_without jq)" run --separate-stderr cq_sh 'cq_require_jq'
  assert_failure
  [[ "$stderr" == *jq* ]]
  [[ "$stderr" == *install* ]]
}

@test "cq_require_jq: jq present -> 0" {
  mkdir "$BATS_TEST_TMPDIR/fakebin"
  printf '#!/bin/sh\n' > "$BATS_TEST_TMPDIR/fakebin/jq"
  chmod +x "$BATS_TEST_TMPDIR/fakebin/jq"
  PATH="$BATS_TEST_TMPDIR/fakebin:$PATH" run cq_sh 'cq_require_jq'
  assert_success
}
