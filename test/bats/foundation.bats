load helpers
setup() { common_setup; }

@test "required files exist" {
  for f in hooks/pre-commit lib/common.sh lib/staged.sh lib/checks.sh lib/wsl.sh \
    lib/review.sh docs/WSL2-INSTALL.md LINT-EXCEPTIONS.md .gitattributes \
    scripts/install.sh scripts/install.ps1 scripts/build-skill.sh; do
    [ -f "$CQ_ROOT/$f" ] || fail "missing $f"
  done
}

@test ".gitattributes forces LF for hook and *.sh" {
  run grep -Fx "hooks/pre-commit text eol=lf" "$CQ_ROOT/.gitattributes"
  assert_success
  run grep -Fx "*.sh text eol=lf" "$CQ_ROOT/.gitattributes"
  assert_success
}

@test "hook prints not implemented and fails" {
  run "$CQ_ROOT/hooks/pre-commit"
  assert_failure
  assert_output --partial "not implemented"
}

@test "LINT-EXCEPTIONS.md lists vendor/" {
  run grep -F 'vendor/' "$CQ_ROOT/LINT-EXCEPTIONS.md"
  assert_success
}
