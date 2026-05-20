#!/bin/bash
# Doc-type plugin: decision (ADRs).
# Sourced by hooks/doc.sh after lib/common.sh.

DOC_KIND="decision"
DOC_DIR="$PROJECT_ROOT/docs/decisions"
DOC_INDEX="$DOC_DIR/INDEX.md"

doc_index_header() {
    cat <<'EOF'
# Decision Index (ADRs)

> Auto-maintained by `~/.agent-hooks/doc.sh decision`. Newest first.
> Files not matching `NNNN-<slug>.md` are preserved but not indexed.

| ID | Slug | Title | Status | Tags |
|----|------|-------|--------|------|
EOF
}

_decision_template() {
    local id="$1" slug="$2" date="$3"
    cat <<EOF
---
id: $id
slug: $slug
date: $date
title: TODO one-line title
status: Proposed
tags: []
supersedes: []
superseded_by:
---

## Status
Proposed

## Context
TODO — what is the situation that necessitates a decision?

## Decision
TODO — what we decided to do.

## Alternatives considered
TODO — list ≥1 viable alternative + why it was rejected.

## Consequences
TODO — positive, negative, and neutral consequences of this decision.
EOF
}

# Determine next ADR number by scanning existing NNNN-*.md files.
_decision_next_id() {
    local max=0 f n
    shopt -s nullglob
    for f in "$DOC_DIR"/[0-9][0-9][0-9][0-9]-*.md; do
        n="${f##*/}"
        n="${n%%-*}"
        n="$((10#$n))"
        [ "$n" -gt "$max" ] && max="$n"
    done
    shopt -u nullglob
    printf "%04d" $((max + 1))
}

# ----- new -------------------------------------------------------------------

doc_new() {
    [ -d "$DOC_DIR" ] || { echo "Decisions dir missing: $DOC_DIR. Run ~/.agent-hooks/init.sh." >&2; return 1; }
    [ -f "$DOC_INDEX" ] || { echo "INDEX missing: $DOC_INDEX. Run ~/.agent-hooks/init.sh." >&2; return 1; }

    local raw="${1:-}"
    [ -n "$raw" ] || { echo "Usage: doc.sh decision new <slug>" >&2; return 2; }
    local slug; slug="$(slugify "$raw")"
    [ -n "$slug" ] || { echo "Slug empty after normalization (input: '$raw')" >&2; return 2; }

    local id; id="$(_decision_next_id)"
    local date; date="$(today)"
    local file="$DOC_DIR/${id}-${slug}.md"

    if [ -e "$file" ]; then
        echo "Already exists: $file" >&2
        echo "$file"
        return 0
    fi

    _decision_template "$id" "$slug" "$date" > "$file"

    local placeholder="| $id | $slug | (pending — fill frontmatter then rebuild) | Proposed |  |"
    awk -v row="$placeholder" '
        BEGIN { inserted=0 }
        /^\|[[:space:]]*-+/ && !inserted { print; print row; inserted=1; next }
        { print }
        END { if (!inserted) print row }
    ' "$DOC_INDEX" > "$DOC_INDEX.tmp" && mv "$DOC_INDEX.tmp" "$DOC_INDEX"

    echo "Created $file (ADR $id)"
    echo "Next: edit it (title, status, body) then run: ~/.agent-hooks/doc.sh decision rebuild"
    echo "$file"
}

# Decisions are atomic and do not get appended. Use 'supersedes' frontmatter
# in a new ADR to record a replacement.
doc_append() {
    echo "Decisions are atomic and do not support append." >&2
    echo "To revise a decision, create a new ADR with 'supersedes: [<old-slug>]' in its frontmatter." >&2
    return 2
}

# ----- list ------------------------------------------------------------------

doc_list() {
    local limit="${1:-30}"
    if [ ! -f "$DOC_INDEX" ]; then
        echo "No decision index ($DOC_INDEX). Run ~/.agent-hooks/init.sh." >&2
        return 0
    fi
    awk -v limit="$limit" '
        BEGIN { rows=0; in_table=0 }
        !in_table {
            print
            if ($0 ~ /^\|[[:space:]]*-+/) in_table=1
            next
        }
        in_table {
            if ($0 ~ /^\|[[:space:]]*[0-9]{4}/) {
                if (rows < limit) { print; rows++ }
            } else if ($0 ~ /^\|/) {
                if (rows < limit) { print; rows++ }
            } else {
                print
                in_table=0
            }
        }
    ' "$DOC_INDEX"
}

# ----- rebuild ---------------------------------------------------------------

doc_rebuild() {
    [ -d "$DOC_DIR" ] || { echo "No $DOC_DIR. Run ~/.agent-hooks/init.sh." >&2; return 1; }

    local tmp; tmp="$(mktemp)"
    local rowfile; rowfile="$(mktemp)"
    trap 'rm -f "$tmp" "$rowfile"' RETURN

    doc_index_header > "$tmp"

    : > "$rowfile"
    local count=0 f base id slug title status tags
    shopt -s nullglob
    for f in "$DOC_DIR"/*.md; do
        base="$(basename "$f")"
        [ "$base" = "INDEX.md" ] && continue
        case "$base" in INDEX.md.bak.*) continue ;; esac
        [[ "$base" =~ ^[0-9]{4}-.+\.md$ ]] || continue

        id="$(read_frontmatter "$f" id)"
        slug="$(read_frontmatter "$f" slug)"
        title="$(read_frontmatter "$f" title)"
        status="$(read_frontmatter "$f" status)"
        tags="$(read_frontmatter "$f" tags)"

        if [ -z "$id" ] || [ -z "$slug" ]; then
            [[ "$base" =~ ^([0-9]{4})-(.+)\.md$ ]] || continue
            [ -z "$id" ] && id="${BASH_REMATCH[1]}"
            [ -z "$slug" ] && slug="${BASH_REMATCH[2]}"
        fi
        [ -z "$title" ] || [ "$title" = "TODO one-line title" ] && title="(pending — fill frontmatter then rebuild)"
        [ -z "$status" ] && status="Proposed"

        # Sort key: invert id so newest first.
        printf '%s\t| %s | %s | %s | %s | %s |\n' "$id" "$id" "$slug" "$title" "$status" "$tags" >> "$rowfile"
        count=$((count + 1))
    done
    shopt -u nullglob

    if [ "$count" -gt 0 ]; then
        sort -r "$rowfile" | cut -f2- >> "$tmp"
    fi

    mv "$tmp" "$DOC_INDEX"
    echo "Rebuilt $DOC_INDEX ($count entries)"
}

# ----- search ----------------------------------------------------------------

doc_search() {
    local query="${1:-}"
    [ -n "$query" ] || { echo "Usage: doc.sh decision search <query>" >&2; return 2; }
    shift || true

    [ -d "$DOC_DIR" ] || { return 0; }

    if command -v rg >/dev/null 2>&1; then
        rg --color=never --line-number --max-columns=200 --type md "$@" -- "$query" "$DOC_DIR" || {
            local s=$?; [ "$s" -eq 1 ] && return 0 || return "$s"
        }
    else
        grep -RIn --include='*.md' -- "$query" "$DOC_DIR" || {
            local s=$?; [ "$s" -eq 1 ] && return 0 || return "$s"
        }
    fi
}
