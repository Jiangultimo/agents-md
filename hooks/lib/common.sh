#!/bin/bash
# Shared utilities for hooks/* scripts. Source this file, do not execute.

# Project root: prefer git toplevel, else current working directory.
if PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    PROJECT_ROOT="$PWD"
fi

# Marker wrapping the project-context block in root AGENTS.md / CLAUDE.md.
MARKER_START="<!-- context-index:start -->"
MARKER_END="<!-- context-index:end -->"

# Magic substring that identifies INDEX files authored by hooks. Init looks
# for this in the first few lines to decide whether an existing INDEX needs
# to be backed up before being overwritten.
INDEX_MAGIC_MARKER="Auto-maintained by"

today() { date +%Y-%m-%d; }
now()   { date '+%Y-%m-%d %H:%M'; }

# Lowercase + replace non-alphanumeric runs with single dashes; trim outer dashes.
slugify() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -c 'a-z0-9\n' '-' \
        | sed -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}

current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || true
}

# Derive a short slug from current git branch; falls back to a timestamp.
auto_slug() {
    local b
    b="$(current_branch)"
    case "$b" in
        ""|HEAD|main|master|develop)
            echo "snapshot-$(date +%Y%m%d-%H%M%S)"
            ;;
        *)
            slugify "$b"
            ;;
    esac
}

# Extract a YAML frontmatter value. Returns empty if missing.
# Usage: read_frontmatter <file> <key>
read_frontmatter() {
    local file="$1" key="$2"
    awk -v key="$key" '
        BEGIN { in_fm=0 }
        NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
        in_fm && /^---[[:space:]]*$/ { exit }
        in_fm {
            if (match($0, "^" key ":[[:space:]]*")) {
                v = substr($0, RSTART + RLENGTH)
                gsub(/^"|"$|^\[|\]$/, "", v)
                print v
                exit
            }
        }
    ' "$file"
}

# Replace or append a delimited block in a file.
# Usage: replace_or_append_block <file> <start_marker> <end_marker> <block_file>
replace_or_append_block() {
    local file="$1" start="$2" end="$3" block_file="$4"
    if [ -f "$file" ] && grep -qF "$start" "$file"; then
        awk -v start="$start" -v end="$end" -v blockfile="$block_file" '
            BEGIN {
                while ((getline line < blockfile) > 0) {
                    block = (block == "" ? line : block "\n" line)
                }
                close(blockfile)
            }
            $0 == start { print block; in_block=1; next }
            in_block && $0 == end { in_block=0; next }
            !in_block { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        return 0
    fi
    if [ -f "$file" ]; then
        printf '\n' >> "$file"
        cat "$block_file" >> "$file"
    else
        cat "$block_file" > "$file"
    fi
}

# Replace the existing INDEX with backup if it's not authored by hooks.
# Usage: backup_foreign_index <index_file>
# Returns 0 silently if index is missing or already authored by us.
# Prints "backed up to <path>" if a backup was created.
backup_foreign_index() {
    local index="$1"
    [ -f "$index" ] || return 0
    if head -5 "$index" 2>/dev/null | grep -qF "$INDEX_MAGIC_MARKER"; then
        return 0
    fi
    local backup="${index}.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$index" "$backup"
    echo "Backed up foreign INDEX: $backup"
}
