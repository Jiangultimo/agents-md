#!/bin/bash
#
# sync-agent-rules.sh — Symlink README.md (agent rules) to AI coding tool config directories.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/README.md"

# Resolve target name to destination path (bash 3.2 compatible, no associative array)
resolve_dest() {
    case "$1" in
        opencode) echo "$HOME/.config/opencode/AGENTS.md" ;;
        claude)   echo "$HOME/.claude/CLAUDE.md" ;;
        codex)    echo "$HOME/.codex/AGENTS.md" ;;
        *)        echo "" ;;
    esac
}

show_help() {
    cat <<EOF
Usage: $(basename "$0") <target...> | all

Symlink README.md to AI coding tool config directories.

Targets:
  opencode    ~/.config/opencode/AGENTS.md
  claude      ~/.claude/CLAUDE.md
  codex       ~/.codex/AGENTS.md
  all         Link to all targets above

Examples:
  $(basename "$0") all              # link to all targets
  $(basename "$0") claude           # link to Claude Code only
  $(basename "$0") opencode codex   # link to specified targets

Options:
  -h, --help  Show this help message
EOF
}

# Link one target: backup existing regular file, then create symlink
link_target() {
    local name="$1"
    local dest
    dest="$(resolve_dest "$name")"

    if [ -z "$dest" ]; then
        echo "Unknown target: $name (valid: opencode, claude, codex, all)"
        return 1
    fi

    local dest_dir
    dest_dir="$(dirname "$dest")"

    # Check if target directory exists; skip if not
    if [ ! -d "$dest_dir" ]; then
        echo "[$name] Skipped — directory $dest_dir does not exist (is $name installed?)"
        return 0
    fi

    # Already a symlink pointing to the same source — skip
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$SRC" ]; then
        echo "[$name] Already linked → $dest"
        return 0
    fi

    # Existing regular file (not symlink) — confirm before replacing
    if [ -f "$dest" ] && [ ! -L "$dest" ]; then
        echo "[$name] File already exists: $dest"
        read -rp "[$name] Backup and replace with symlink? [y/N] " answer
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            echo "[$name] Skipped"
            return 0
        fi
        local timestamp
        timestamp=$(date +"%Y%m%d%H%M%S")
        local backup="${dest%.md}.bak.${timestamp}.md"
        echo "[$name] Backing up → $backup"
        cp "$dest" "$backup"
    fi

    # Remove existing file/symlink, then create new symlink
    rm -f "$dest"
    ln -s "$SRC" "$dest"
    echo "[$name] Linked $dest → $SRC"
}

# No arguments or help flag → show help
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# Validate source
if [ ! -f "$SRC" ]; then
    echo "Error: Source file $SRC not found"
    exit 1
fi

# Resolve targets
if [ "$1" = "all" ]; then
    selected="opencode claude codex"
else
    selected="$*"
fi

for target in $selected; do
    link_target "$target"
done

echo "Done!"
