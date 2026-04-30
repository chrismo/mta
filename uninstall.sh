#!/usr/bin/env bash
#
# MTA uninstaller - remove MTA's symlinks from PATH and ~/.claude/commands/
#
# Removes only MTA-owned symlinks. Leaves alone:
#   - ~/.claude/contexts/                 (your accumulated context data)
#   - ~/.claude/settings.json             (permissions + hooks unchanged)
#   - ~/.claude/projects/.../memory/      (auto-memory)
#   - The mta repo itself
#   - claude-slot, claude-tabs, claude-search (now owned by claude-rig)
#
# Run claude-rig's install.sh afterwards to re-point claude-slot/claude-tabs
# at claude-rig (and add the new claude-search command).
#
# Usage: ./uninstall.sh [--dry-run]

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
COMMANDS_DIR="${CLAUDE_COMMANDS_DIR:-$HOME/.claude/commands}"

# Symlinks installed by install.sh
BIN_SYMLINKS=(
  "$LOCAL_BIN/mta"
  "$LOCAL_BIN/mta-engine"
  "$LOCAL_BIN/mta-context.sh"   # legacy shim from earlier installs
  "$LOCAL_BIN/work-context"
)

COMMAND_ENTRIES=(
  "$COMMANDS_DIR/mta"
  "$COMMANDS_DIR/mtm"
  "$COMMANDS_DIR/work-context.md"
)

removed=0
skipped=0

remove_path() {
  local path="$1"
  if [[ ! -L "$path" ]] && [[ ! -e "$path" ]]; then
    skipped=$((skipped + 1))
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "would remove: $path"
  else
    rm -rf "$path"
    echo "removed: $path"
  fi
  removed=$((removed + 1))
}

echo "Uninstalling MTA symlinks..."
echo

echo "From $LOCAL_BIN:"
for path in "${BIN_SYMLINKS[@]}"; do
  remove_path "$path"
done
echo

echo "From $COMMANDS_DIR:"
for path in "${COMMAND_ENTRIES[@]}"; do
  remove_path "$path"
done
echo

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry run: $removed entries would be removed, $skipped already absent."
else
  echo "Done: $removed entries removed, $skipped already absent."
fi

echo
echo "Left untouched (delete manually if you want them gone):"
echo "  ~/.claude/contexts/         (accumulated context data)"
echo "  ~/.claude/settings.json     (Skill/Bash permissions for mta:*, mtm:*, mta-engine, work-context)"
echo "  ~/.claude/projects/-Users-chrismo-dev-mta/memory/"
echo "  $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)  (this repo)"
echo
echo "Next steps:"
echo "  1. cd ~/dev/claude-rig && ./install.sh    # re-link claude-slot, claude-tabs, claude-search"
echo "  2. Restart Claude Code sessions to pick up the new symlinks"
