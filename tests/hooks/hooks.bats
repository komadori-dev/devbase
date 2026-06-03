#!/usr/bin/env bats
# tests/hooks/hooks.bats — unit tests for devbase/terminal/lib/hooks.sh
#
# Run from the repo root:
#   bats tests/hooks/hooks.bats

HOOKS_SH="$BATS_TEST_DIRNAME/../../devbase/terminal/lib/hooks.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Create a fresh temp dir for each test and point DEVBASE_HOOKS_DIR at it.
setup() {
  TEST_DIR="$(mktemp -d)"
  export DEVBASE_HOOKS_DIR="$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Make a script at $TEST_DIR/<phase>/<name>.sh with given content.
# Marks it executable by default; pass --no-exec to skip chmod.
make_script() {
  local phase="$1" name="$2" body="$3" exec="${4:---exec}"
  local dir="$TEST_DIR/$phase"
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$dir/$name"
  [[ "$exec" == "--no-exec" ]] || chmod +x "$dir/$name"
}

# Stub gum so tests run without the real binary.
# Captures: gum log calls write to $GUM_LOG_FILE; gum choose is unused here.
gum_stub() {
  export GUM_LOG_FILE="$TEST_DIR/gum.log"
  # Shadow gum with a function inside the sourced environment.
  # bats runs each @test in a subshell so this is safe.
  gum() {
    if [[ "$1" == "log" ]]; then
      shift
      echo "$*" >> "$GUM_LOG_FILE"
    fi
  }
  export -f gum
}

# Source hooks.sh with gum stubbed, inside a subshell captured to output.
source_hooks() {
  gum_stub
  # shellcheck disable=SC1090
  source "$HOOKS_SH"
}

# ---------------------------------------------------------------------------
# list_hooks
# ---------------------------------------------------------------------------

@test "list_hooks: returns nothing when phase dir is absent" {
  source_hooks
  run list_hooks "pre-attach"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "list_hooks: returns nothing when phase dir is empty" {
  mkdir -p "$TEST_DIR/pre-attach"
  source_hooks
  run list_hooks "pre-attach"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "list_hooks: lists one executable script" {
  make_script "pre-attach" "01-hello.sh" 'echo hello'
  source_hooks
  run list_hooks "pre-attach"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == *"01-hello.sh" ]]
}

@test "list_hooks: lists multiple scripts in lexicographic order" {
  make_script "post-attach" "02-second.sh" 'echo second'
  make_script "post-attach" "01-first.sh"  'echo first'
  make_script "post-attach" "03-third.sh"  'echo third'
  source_hooks
  run list_hooks "post-attach"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [[ "${lines[0]}" == *"01-first.sh"  ]]
  [[ "${lines[1]}" == *"02-second.sh" ]]
  [[ "${lines[2]}" == *"03-third.sh"  ]]
}

@test "list_hooks: skips non-executable scripts" {
  make_script "pre-attach" "01-exec.sh"    'echo exec'
  make_script "pre-attach" "02-noexec.sh"  'echo noexec' --no-exec
  source_hooks
  run list_hooks "pre-attach"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == *"01-exec.sh" ]]
}

@test "list_hooks: scopes to the requested phase" {
  make_script "pre-attach"  "01-pre.sh"  'echo pre'
  make_script "post-attach" "01-post.sh" 'echo post'
  source_hooks
  run list_hooks "pre-attach"
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == *"pre.sh" ]]
}

# ---------------------------------------------------------------------------
# run_pre_attach_hooks / run_post_attach_hooks
# ---------------------------------------------------------------------------

@test "run_pre_attach_hooks: succeeds silently when dir is absent" {
  source_hooks
  run run_pre_attach_hooks
  [ "$status" -eq 0 ]
}

@test "run_post_attach_hooks: succeeds silently when dir is absent" {
  source_hooks
  run run_post_attach_hooks
  [ "$status" -eq 0 ]
}

@test "run_pre_attach_hooks: runs scripts and captures output" {
  make_script "pre-attach" "01-hello.sh" 'echo "ran pre"'
  source_hooks
  run run_pre_attach_hooks
  [ "$status" -eq 0 ]
  [[ "$output" == *"ran pre"* ]]
}

@test "run_post_attach_hooks: runs scripts and captures output" {
  make_script "post-attach" "01-hello.sh" 'echo "ran post"'
  source_hooks
  run run_post_attach_hooks
  [ "$status" -eq 0 ]
  [[ "$output" == *"ran post"* ]]
}

@test "run_pre_attach_hooks: runs multiple scripts in lexicographic order" {
  make_script "pre-attach" "02-b.sh" 'echo "b"'
  make_script "pre-attach" "01-a.sh" 'echo "a"'
  source_hooks
  run run_pre_attach_hooks
  [ "$status" -eq 0 ]
  # "a" must appear before "b" in the combined output
  a_pos=$(echo "$output" | grep -n "^a$" | cut -d: -f1)
  b_pos=$(echo "$output" | grep -n "^b$" | cut -d: -f1)
  (( a_pos < b_pos ))
}

@test "run_pre_attach_hooks: aborts on first failing script" {
  make_script "pre-attach" "01-fail.sh" 'exit 1'
  make_script "pre-attach" "02-after.sh" 'echo "should not run"'
  source_hooks
  run run_pre_attach_hooks
  [ "$status" -ne 0 ]
  [[ "$output" != *"should not run"* ]]
}

# ---------------------------------------------------------------------------
# run_single_hook
# ---------------------------------------------------------------------------

