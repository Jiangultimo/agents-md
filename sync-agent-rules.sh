#!/bin/bash
#
# sync-agent-rules.sh — Symlink README.md (agent rules) to AI coding tool config directories.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/README.md"
HOOKS_SRC="$SCRIPT_DIR/hooks"

# Single source of truth: "name:path" entries (bash 3.2 compatible — no associative arrays).
# To add a new target, append one line here; help text and `all` expansion are derived.
# The "hooks" entry links a DIRECTORY (HOOKS_SRC); all others link the README.md file.
TARGETS=(
    "opencode:$HOME/.config/opencode/AGENTS.md"
    "claude:$HOME/.claude/CLAUDE.md"
    "codex:$HOME/.codex/AGENTS.md"
    "hooks:$HOME/.agent-hooks"
)

resolve_dest() {
    local name="$1" entry
    for entry in "${TARGETS[@]}"; do
        if [ "${entry%%:*}" = "$name" ]; then
            echo "${entry#*:}"
            return 0
        fi
    done
    echo ""
}

all_target_names() {
    local entry
    for entry in "${TARGETS[@]}"; do
        printf '%s ' "${entry%%:*}"
    done
}

show_help() {
    local entry name path
    cat <<EOF
Usage: $(basename "$0") <target...> | all [options]

Symlink agent rules (README.md) to AI coding tool config directories, and
the hooks/ scripts directory to a global, project-agnostic path so that
hooks/* remain callable when rules are loaded from any project's CWD.

Targets:
EOF
    for entry in "${TARGETS[@]}"; do
        name="${entry%%:*}"
        path="${entry#*:}"
        # Render $HOME back to ~ for readability
        printf '  %-10s %s\n' "$name" "${path/#$HOME/\~}"
    done
    cat <<EOF
  all        Link to all targets above

Options:
  --dry-run   Show what would happen without making changes
  --force     Overwrite without prompting (required for non-interactive use)
  -h, --help  Show this help message

Examples:
  $(basename "$0") all              # link rules to every tool + hooks/ globally
  $(basename "$0") claude           # link rules to Claude Code only
  $(basename "$0") hooks            # link hooks/ to ~/.agent-hooks only
  $(basename "$0") opencode codex   # link to specified targets
  $(basename "$0") all --dry-run    # preview only
EOF
}

# Globals controlled by CLI flags
DRY_RUN=0
FORCE=0

# Wrapper for actions that must be skipped in dry-run mode.
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  [dry-run] $*"
    else
        "$@"
    fi
}

# Prompt with a default-No yes/no question. Honors --force and non-interactive stdin.
confirm() {
    local prompt="$1"
    if [ "$FORCE" -eq 1 ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        echo "  Non-interactive shell detected; pass --force to proceed without prompt."
        return 1
    fi
    local answer
    read -rp "$prompt [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Link one target. Returns 0 on success/skip, 1 on error.
link_target() {
    local name="$1"
    local dest
    dest="$(resolve_dest "$name")"

    if [ -z "$dest" ]; then
        echo "[$name] Unknown target (valid: $(all_target_names)all)"
        return 1
    fi

    # The "hooks" target links a directory, not the README file.
    if [ "$name" = "hooks" ]; then
        link_hooks_dir "$name" "$dest"
        return $?
    fi

    local dest_dir
    dest_dir="$(dirname "$dest")"

    if [ ! -d "$dest_dir" ]; then
        echo "[$name] Skipped — directory $dest_dir does not exist (is $name installed?)"
        return 0
    fi

    # Already a symlink pointing to the same source — nothing to do.
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$SRC" ]; then
        echo "[$name] Already linked → $dest"
        return 0
    fi

    # Symlink pointing somewhere else — confirm before replacing.
    if [ -L "$dest" ]; then
        local current
        current="$(readlink "$dest")"
        echo "[$name] Existing symlink points elsewhere: $current"
        if ! confirm "[$name] Replace with link to $SRC?"; then
            echo "[$name] Skipped"
            return 0
        fi
        run rm -f "$dest"
        run ln -s "$SRC" "$dest"
        echo "[$name] Re-linked $dest → $SRC"
        return 0
    fi

    # Existing regular file — back up first, then replace.
    if [ -f "$dest" ]; then
        echo "[$name] File already exists: $dest"
        if ! confirm "[$name] Backup and replace with symlink?"; then
            echo "[$name] Skipped"
            return 0
        fi
        local backup="${dest%.md}.bak.$(date +%Y%m%d%H%M%S).md"
        echo "[$name] Backing up → $backup"
        if ! run cp "$dest" "$backup"; then
            echo "[$name] Backup failed; aborting to avoid data loss"
            return 1
        fi
    fi

    run rm -f "$dest"
    run ln -s "$SRC" "$dest"
    echo "[$name] Linked $dest → $SRC"
}

# Link the hooks/ directory to a global, project-agnostic path so that agents
# reading the synced rules (which live at the global AGENTS.md/CLAUDE.md path)
# can invoke hooks/* scripts regardless of their current project's CWD.
# Returns 0 on success/skip, 1 on error.
link_hooks_dir() {
    local name="$1" dest="$2"

    if [ ! -d "$HOOKS_SRC" ]; then
        echo "[$name] Skipped — source $HOOKS_SRC not found"
        return 0
    fi

    local dest_dir
    dest_dir="$(dirname "$dest")"
    if [ ! -d "$dest_dir" ]; then
        run mkdir -p "$dest_dir"
    fi

    # Already a symlink pointing to the same source — nothing to do.
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$HOOKS_SRC" ]; then
        echo "[$name] Already linked → $dest"
        return 0
    fi

    # Symlink pointing somewhere else — confirm before replacing.
    if [ -L "$dest" ]; then
        local current
        current="$(readlink "$dest")"
        echo "[$name] Existing symlink points elsewhere: $current"
        if ! confirm "[$name] Replace with link to $HOOKS_SRC?"; then
            echo "[$name] Skipped"
            return 0
        fi
        run rm -f "$dest"
        run ln -s "$HOOKS_SRC" "$dest"
        echo "[$name] Re-linked $dest → $HOOKS_SRC"
        return 0
    fi

    # Existing real directory — back up before replacing with symlink.
    if [ -d "$dest" ]; then
        echo "[$name] Directory already exists: $dest"
        if ! confirm "[$name] Back up and replace with symlink?"; then
            echo "[$name] Skipped"
            return 0
        fi
        local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        echo "[$name] Backing up → $backup"
        if ! run mv "$dest" "$backup"; then
            echo "[$name] Backup failed; aborting to avoid data loss"
            return 1
        fi
    fi

    run ln -s "$HOOKS_SRC" "$dest"
    echo "[$name] Linked $dest → $HOOKS_SRC"
}

# ---- argument parsing --------------------------------------------------------
positional=()
for arg in "$@"; do
    case "$arg" in
        -h|--help) show_help; exit 0 ;;
        --dry-run) DRY_RUN=1 ;;
        --force)   FORCE=1 ;;
        --*)       echo "Unknown option: $arg"; show_help; exit 2 ;;
        *)         positional+=("$arg") ;;
    esac
done

if [ "${#positional[@]}" -eq 0 ]; then
    show_help
    exit 0
fi

if [ ! -f "$SRC" ]; then
    echo "Error: Source file $SRC not found"
    exit 1
fi

# Resolve targets. `all` is mutually exclusive with explicit names.
selected=()
for arg in "${positional[@]}"; do
    if [ "$arg" = "all" ]; then
        if [ "${#positional[@]}" -gt 1 ]; then
            echo "Error: 'all' cannot be combined with other targets"
            exit 2
        fi
        # shellcheck disable=SC2207
        selected=($(all_target_names))
    else
        selected+=("$arg")
    fi
done

[ "$DRY_RUN" -eq 1 ] && echo "Dry-run mode: no changes will be made."

exit_code=0
for target in "${selected[@]}"; do
    link_target "$target" || exit_code=1
done

if [ "$exit_code" -eq 0 ]; then
    echo "Done!"
else
    echo "Done with errors."
fi
exit $exit_code
