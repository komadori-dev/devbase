#!/usr/bin/env bats
# tests/terminal/preset.bats — unit tests for devbase/terminal/lib/preset.sh
#
# Run from the repo root:
#   bats tests/terminal/preset.bats

PRESET_SH="$BATS_TEST_DIRNAME/../../devbase/terminal/lib/preset.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup() {
  TEST_DIR="$(mktemp -d)"
  export DEVBASE_PRESETS_DIR="$TEST_DIR"
  unset DEVBASE_PRESETS

  # Stub gum so tests run without the real binary.
  export GUM_LOG_FILE="$TEST_DIR/gum.log"
  gum() {
    if [[ "$1" == "log" ]]; then
      shift
      echo "$*" >> "$GUM_LOG_FILE"
    fi
  }
  export -f gum
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Write a minimal preset script to $TEST_DIR/<name>.sh.
make_preset() {
  local name="$1" body="${2:-}"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$TEST_DIR/$name.sh"
  chmod +x "$TEST_DIR/$name.sh"
}

source_preset() {
  # shellcheck disable=SC1090
  source "$PRESET_SH"
}

# ---------------------------------------------------------------------------
# load_presets — no presets set
# ---------------------------------------------------------------------------

@test "load_presets: does nothing when DEVBASE_PRESETS is unset" {
  source_preset
  run load_presets
  [ "$status" -eq 0 ]
  grep -q "no presets set" "$GUM_LOG_FILE"
}

@test "load_presets: does nothing when DEVBASE_PRESETS is empty string" {
  export DEVBASE_PRESETS=""
  source_preset
  run load_presets
  [ "$status" -eq 0 ]
  grep -q "no presets set" "$GUM_LOG_FILE"
}

@test "load_presets: does nothing when DEVBASE_PRESETS is only whitespace/commas" {
  export DEVBASE_PRESETS=" , , "
  source_preset
  run load_presets
  [ "$status" -eq 0 ]
  grep -q "no presets set" "$GUM_LOG_FILE"
}

# ---------------------------------------------------------------------------
# load_presets — single preset
# ---------------------------------------------------------------------------

@test "load_presets: runs a single preset script" {
  make_preset "node" 'echo "node preset ran"'
  export DEVBASE_PRESETS="node"
  source_preset
  run load_presets
  [ "$status" -eq 0 ]
  [[ "$output" == *"node preset ran"* ]]
}

@test "load_presets: logs a warning for an unknown preset and continues" {
  make_preset "python" 'echo "python preset ran"'
  export DEVBASE_PRESETS="missing,python"
  source_preset
  run load_presets
  [ "$status" -eq 0 ]
  grep -q "missing" "$GUM_LOG_FILE"
  [[ "$output" == *"python preset ran"* ]]
}

@test "load_presets: does not abort when one preset script fails" {
  make_preset "bad"  'exit 1'
  make_preset "good" 'echo "good ran"'
  export DEVBASE_PRESETS="bad,good"
  source_preset
  run load_presets
  [ "$status" -eq 0 ]
  [[ "$output" == *"good ran"* ]]
}

# ---------------------------------------------------------------------------
# load_presets — multiple presets
# ---------------------------------------------------------------------------

@test "load_presets: runs multiple presets in order" {
  make_preset "first"  'echo "first"'
  make_preset "second" 'echo "second"'
  export DEVBASE_PRESETS="first,second"
  source_preset
  run load_presets
  [ "$status" -eq 0 ]
  first_pos=$(echo "$output" | grep -n "^first$"  | cut -d: -f1)
  second_pos=$(echo "$output" | grep -n "^second$" | cut -d: -f1)
  (( first_pos < second_pos ))
}

@test "load_presets: trims spaces around preset names" {
  make_preset "node" 'echo "node ran"'
  export DEVBASE_PRESETS=" node "
  source_preset
  run load_presets
  [ "$status" -eq 0 ]
  [[ "$output" == *"node ran"* ]]
}

# ---------------------------------------------------------------------------
# DEVBASE_PRESETS_DIR override
# ---------------------------------------------------------------------------

@test "DEVBASE_PRESETS_DIR: loads preset from the overridden directory" {
  local alt_dir
  alt_dir="$(mktemp -d)"
  printf '#!/usr/bin/env bash\necho "alt preset"\n' > "$alt_dir/custom.sh"
  chmod +x "$alt_dir/custom.sh"

  DEVBASE_PRESETS_DIR="$alt_dir" source_preset
  export DEVBASE_PRESETS="custom"
  run load_presets
  rm -rf "$alt_dir"

  [ "$status" -eq 0 ]
  [[ "$output" == *"alt preset"* ]]
}
