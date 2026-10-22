load helpers

setup() {
  common_setup
  repo="$(make_repo)"
  cd "$repo"
  rm -f .git/hooks/pre-commit   # unit tests: commits here must not run the hook
}

# Run cq_staged_files with NULs shown as '@' so `run` can compare exactly.
nul_at() { cq_sh 'cq_staged_files | tr "\0" "@"'; }

@test "cq_staged_files emits NUL-separated paths" {
  echo a > a.txt; echo b > b.json; git add .
  run nul_at
  assert_output 'a.txt@b.json@'
}

@test "cq_staged_files keeps spaces and an embedded newline intact" {
  echo a > "a b.txt"; echo b > $'nl\nname.txt'; git add .
  run nul_at
  assert_output $'a b.txt@nl\nname.txt@'
}

@test "cq_staged_files uses ACMR: added/modified/renamed listed, deleted not" {
  echo 1 > mod.txt; echo 1 > del.txt; echo 1 > ren.txt
  git add .; git commit -q -m base
  echo 2 > mod.txt; git rm -q del.txt; git mv ren.txt new.txt; echo 1 > added.txt
  git add .
  run nul_at
  assert_output 'added.txt@mod.txt@new.txt@'
}

@test "cq_staged_files lists a renamed file under its NEW name only" {
  echo content > old.txt; git add .; git commit -q -m base
  git mv old.txt new.txt
  run nul_at
  assert_output 'new.txt@'
}

@test "cq_staged_matches is true only for a matching staged extension" {
  echo a > a.json; echo b > b.txt; git add .
  run cq_sh "cq_staged_matches '*.json'"
  assert_success
  run cq_sh "cq_staged_matches '*.yml'"
  assert_failure
}

@test "cq_staged_matches: .yaml counts when both globs are asked for" {
  echo a > c.yaml; git add .
  run cq_sh "cq_staged_matches '*.yml' '*.yaml'"
  assert_success
  run cq_sh "cq_staged_matches '*.yml'"
  assert_failure
}

@test "cq_staged_matches: embedded newline does not cause a false match" {
  echo a > $'x.json\ny.txt'; git add .
  run cq_sh "cq_staged_matches '*.json'"
  assert_failure
  echo a > z.json; git add z.json   # positive control
  run cq_sh "cq_staged_matches '*.json'"
  assert_success
}

@test "cq_export_index exports STAGED content (good staged, bad unstaged)" {
  echo good > f.json; git add f.json; echo bad > f.json
  run cq_sh 'cq_export_index && cat "$CQ_EXPORT/f.json"'
  assert_output good
}

@test "cq_export_index exports STAGED content (bad staged, good unstaged)" {
  echo bad > f.json; git add f.json; echo good > f.json
  run cq_sh 'cq_export_index && cat "$CQ_EXPORT/f.json"'
  assert_output bad
}

@test "cq_export_index leaves working tree, index and stash untouched" {
  echo staged > f.json; git add f.json; echo unstaged > f.json; echo u > untracked.txt
  before="$(git status --porcelain)"
  run cq_sh 'cq_export_index'
  assert_success
  [ "$(git status --porcelain)" = "$before" ]
  [ "$(cat f.json)" = unstaged ]
  [ -z "$(git stash list)" ]
}

@test "cq_export_index omits untracked files" {
  echo a > a.json; git add a.json
  echo x > Berksfile.lock; mkdir .kitchen; echo x > .kitchen/state.yml
  run cq_sh 'cq_export_index && ls -A "$CQ_EXPORT"'
  assert_output a.json
}

@test "cq_export_index temp dir is removed on normal exit" {
  echo a > a.json; git add a.json
  run cq_sh 'cq_export_index && echo "$CQ_EXPORT"'
  assert_success
  [ -n "$output" ]
  [ ! -d "$output" ]
}

