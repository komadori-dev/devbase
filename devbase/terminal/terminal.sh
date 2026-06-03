#!/usr/bin/env bash
# terminal — print kuchipachi + system info + daily tip + (optional) git info.
set -uo pipefail

DEVBASE=/usr/local/share/devbase
LIB=$DEVBASE/terminal
PRESETS=$DEVBASE/presets

COLOR_KUCHIPACHI="${DEVBASE_BANNER_COLOR:-157}"
COLOR_KEY=157
COLOR_DIM=245

export TERM=xterm-256color

# ---- load modules --------------------------------------------------------
# Order matters: ansi → box → feature modules. sysinfo.sh populates the vars
# the banner module reads.
source "$LIB/lib/ansi.sh"
source "$LIB/lib/box.sh"
source "$LIB/lib/sysinfo.sh"
source "$LIB/lib/kuchipachi/greet.sh"
source "$LIB/lib/git.sh"
source "$LIB/lib/preset.sh"
source "$LIB/lib/hooks.sh"
source "$LIB/lib/menu.sh"


# ---- shared color vars (used by box.sh and greet.sh) --------------------
C_BORDER=$(fg "$COLOR_KUCHIPACHI")
C_KEY=$(fg "$COLOR_KEY")

# ---- layout --------------------------------------------------------------
term_cols=$(tput cols 2>/dev/null || echo 80)
gum log --time rfc822 --level info "dev container initialized, preparing post attach commands..."
gum log --time rfc822 --level debug "workdir: $PWD"

# ---- hooks + presets -----------------------------------------------------
run_pre_attach_hooks
print_presets_info
run_post_attach_hooks

# ---- git info ------------------------------------------------------------
print_git_info

# ---- kuchipachi + system info + motd -------------------------------------
echo
print_copyright
echo
print_greet
echo
print_motd
echo

# ---- menu ----------------------------------------------------------------
# Skip in non-interactive environments (e.g. CI). Set DEVBASE_NO_MENU=1 to
# run terminal headlessly — all hooks, presets, and banner still execute.
[[ "${DEVBASE_NO_MENU:-0}" == "1" ]] && exit 0
menu_items=()

# Add a top-level hooks sub-menu for a phase, but only when scripts exist.
# The sub-menu lists each script individually. Both paths call the same
# underlying _run_hooks, so execution order always matches the initial attach run.
_add_hook_menu() {
  local phase="$1"
  local -a scripts=()
  mapfile -t scripts < <(list_hooks "$phase")
  (( ${#scripts[@]} == 0 )) && return

  # Build a dedicated sub-menu function scoped to this phase so that the script
  # paths are captured by value and not re-evaluated on each open.
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

_add_hook_menu "pre-attach"
_add_hook_menu "post-attach"

# hooks sub-menus first (already in menu_items), then kuchipachi.
menu_items+=(
  "kuchipachi"  "open_menu 'dance' 'bash \$LIB/lib/kuchipachi/dance/dance.sh'"
)

open_menu --default "quit" "${menu_items[@]}"
