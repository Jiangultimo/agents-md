#!/bin/bash
# Honest, read-only overview of docs/ in the current project.
# Lists what actually exists; expects nothing; warns about nothing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/common.sh"

DOCS_DIR="$PROJECT_ROOT/docs"

echo "docs/  ($PROJECT_ROOT/docs)"

if [ ! -d "$DOCS_DIR" ]; then
    echo "  (empty — no docs/ yet; created lazily on first snapshot/decision)"
    exit 0
fi

# Hooks-managed dirs get a hint command. Mapping is hardcoded to the two kinds
# we ship (folder name → command-line kind name).
hooks_kind_for() {
    case "$1" in
        context)   echo "context" ;;
        decisions) echo "decision" ;;
        *)         echo "" ;;
    esac
}

shopt -s nullglob
for d in "$DOCS_DIR"/*/; do
    name="$(basename "$d")"
    md_count=$(find "$d" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    hint=""
    kind="$(hooks_kind_for "$name")"
    if [ -n "$kind" ]; then
        hint="   [hooks] → ~/.agent-hooks/doc.sh $kind list"
    fi
    printf "  %-15s %3d files%s\n" "$name/" "$md_count" "$hint"
done

# Top-level *.md files at docs/ root
found_root_md=0
for f in "$DOCS_DIR"/*.md; do
    [ -f "$f" ] || continue
    [ "$found_root_md" -eq 0 ] && { echo ""; echo "docs/*.md:"; found_root_md=1; }
    printf "  %s\n" "$(basename "$f")"
done
shopt -u nullglob
