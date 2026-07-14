# greet.sh — kuchipachi art + system info box + daily tip (motd).
# Exposes: print_greet(), print_motd()
# Requires: ansi.sh, box.sh, and sysinfo.sh to have been sourced (provides
#           PROJECT, CWD, USER_NAME, HOST, TIME_UTC, UPTIME_STR, MEMORY, DISK).
# Reads: $LIB, $C_BORDER, $COLOR_DIM, term_cols (set by orchestrator).

# Pick today's tip — stable per day so the same line stays all day.
pick_motd() {
  local file=$LIB/lib/kuchipachi/motd.txt
  [ -r "$file" ] || return 0
  local lines
  mapfile -t lines < <(grep -vE '^\s*(#|$)' "$file")
  (( ${#lines[@]} == 0 )) && return 0
  local idx=$(( 10#$(date +%j) % ${#lines[@]} ))
  printf '%s' "${lines[$idx]}"
}

print_copyright() {
  gum style --bold --foreground "$COLOR_DIM" --align center \
  "© コマドリ.com · robin.de.clerck@gmail.com · github.com/komadori-dev/devbase"
}

# Render kuchipachi + system info side-by-side (or stacked on narrow terms).
print_greet() {
  local kuchipachi_block sys_box

  kuchipachi_block=$(color_lines "$C_BORDER" < "$LIB/lib/kuchipachi/kuchipachi.txt")

  local sys_rows=(
    "Project|$PROJECT"
    "Working directory|$CWD"
    "|"
    "User|$USER_NAME"
    "Host|$HOST"
    "Time (UTC)|$TIME_UTC"
    "Uptime|$UPTIME_STR"
    "|"
    "Memory|$MEMORY"
    "Disk|$DISK"
  )
  sys_box=$(render_box "system info" 18 2 "${sys_rows[@]}")

  if [ "${term_cols:-80}" -ge 70 ]; then
    gum join --horizontal --align center "$kuchipachi_block" "  " "$sys_box"
  else
    printf '%s\n\n%s\n' "$kuchipachi_block" "$sys_box"
  fi
}

# Print today's motd via gum log (no-op if motd.txt is absent or empty).
print_motd() {
  local motd
  motd=$(pick_motd)
  [ -n "$motd" ] && gum log --time rfc822 --level info "$motd"
  return 0
}