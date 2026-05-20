#!/bin/bash
# Unified dispatcher for project doc hooks.
# Usage: doc.sh <kind> <action> [args]
#        doc.sh search <query>                    (cross-kind search)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="$SCRIPT_DIR/lib/common.sh"
[ -f "$LIB" ] || { echo "Missing $LIB" >&2; exit 1; }
# shellcheck source=/dev/null
source "$LIB"

show_help() {
    cat <<'EOF'
Usage: doc.sh <kind> <action> [args]
       doc.sh search <query>             # search across all kinds
       doc.sh kinds                      # list available kinds
       doc.sh -h | --help

Kinds (per doc-types/<kind>.sh):
  context     change snapshots (docs/context/)
  decision    architectural decision records (docs/decisions/)

Actions:
  new [<slug>]        Create a new doc. Slug derived from git branch if omitted (context only; decision requires slug).
  append <slug>       Append a Follow-up section (context only).
  list [N]            Print INDEX header + up to N rows (default 30).
  rebuild             Re-scan files, rebuild INDEX from frontmatter.
  search <query>      Keyword search within this kind.

Examples:
  ~/.agent-hooks/doc.sh context new
  ~/.agent-hooks/doc.sh context new auth-jwt-migration
  ~/.agent-hooks/doc.sh context append auth-jwt-migration
  ~/.agent-hooks/doc.sh context list 10
  ~/.agent-hooks/doc.sh context rebuild
  ~/.agent-hooks/doc.sh decision new use-postgres
  ~/.agent-hooks/doc.sh decision rebuild
  ~/.agent-hooks/doc.sh search "JWT"
EOF
}

list_kinds() {
    local f
    for f in "$SCRIPT_DIR/doc-types"/*.sh; do
        [ -f "$f" ] || continue
        basename "$f" .sh
    done
}

case "${1:-}" in
    ""|-h|--help) show_help; exit 0 ;;
    kinds) list_kinds; exit 0 ;;
esac

# Cross-kind search: doc.sh search <query>
if [ "$1" = "search" ]; then
    shift
    QUERY="${1:-}"
    [ -n "$QUERY" ] || { echo "Usage: doc.sh search <query>" >&2; exit 2; }
    shift
    rc=0
    for kind in $(list_kinds); do
        type_file="$SCRIPT_DIR/doc-types/$kind.sh"
        (
            # shellcheck source=/dev/null
            source "$type_file"
            printf '\n=== %s ===\n' "$kind"
            doc_search "$QUERY" "$@" || true
        )
    done
    exit "$rc"
fi

KIND="$1"
shift
ACTION="${1:-}"
[ -n "$ACTION" ] || { echo "Missing action. See: doc.sh --help" >&2; exit 2; }
shift

TYPE_FILE="$SCRIPT_DIR/doc-types/$KIND.sh"
if [ ! -f "$TYPE_FILE" ]; then
    echo "Unknown kind: $KIND" >&2
    echo "Available: $(list_kinds | tr '\n' ' ')" >&2
    exit 2
fi
# shellcheck source=/dev/null
source "$TYPE_FILE"

case "$ACTION" in
    new)     doc_new "$@" ;;
    append)  doc_append "$@" ;;
    list)    doc_list "$@" ;;
    rebuild) doc_rebuild "$@" ;;
    search)  doc_search "$@" ;;
    *)
        echo "Unknown action: $ACTION (valid: new, append, list, rebuild, search)" >&2
        exit 2
        ;;
esac
