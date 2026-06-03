#!/usr/bin/env bash
# devbase-init — scaffold a new project with a devbase devcontainer.
set -euo pipefail

REPO="robindeclerck/devbase"
BRANCH="${DEVBASE_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH/templates"

ACCENT=212
DIM=245

# ---- helpers -------------------------------------------------------------
die() { gum style --foreground 203 "✗ $1" >&2; exit 1; }

fetch() {
  local src="$RAW/$1" dst=$2
  mkdir -p "$(dirname "$dst")"
  curl -fsSL "$src" -o "$dst" || die "failed to fetch $src"
}

slugify() {
  printf '%s' "$1" \
    | awk '{print $1}' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

confirm() {
  local prompt=$1 default=${2:-y} ans hint
  if [ "$default" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  read -r -p "» $prompt $hint " ans </dev/tty
  ans=${ans:-$default}
  case "$ans" in [yY]*) return 0 ;; *) return 1 ;; esac
}

# ---- gum bootstrap -------------------------------------------------------
if ! command -v gum >/dev/null 2>&1; then
  echo "gum is required but not installed."
  if confirm "install with homebrew?" y; then
    command -v brew >/dev/null 2>&1 \
      || die "homebrew not found — install gum manually: https://github.com/charmbracelet/gum"
    brew install gum
  else
    die "gum required. install: https://github.com/charmbracelet/gum"
  fi
fi

# ---- header --------------------------------------------------------------
clear
gum style \
  --border double --border-foreground "$ACCENT" \
  --padding "1 4" --margin "1 0" --align center \
  --bold --foreground "$ACCENT" \
  "devbase init" \
  "" \
  "$(gum style --foreground "$DIM" 'scaffold a new devcontainer project')"

# ---- prompts -------------------------------------------------------------
NAME=$(gum input \
  --header "» project name" \
  --placeholder "Pipeline Dev Container" \
  --width 60 </dev/tty)
[ -n "$NAME" ] || die "name required"

SLUG_DEFAULT=$(slugify "$NAME")
SLUG=$(gum input \
  --header "» slug" \
  --value "$SLUG_DEFAULT" \
  --width 60 </dev/tty)
[ -n "$SLUG" ] || die "slug required"

PRESET_CHOICE=$(gum choose --header "» preset" "python" "node" "none" </dev/tty)
PRESETS=""
[ "$PRESET_CHOICE" != "none" ] && [ -n "$PRESET_CHOICE" ] && PRESETS="$PRESET_CHOICE"

# ---- summary + confirm ---------------------------------------------------
echo
gum style --foreground "$DIM" --margin "0 2" \
  "name     $NAME" \
  "slug     $SLUG" \
  "preset   ${PRESETS:-<none>}" \
  "target   $(pwd)"
echo

confirm "scaffold these files?" y || die "aborted by user"

if [ -e .devcontainer ] || [ -e docker-compose.yml ]; then
  confirm "existing .devcontainer/ or docker-compose.yml found — overwrite?" n \
    || die "aborted by user"
fi

# ---- fetch base templates ------------------------------------------------
gum spin --spinner dot --title "fetching base templates" -- bash -c "
  set -e
  $(declare -f fetch die)
  RAW='$RAW'
  fetch base/.devcontainer/devcontainer.json           .devcontainer/devcontainer.json
  fetch base/.devcontainer/Dockerfile                  .devcontainer/Dockerfile
  fetch base/.devcontainer/docker-compose.override.yml .devcontainer/docker-compose.override.yml
  fetch base/docker-compose.yml                        docker-compose.yml
"

# ---- substitute placeholders --------------------------------------------
gum spin --spinner dot --title "applying placeholders" -- bash -c "
  set -e
  for f in \
    .devcontainer/devcontainer.json \
    .devcontainer/Dockerfile \
    .devcontainer/docker-compose.override.yml \
    docker-compose.yml
  do
    [ -f \"\$f\" ] || continue
    sed -i.bak \
      -e 's|{{NAME}}|$NAME|g' \
      -e 's|{{SLUG}}|$SLUG|g' \
      -e 's|{{PRESETS}}|$PRESETS|g' \
      \"\$f\"
    rm -f \"\$f.bak\"
  done
"

# ---- done ----------------------------------------------------------------
echo
gum style \
  --border rounded --border-foreground "$ACCENT" \
  --padding "1 4" --align center \
  --bold --foreground "$ACCENT" \
  "✓ $NAME scaffolded"
echo

if command -v code >/dev/null 2>&1; then
  if confirm "open in VS Code?" y; then
    code .
  fi
else
  gum style --foreground "$DIM" \
    "next: open in VS Code → Reopen in Container"
fi

echo