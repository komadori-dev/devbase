#!/usr/bin/env bats
# tests/terminal/menu.bats — tests for the top-level and sub-menu item structure
#                             built by _add_hook_menu in terminal.sh.
#
# Run from the repo root:
#   bats tests/terminal/menu.bats

HOOKS_SH="$BATS_TEST_DIRNAME/../../devbase/terminal/lib/hooks.sh"
MENU_SH="$BATS_TEST_DIRNAME/../../devbase/terminal/lib/menu.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup() {
  TEST_DIR="$(mktemp -d)"
  export DEVBASE_HOOKS_DIR="$TEST_DIR"

  export GUM_LOG_FILE="$TEST_DIR/gum.log"
  gum() {
    if [[ "$1" == "log" ]]; then shift; echo "$*" >> "$GUM_LOG_FILE"; fi
  }
  export -f gum

  # shellcheck disable=SC1090
  source "$HOOKS_SH"
  source "$MENU_SH"

  # Mirror of _add_hook_menu from terminal.sh, callable in test scope.
  _add_hook_menu() {
    local phase="$1"
    local -a scripts=()
    mapfile -t scripts < <(list_hooks "$phase")
    (( ${#scripts[@]} == 0 )) && return

    local fn_name="_menu_${phase//-/_}"
    local fn_body
    fn_body=$(
      printf '%s() {\n' "$fn_name"
      printf '  open_menu'
      for script in "${scripts[@]}"; do
        local label
        label=$(basename "$script" .sh)
        printf ' %s %s' "$(printf '%q' "$label")" "$(printf '%q' "run_single_hook $phase $script")"
      done
      printf '\n}\n'
    )
    eval "$fn_body"
    menu_items+=("$phase hooks" "$fn_name")
  }
}

teardown() {
  rm -rf "$TEST_DIR"
}

make_script() {
  local phase="$1" name="$2"
  local dir="$TEST_DIR/$phase"
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\necho "%s"\n' "$name" > "$dir/$name"
  chmod +x "$dir/$name"
}

# Override open_menu to print the labels it would pass to gum, then return.
# Used to inspect sub-menu content without needing a TTY.
capture_sub_labels() {
  local sub_fn="$1"
  open_menu() {
    local -a labels=()
    while (( $# >= 2 )); do labels+=("$1"); shift 2; done
    printf '%s\n' "${labels[@]}" "quit"
  }
  "$sub_fn"
}
export -f capture_sub_labels

# ---------------------------------------------------------------------------
# Top-level menu — no hooks present
# ---------------------------------------------------------------------------

@test "top-level menu: no hook phases added when no scripts exist" {
  menu_items=()
  _add_hook_menu "pre-attach"
  _add_hook_menu "post-attach"
  [ "${#menu_items[@]}" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Top-level menu — ordering
# ---------------------------------------------------------------------------

@test "top-level menu: pre-attach hooks entry added before post-attach hooks" {
  make_script "pre-attach"  "01-pre.sh"
  make_script "post-attach" "01-post.sh"
  menu_items=()
  _add_hook_menu "pre-attach"
  _add_hook_menu "post-attach"

  # Labels are at even indices: 0, 2, ...
  [ "${menu_items[0]}" = "pre-attach hooks" ]
  [ "${menu_items[2]}" = "post-attach hooks" ]
}

@test "top-level menu: only present phases appear" {
  make_script "post-attach" "01-post.sh"
  menu_items=()
  _add_hook_menu "pre-attach"
  _add_hook_menu "post-attach"

  [ "${#menu_items[@]}" -eq 2 ]
  [ "${menu_items[0]}" = "post-attach hooks" ]
}

# ---------------------------------------------------------------------------
# Sub-menu — item content
# ---------------------------------------------------------------------------

@test "sub-menu: single script produces exactly that label and quit" {
  make_script "post-attach" "01-setup.sh"
  menu_items=()
  _add_hook_menu "post-attach"

  run capture_sub_labels "${menu_items[1]}"

  [ "$status" -eq 0 ]
  local line_count
  line_count=$(echo "$output" | grep -c .)
  [ "$line_count" -eq 2 ]
  [[ "$output" == *"01-setup"* ]]
  [[ "$output" == *"quit"* ]]
}

@test "sub-menu: multiple scripts all appear as individual entries" {
  make_script "pre-attach" "01-secrets.sh"
  make_script "pre-attach" "02-env.sh"
  menu_items=()
  _add_hook_menu "pre-attach"

  run capture_sub_labels "${menu_items[1]}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"01-secrets"* ]]
  [[ "$output" == *"02-env"* ]]
  [[ "$output" == *"quit"* ]]
}

@test "sub-menu: no 'run all' or internal function names exposed" {
  make_script "post-attach" "01-setup.sh"
  menu_items=()
  _add_hook_menu "post-attach"

  run capture_sub_labels "${menu_items[1]}"

  [ "$status" -eq 0 ]
  [[ "$output" != *"run all"* ]]
  [[ "$output" != *"_run_hooks"* ]]
  [[ "$output" != *"_menu_"* ]]
}
