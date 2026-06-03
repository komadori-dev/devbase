# hooks.sh — run executable scripts from .devcontainer/pre-attach/ and post-attach/.
# Exposes: run_pre_attach_hooks(), run_post_attach_hooks()
# Reads: DEVBASE_HOOKS_DIR (overrides default), falls back to $PWD/.devcontainer

HOOKS_BASE_DIR="${DEVBASE_HOOKS_DIR:-$PWD/.devcontainer}"

# Run all executable *.sh scripts in a hooks directory, in lexicographic order.
# Usage: _run_hooks <phase> <dir>
_run_hooks() {
  local phase="$1"
  local dir="$2"

  if [ ! -d "$dir" ]; then
    gum log --time rfc822 --level debug "no $dir directory found, skipping..."
    return 0
  fi

  # Collect executable *.sh files; lexicographic order via glob expansion.
  local -a scripts=()
  for f in "$dir"/*.sh; do
    [ -f "$f" ] && [ -x "$f" ] && scripts+=("$f")
  done

  local count=${#scripts[@]}
  gum log --time rfc822 --level debug "discovered $count $phase script(s)"

  (( count == 0 )) && return 0

  for script in "${scripts[@]}"; do
    local name
    name=$(basename "$script")
    gum log --time rfc822 --level info "running $phase hook: $name"
    bash "$script" || {
      gum log --time rfc822 --level error "$phase hook '$name' failed (exit $?), aborting"
      return 1
    }
  done
}

run_pre_attach_hooks() {
  _run_hooks "pre-attach" "$HOOKS_BASE_DIR/pre-attach"
}

run_post_attach_hooks() {
  _run_hooks "post-attach" "$HOOKS_BASE_DIR/post-attach"
}

# List executable *.sh scripts for a phase. Prints one path per line.
# Usage: list_hooks <phase>   (phase = "pre-attach" | "post-attach")
list_hooks() {
  local phase="$1"
  local dir="$HOOKS_BASE_DIR/$phase"
  [ -d "$dir" ] || return 0
  for f in "$dir"/*.sh; do
    [ -f "$f" ] && [ -x "$f" ] && echo "$f"
  done
  return 0
}

# Run a single hook script by path, with the same logging as _run_hooks.
# Usage: run_single_hook <phase> <path>
run_single_hook() {
  local phase="$1"
  local script="$2"
  local name
  name=$(basename "$script")
  gum log --time rfc822 --level info "re-running $phase hook: $name"
  bash "$script" || gum log --time rfc822 --level error "$phase hook '$name' failed (exit $?)"
}
