#!/usr/bin/env bash
#
# MTA installer - set up CLI tools and Claude Code skills
#
# What this does:
#   1. Checks dependencies (super CLI)
#   2. Symlinks bin/* -> ~/.local/bin/
#   3. Symlinks skills/*.sh -> ~/.local/bin/ (skill-bundled scripts)
#   4. Symlinks skills/mta/ and skills/mtm/ -> ~/.claude/commands/
#   5. Symlinks skills/*.md -> ~/.claude/commands/
#
# Usage: ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"
COMMANDS_DEST="$HOME/.claude/commands"

# ─────────────────────────────────────────────────────────────────────────────
# Dependency checks
# ─────────────────────────────────────────────────────────────────────────────

if ! command -v super &>/dev/null; then
  echo "Error: 'super' CLI not found. Install SuperDB first:"
  echo "  brew install superdb"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Install CLI
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$LOCAL_BIN"

for bin_file in mta mta-engine claude-slot; do
  dest="$LOCAL_BIN/$bin_file"
  if [[ -L "$dest" ]] || [[ -f "$dest" ]]; then
    rm "$dest"
  fi
  ln -s "$SCRIPT_DIR/bin/$bin_file" "$dest"
  echo "Linked $bin_file -> $LOCAL_BIN/"
done

# ─────────────────────────────────────────────────────────────────────────────
# Install skills (mta/ and mtm/ -> ~/.claude/commands/)
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$COMMANDS_DEST"

for namespace in mta mtm; do
  src="$SCRIPT_DIR/skills/$namespace"
  dest="$COMMANDS_DEST/$namespace"

  if [[ ! -d "$src" ]]; then
    echo "Warning: $src not found, skipping"
    continue
  fi

  # Show what we're replacing
  if [[ -L "$dest" ]]; then
    old_target=$(readlink "$dest")
    echo "Replacing $namespace symlink:"
    echo "  was:  $old_target"
    echo "  now:  $src/"
    rm "$dest"
  elif [[ -d "$dest" ]]; then
    echo "Replacing $namespace directory with symlink -> $src/"
    rm -rf "$dest"
  fi

  ln -s "$src/" "$dest"

  skill_count=$(find "$src" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
  echo "Installed $namespace/ ($skill_count skills)"
done

# ─────────────────────────────────────────────────────────────────────────────
# Install standalone skill files (*.md -> commands/, *.sh -> bin/)
# ─────────────────────────────────────────────────────────────────────────────

for skill_file in "$SCRIPT_DIR/skills"/*.md; do
  if [[ -f "$skill_file" ]]; then
    filename=$(basename "$skill_file")
    dest="$COMMANDS_DEST/$filename"

    if [[ -L "$dest" ]] || [[ -f "$dest" ]]; then
      rm "$dest"
    fi

    ln -s "$skill_file" "$dest"
    echo "Linked $filename -> commands/"
  fi
done

# Skill-bundled scripts (e.g. work-context.sh) -> ~/.local/bin/ (without .sh)
for script_file in "$SCRIPT_DIR/skills"/*.sh; do
  if [[ -f "$script_file" ]]; then
    # Install as command name without .sh extension
    cmd_name=$(basename "$script_file" .sh)
    dest="$LOCAL_BIN/$cmd_name"

    if [[ -L "$dest" ]] || [[ -f "$dest" ]]; then
      rm "$dest"
    fi

    ln -s "$script_file" "$dest"
    echo "Linked $cmd_name -> $LOCAL_BIN/ (from skills/)"
  fi
done

echo ""
echo "Done. Verify with:"
echo "  which mta-engine"
echo "  ls -la ~/.claude/commands/mta"
echo "  ls -la ~/.claude/commands/mtm"
