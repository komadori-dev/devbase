#!/usr/bin/env bash
# lib/menu.sh — reusable gum menu
#
# Usage: open_menu [--default <label>] label1 cmd1 label2 cmd2 ...
#
# Items are displayed in the order they are passed. Each label/cmd pair is
# two consecutive arguments. A "quit" option is always appended automatically.

open_menu() {
  local default=""
  if [[ $1 == --default ]]; then
    default=$2; shift 2
  fi

  # Collect labels and commands in order, using parallel indexed arrays.
  local -a labels=()
  local -a commands=()
  while (( $# >= 2 )); do
    labels+=("$1")
    commands+=("$2")
    shift 2
  done

  local choice
  while true; do
    choice=$(printf '%s\n' "${labels[@]}" "quit" | gum choose \
      --cursor.foreground 157 \
      --selected.foreground 157 \
      --header "" \
      ${default:+--selected "$default"}) || return 0

    [[ "$choice" == "quit" || -z "$choice" ]] && return 0

    local i
    for (( i = 0; i < ${#labels[@]}; i++ )); do
      if [[ "${labels[$i]}" == "$choice" ]]; then
        eval "${commands[$i]}"
        break
      fi
    done
  done
}
