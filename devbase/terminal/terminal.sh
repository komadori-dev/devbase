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
menu_items=(
  "kuchipachi"  "open_menu 'dance' 'bash \$LIB/lib/kuchipachi/dance/dance.sh'"
  #"other"       "bash \$LIB/other/other.sh"
)

# Add a top-level hooks sub-menu for a phase, but only when scripts exist.
# The sub-menu lists each script individually and provides a "run all" entry.
# Both paths call _run_hooks so execution order is always the same lexicographic
# glob order used during the initial attach run.
_add_hook_menu() {
  local phase="$1"
  local -a scripts=()
  mapfile -t scripts < <(list_hooks "$phase")
  (( ${#scripts[@]} == 0 )) && return

  local -a sub_items=()
  for script in "${scripts[@]}"; do
    local label
    label=$(basename "$script" .sh)
    sub_items+=("$label" "run_single_hook $(printf '%q' "$phase") $(printf '%q' "$script")")
  done

  # "run all" calls _run_hooks with the resolved dir path baked in — same
  # function and same glob order as the initial attach run.
  local dir="$HOOKS_BASE_DIR/$phase"
  sub_items+=("run all" "_run_hooks $(printf '%q' "$phase") $(printf '%q' "$dir")")

  menu_items+=("$phase hooks" "open_menu ${sub_items[*]}")
}

_add_hook_menu "pre-attach"
_add_hook_menu "post-attach"

open_menu --default "quit" "${menu_items[@]}"