# SIGINT is not tested: background jobs of a non-interactive shell ignore it.
@test "cq_export_index temp dir is removed on TERM and HUP" {
  echo a > a.json; git add a.json
  for sig in TERM HUP; do
    rm -f "$BATS_TEST_TMPDIR/exp"
    sh -c '. "$1/lib/common.sh"; . "$1/lib/staged.sh"; cq_export_index; echo "$CQ_EXPORT" > "$2.tmp"; mv "$2.tmp" "$2"; sleep 5 & wait' \
      _ "$CQ_ROOT" "$BATS_TEST_TMPDIR/exp" >/dev/null 2>&1 3>&- &
    pid=$!
    for _ in $(seq 50); do [ -s "$BATS_TEST_TMPDIR/exp" ] && break; sleep 0.1; done
    exp="$(cat "$BATS_TEST_TMPDIR/exp")"
    [ -d "$exp" ] || { kill "$pid" 2>/dev/null; fail "export dir not created"; }
    kill -"$sig" "$pid"
    wait "$pid" || true
    [ ! -d "$exp" ] || fail "export dir left behind after $sig"
  done
}

@test "export honors GIT_INDEX_FILE as git set it for 'commit -a'" {
  install_probe_hook
  echo v1 > f.json; git add f.json; git commit -q --no-verify -m base
  echo v2 > f.json
  run git commit -a -q -m two
  assert_success
  [ "$(cat "$STUB_LOG_DIR/seen")" = v2 ]
}

@test "export honors GIT_INDEX_FILE as git set it for 'commit <path>'" {
  install_probe_hook
  echo v1 > f.json; echo v1 > g.json; git add .; git commit -q --no-verify -m base
  echo v2 > f.json; echo v2 > g.json
  run git commit -q -m two f.json
  assert_success
  [ "$(cat "$STUB_LOG_DIR/seen")" = $'v2\nv1' ]
}

# Installs the real hook plus a fake check that records the exported f.json and g.json.
install_probe_hook() {
  cp "$CQ_ROOT/hooks/pre-commit" .git/hooks/pre-commit
  cat > .git/hooks/lib/checks.sh <<'PROBE'
check_json() {
  cat "$CQ_EXPORT/f.json" "$CQ_EXPORT/g.json" 2>/dev/null > "$STUB_LOG_DIR/seen"
  return 0
}
PROBE
}

# --- cq_find_chef_root: prints the root relative to the export for easy comparison ---
chef_root() {
  cq_sh 'cq_export_index || exit 1
r=$(cq_find_chef_root "$1") || exit 1
r=${r%/}; e=${CQ_EXPORT%/}
printf "%s" "${r#"$e"}" | sed "s|^/||"' "$1"
}

stage_tree() {
  local f
  for f in "$@"; do mkdir -p "$(dirname "$f")"; echo x > "$f"; done
  git add .
}

@test "cq_find_chef_root returns the nearest ancestor with metadata.rb" {
  stage_tree cook1/metadata.rb cook1/recipes/default.rb
  run chef_root cook1/recipes/default.rb
  assert_output cook1
}

@test "cq_find_chef_root accepts Policyfile.rb" {
  stage_tree pol/Policyfile.rb pol/recipes/r.rb
  run chef_root pol/recipes/r.rb
  assert_output pol
}

@test "cq_find_chef_root fails when no ancestor has a root file" {
  stage_tree loose/x.rb ok/metadata.rb ok/r.rb
  run chef_root ok/r.rb   # positive control
  assert_output ok
  run chef_root loose/x.rb
  assert_failure
}

@test "cq_find_chef_root resolves nested cookbooks independently (monorepo)" {
  stage_tree outer/metadata.rb outer/recipes/r.rb \
    outer/inner/metadata.rb outer/inner/recipes/r.rb
  run chef_root outer/recipes/r.rb
  assert_output outer
  run chef_root outer/inner/recipes/r.rb
  assert_output outer/inner
}

@test "cq_find_chef_root searches the export, not the working tree" {
  stage_tree cook2/recipes/r.rb ok/metadata.rb ok/r.rb
  echo x > cook2/metadata.rb   # present on disk but never staged
  run chef_root ok/r.rb   # positive control
  assert_output ok
  run chef_root cook2/recipes/r.rb
  assert_failure
}
