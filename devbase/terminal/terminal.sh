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
menu_items=(
  "kuchipachi"  "open_menu 'dance' 'bash \$LIB/lib/kuchipachi/dance/dance.sh'"
  #"other"       "bash \$LIB/other/other.sh"
)

open_menu --default "quit" "${menu_items[@]}"