@test "run_single_hook: runs the given script" {
  make_script "post-attach" "01-hello.sh" 'echo "single run"'
  local script="$TEST_DIR/post-attach/01-hello.sh"
  source_hooks
  run run_single_hook "post-attach" "$script"
  [ "$status" -eq 0 ]
  [[ "$output" == *"single run"* ]]
}

@test "run_single_hook: returns non-zero on failure but does not abort" {
  make_script "post-attach" "01-bad.sh" 'exit 42'
  local script="$TEST_DIR/post-attach/01-bad.sh"
  source_hooks
  run run_single_hook "post-attach" "$script"
  # run_single_hook logs the error but does not propagate the exit code
  # (unlike _run_hooks which aborts the chain — single reruns are best-effort).
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# DEVBASE_HOOKS_DIR override
# ---------------------------------------------------------------------------

@test "DEVBASE_HOOKS_DIR: overrides the default hooks base directory" {
  local alt_dir
  alt_dir="$(mktemp -d)"
  make_script "pre-attach" "01-hello.sh" 'echo "from alt dir"'
  # Move the script into the alt dir instead
  mkdir -p "$alt_dir/pre-attach"
  mv "$TEST_DIR/pre-attach/01-hello.sh" "$alt_dir/pre-attach/01-hello.sh"

  DEVBASE_HOOKS_DIR="$alt_dir" source_hooks
  run run_pre_attach_hooks
  rm -rf "$alt_dir"

  [ "$status" -eq 0 ]
  [[ "$output" == *"from alt dir"* ]]
}

@test "DEVBASE_HOOKS_DIR: list_hooks respects the override" {
  local alt_dir
  alt_dir="$(mktemp -d)"
  mkdir -p "$alt_dir/pre-attach"
  printf '#!/usr/bin/env bash\necho alt\n' > "$alt_dir/pre-attach/01-alt.sh"
  chmod +x "$alt_dir/pre-attach/01-alt.sh"

  DEVBASE_HOOKS_DIR="$alt_dir" source_hooks
  run list_hooks "pre-attach"
  rm -rf "$alt_dir"

  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == *"01-alt.sh" ]]
}

# ---------------------------------------------------------------------------
# run_single_hook logging
# ---------------------------------------------------------------------------

@test "run_single_hook: logs re-running info on success" {
  make_script "post-attach" "01-hello.sh" 'echo "ok"'
  local script="$TEST_DIR/post-attach/01-hello.sh"
  source_hooks
  run_single_hook "post-attach" "$script"
  grep -q "re-running post-attach hook: 01-hello.sh" "$GUM_LOG_FILE"
}

@test "run_single_hook: logs error on failure" {
  make_script "post-attach" "01-bad.sh" 'exit 1'
  local script="$TEST_DIR/post-attach/01-bad.sh"
  source_hooks
  run_single_hook "post-attach" "$script"
  grep -q "01-bad.sh" "$GUM_LOG_FILE"
  grep -q "error" "$GUM_LOG_FILE"
}

# ---------------------------------------------------------------------------
# _run_hooks with non-executable-only dir
# ---------------------------------------------------------------------------

@test "_run_hooks: succeeds when dir exists but contains only non-executable scripts" {
  mkdir -p "$TEST_DIR/pre-attach"
  make_script "pre-attach" "01-noexec.sh" 'echo "should not run"' --no-exec
  source_hooks
  run run_pre_attach_hooks
  [ "$status" -eq 0 ]
  [[ "$output" != *"should not run"* ]]
}

# ---------------------------------------------------------------------------
# run_post_attach_hooks — order and abort (mirrors pre-attach coverage)
# ---------------------------------------------------------------------------

@test "run_post_attach_hooks: runs multiple scripts in lexicographic order" {
  make_script "post-attach" "02-b.sh" 'echo "b"'
  make_script "post-attach" "01-a.sh" 'echo "a"'
  source_hooks
  run run_post_attach_hooks
  [ "$status" -eq 0 ]
  a_pos=$(echo "$output" | grep -n "^a$" | cut -d: -f1)
  b_pos=$(echo "$output" | grep -n "^b$" | cut -d: -f1)
  (( a_pos < b_pos ))
}

@test "run_post_attach_hooks: aborts on first failing script" {
  make_script "post-attach" "01-fail.sh"  'exit 1'
  make_script "post-attach" "02-after.sh" 'echo "should not run"'
  source_hooks
  run run_post_attach_hooks
  [ "$status" -ne 0 ]
  [[ "$output" != *"should not run"* ]]
}

# ---------------------------------------------------------------------------
# run all (menu) === _run_hooks order consistency
# ---------------------------------------------------------------------------

@test "_run_hooks order matches list_hooks order" {
  make_script "pre-attach" "03-c.sh" 'echo "c"'
  make_script "pre-attach" "01-a.sh" 'echo "a"'
  make_script "pre-attach" "02-b.sh" 'echo "b"'

  source_hooks

  # Capture the order list_hooks would show in the menu
  mapfile -t listed < <(list_hooks "pre-attach")
  listed_names=("${listed[@]##*/}")  # basenames only

  # Capture the order _run_hooks actually runs them
  run run_pre_attach_hooks
  run_order=()
  while IFS= read -r line; do
    [[ "$line" =~ ^[abc]$ ]] && run_order+=("$line")
  done <<< "$output"

  # Both should be a, b, c
  [ "${listed_names[0]}" = "01-a.sh" ]
  [ "${listed_names[1]}" = "02-b.sh" ]
  [ "${listed_names[2]}" = "03-c.sh" ]
  [ "${run_order[0]}" = "a" ]
  [ "${run_order[1]}" = "b" ]
  [ "${run_order[2]}" = "c" ]
}
