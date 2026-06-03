#!/usr/bin/env bash
# ci-assert.sh — run inside the container after postAttachCommand to verify
# that terminal executed correctly. Exits non-zero on any failure.
set -euo pipefail

PASS=0
FAIL=0

assert() {
  local description="$1"
  local command="$2"
  if eval "$command" &>/dev/null; then
    echo "  PASS  $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $description"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "devcontainer assertions"
echo "-----------------------"

# terminal binary is on PATH
assert "terminal is on PATH" "command -v terminal"

# hooks ran and wrote to the shared log
assert "pre-attach hook ran"  "grep -q 'hello from pre attach script'  /tmp/devbase-ci.log"
assert "post-attach hook ran" "grep -q 'hello from post attach script' /tmp/devbase-ci.log"

# node preset ran — node_modules should exist
assert "node preset ran" "[ -d /workspace/node-example/node_modules ]"

# npm itself is available
assert "npm is on PATH" "command -v npm"

echo "-----------------------"
echo "  ${PASS} passed, ${FAIL} failed"
echo ""

(( FAIL == 0 ))
