#!/usr/bin/env bats
# tests/terminal/git.bats — unit tests for devbase/terminal/lib/git.sh
#
# Run from the repo root:
#   bats tests/terminal/git.bats

GIT_SH="$BATS_TEST_DIRNAME/../../devbase/terminal/lib/git.sh"
ANSI_SH="$BATS_TEST_DIRNAME/../../devbase/terminal/lib/ansi.sh"
BOX_SH="$BATS_TEST_DIRNAME/../../devbase/terminal/lib/box.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup() {
  TEST_DIR="$(mktemp -d)"

  # Initialise a real git repo so collect_git has something to work with.
  REPO_DIR="$TEST_DIR/repo"
  mkdir -p "$REPO_DIR"
  git -C "$REPO_DIR" init -q
  git -C "$REPO_DIR" config user.email "test@test.com"
  git -C "$REPO_DIR" config user.name  "Test"
  touch "$REPO_DIR/file.txt"
  git -C "$REPO_DIR" add .
  git -C "$REPO_DIR" commit -q -m "initial commit"

  # Stub gum.
  export GUM_LOG_FILE="$TEST_DIR/gum.log"
  gum() {
    if [[ "$1" == "log" ]]; then
      shift
      echo "$*" >> "$GUM_LOG_FILE"
    fi
  }
  export -f gum

  # C_BORDER and C_KEY are required by box.sh / print_rows.
  export C_BORDER=""
  export C_KEY=""
}

teardown() {
  rm -rf "$TEST_DIR"
}

source_git() {
  # shellcheck disable=SC1090
  source "$ANSI_SH"
  source "$BOX_SH"
  source "$GIT_SH"
}

# ---------------------------------------------------------------------------
# collect_git — outside a repo
# ---------------------------------------------------------------------------

@test "collect_git: produces no rows outside a git repo" {
  cd "$TEST_DIR"
  source_git
  collect_git
  [ "${#GIT_ROWS[@]}" -eq 0 ]
}

# ---------------------------------------------------------------------------
# collect_git — inside a repo
# ---------------------------------------------------------------------------

@test "collect_git: populates GIT_ROWS inside a repo" {
  cd "$REPO_DIR"
  source_git
  collect_git
  [ "${#GIT_ROWS[@]}" -gt 0 ]
}

@test "collect_git: Branch row reflects current branch" {
  cd "$REPO_DIR"
  source_git
  collect_git
  local branch_row
  branch_row=$(printf '%s\n' "${GIT_ROWS[@]}" | grep '^Branch|')
  [[ "$branch_row" == *"Branch|"* ]]
  # The default branch name is either 'main' or 'master' depending on git config.
  [[ "$branch_row" == *"main"* || "$branch_row" == *"master"* ]]
}

@test "collect_git: Commit row includes the commit subject" {
  cd "$REPO_DIR"
  source_git
  collect_git
  local commit_row
  commit_row=$(printf '%s\n' "${GIT_ROWS[@]}" | grep '^Commit|')
  [[ "$commit_row" == *"initial commit"* ]]
}

@test "collect_git: Status row shows 'clean' on a clean working tree" {
  cd "$REPO_DIR"
  source_git
  collect_git
  local status_row
  status_row=$(printf '%s\n' "${GIT_ROWS[@]}" | grep '^Status|')
  [[ "$status_row" == *"clean"* ]]
}

@test "collect_git: Status row shows change count when working tree is dirty" {
  cd "$REPO_DIR"
  echo "change" >> "$REPO_DIR/file.txt"
  source_git
  collect_git
  local status_row
  status_row=$(printf '%s\n' "${GIT_ROWS[@]}" | grep '^Status|')
  [[ "$status_row" == *"change(s)"* ]]
}

@test "collect_git: long commit subject is truncated to 60 characters" {
  local long_msg
  long_msg=$(printf '%0.sa' {1..80})  # 80 'a' characters
  git -C "$REPO_DIR" commit -q --allow-empty -m "$long_msg"
  cd "$REPO_DIR"
  source_git
  collect_git
  local commit_row val
  commit_row=$(printf '%s\n' "${GIT_ROWS[@]}" | grep '^Commit|')
  val="${commit_row#Commit|}"
  # Subject portion (after "sha — ") should end in "..."
  [[ "$val" == *"..."* ]]
}

@test "collect_git: detached HEAD shows detached label" {
  local sha
  sha=$(git -C "$REPO_DIR" rev-parse HEAD)
  git -C "$REPO_DIR" checkout -q --detach "$sha"
  cd "$REPO_DIR"
  source_git
  collect_git
  local branch_row
  branch_row=$(printf '%s\n' "${GIT_ROWS[@]}" | grep '^Branch|')
  [[ "$branch_row" == *"detached"* ]]
}

# ---------------------------------------------------------------------------
# collect_git — no upstream
# ---------------------------------------------------------------------------

@test "collect_git: Upstream row shows 'no upstream' when none is set" {
  cd "$REPO_DIR"
  source_git
  collect_git
  local upstream_row
  upstream_row=$(printf '%s\n' "${GIT_ROWS[@]}" | grep '^Upstream|')
  [[ "$upstream_row" == *"no upstream"* ]]
}

# ---------------------------------------------------------------------------
# collect_git — idempotency
# ---------------------------------------------------------------------------

@test "collect_git: can be called twice without duplicating rows" {
  cd "$REPO_DIR"
  source_git
  collect_git
  local count_first="${#GIT_ROWS[@]}"
  GIT_ROWS=()
  collect_git
  local count_second="${#GIT_ROWS[@]}"
  [ "$count_first" -eq "$count_second" ]
}
