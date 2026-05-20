#!/bin/bash
# OPTIONAL explicit bootstrap. Normal usage does NOT require this — `doc.sh
# <kind> new` and `rebuild` create docs/context/, docs/decisions/, and their
# INDEX.md files lazily on first call.
#
# Run this when you want to:
# - pre-create the doc dirs + INDEX files so they show up in `git status` /
#   on the file tree before any snapshot exists, OR
# - inject (or refresh) the project-context block in AGENTS.md / CLAUDE.md.
#
# Idempotent: re-running updates the injected block without touching unrelated
# content; existing hooks-authored INDEX files are kept as-is; foreign INDEX
# files are backed up before being replaced.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/common.sh"

TARGET="$(bash "$SCRIPT_DIR/lib/detect-target.sh")"
TARGET_PATH="$PROJECT_ROOT/$TARGET"

# Init one doc kind: create dir if missing; back up foreign INDEX; write fresh INDEX header.
init_kind() {
    local kind="$1"
    local type_file="$SCRIPT_DIR/doc-types/$kind.sh"
    [ -f "$type_file" ] || { echo "Skip: unknown kind $kind"; return 0; }

    # shellcheck source=/dev/null
    source "$type_file"

    mkdir -p "$DOC_DIR"

    if [ ! -f "$DOC_INDEX" ]; then
        doc_index_header > "$DOC_INDEX"
        echo "Created $DOC_INDEX"
        return 0
    fi

    if head -5 "$DOC_INDEX" | grep -qF "$INDEX_MAGIC_MARKER"; then
        echo "Kept    $DOC_INDEX (already hooks-managed)"
        return 0
    fi

    local backup="${DOC_INDEX}.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$DOC_INDEX" "$backup"
    doc_index_header > "$DOC_INDEX"
    echo "Backed up foreign INDEX → $(basename "$backup")"
    echo "Created fresh $DOC_INDEX"
}

init_kind context
init_kind decision

# Inject / refresh the entry-block in AGENTS.md or CLAUDE.md
BLOCK_TMP="$(mktemp)"
trap 'rm -f "$BLOCK_TMP"' EXIT

cat > "$BLOCK_TMP" <<EOF
$MARKER_START
## Hooks-managed Docs

This repo uses globally-installed hooks scripts (at \`~/.agent-hooks/\`) to maintain two doc categories:

- \`docs/context/\` — change snapshots (short-term memory)
- \`docs/decisions/\` — architectural decision records (long-term memory)

At task start: \`~/.agent-hooks/docs-overview.sh\` → \`~/.agent-hooks/doc.sh context list\` → \`~/.agent-hooks/doc.sh decision list\`. Expand individual docs only when topically relevant. Use \`~/.agent-hooks/doc.sh <kind> search <query>\` or \`~/.agent-hooks/doc.sh search <query>\` for keyword lookup.

After completing an independent feature / refactor / investigation (arc end): \`~/.agent-hooks/doc.sh context new\`. After a non-trivial architectural choice: \`~/.agent-hooks/doc.sh decision new <slug>\`. See the project rules for full triggers & timing.
$MARKER_END
EOF

if [ ! -f "$TARGET_PATH" ]; then
    cat "$BLOCK_TMP" > "$TARGET_PATH"
    echo "Created $TARGET_PATH with hooks block"
elif grep -qF "$MARKER_START" "$TARGET_PATH"; then
    replace_or_append_block "$TARGET_PATH" "$MARKER_START" "$MARKER_END" "$BLOCK_TMP"
    echo "Refreshed hooks block in $TARGET_PATH"
else
    replace_or_append_block "$TARGET_PATH" "$MARKER_START" "$MARKER_END" "$BLOCK_TMP"
    echo "Appended hooks block to $TARGET_PATH"
fi

echo "Done. Use: ~/.agent-hooks/doc.sh context new   |   ~/.agent-hooks/doc.sh decision new <slug>"
