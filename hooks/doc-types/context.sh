#!/bin/bash
# Doc-type plugin: context (change snapshots).
# Sourced by hooks/doc.sh after lib/common.sh.
# Exposes: DOC_KIND, DOC_DIR, DOC_INDEX, doc_index_header, doc_new, doc_append,
# doc_list, doc_rebuild, doc_search.

DOC_KIND="context"
DOC_DIR="$PROJECT_ROOT/docs/context"
DOC_INDEX="$DOC_DIR/INDEX.md"

doc_index_header() {
    cat <<'EOF'
# Context Index

> Auto-maintained by `hooks/doc.sh context`. Newest entries first.
> Files not matching `YYYY-MM-DD-<slug>.md` are preserved but not indexed.

| Date | Slug | Title | Tags |
|------|------|-------|------|
EOF
}

_context_template() {
    local date="$1" slug="$2"
    cat <<EOF
---
date: $date
slug: $slug
title: TODO one-line title
tags: []
related: []
---

## 背景 / 触发动机
TODO

## 关键决策
TODO

## 影响范围
TODO

## 已知遗留 / 后续待办
TODO

## 验证
TODO
EOF
}

# ----- new -------------------------------------------------------------------

doc_new() {
    [ -d "$DOC_DIR" ] || { echo "Context dir missing: $DOC_DIR. Run hooks/init.sh." >&2; return 1; }
    [ -f "$DOC_INDEX" ] || { echo "INDEX missing: $DOC_INDEX. Run hooks/init.sh." >&2; return 1; }

    local raw="${1:-$(auto_slug)}"
    local slug; slug="$(slugify "$raw")"
    [ -n "$slug" ] || { echo "Slug empty after normalization (input: '$raw')" >&2; return 2; }

    local date; date="$(today)"
    local file="$DOC_DIR/${date}-${slug}.md"

    if [ -e "$file" ]; then
        echo "Already exists: $file" >&2
        echo "$file"
        return 0
    fi

    _context_template "$date" "$slug" > "$file"

    local placeholder="| $date | $slug | (pending — fill frontmatter then rebuild) |  |"
    awk -v row="$placeholder" '
        BEGIN { inserted=0 }
        /^\|[[:space:]]*-+/ && !inserted { print; print row; inserted=1; next }
        { print }
        END { if (!inserted) print row }
    ' "$DOC_INDEX" > "$DOC_INDEX.tmp" && mv "$DOC_INDEX.tmp" "$DOC_INDEX"

    echo "Created $file"
    echo "Next: edit it (title, tags, body) then run: hooks/doc.sh context rebuild"
    echo "$file"
}

# ----- append (cross-session continuation) -----------------------------------

doc_append() {
    local slug="${1:-}"
    [ -n "$slug" ] || { echo "Usage: doc.sh context append <slug>" >&2; return 2; }
    slug="$(slugify "$slug")"

    local matches
    matches="$(ls "$DOC_DIR" 2>/dev/null | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}-${slug}\\.md$" || true)"
    local count
    count="$(printf '%s\n' "$matches" | grep -c . || true)"

    if [ "$count" -eq 0 ]; then
        echo "No snapshot matches slug: $slug" >&2
        echo "Did you mean: hooks/doc.sh context new $slug" >&2
        return 1
    fi
    if [ "$count" -gt 1 ]; then
        echo "Multiple snapshots match slug '$slug':" >&2
        printf '  %s\n' $matches >&2
        echo "Pass the exact filename (without docs/context/ prefix) instead." >&2
        return 1
    fi

    local target="$DOC_DIR/$matches"
    cat >> "$target" <<EOF

## Follow-up — $(now)
TODO
EOF

    echo "Appended Follow-up section to $target"
    echo "Edit the new section. Frontmatter unchanged so no rebuild needed."
    echo "$target"
}

# ----- list ------------------------------------------------------------------

doc_list() {
    local limit="${1:-30}"
    if [ ! -f "$DOC_INDEX" ]; then
        echo "No context index ($DOC_INDEX). Run hooks/init.sh." >&2
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
            if ($0 ~ /^\|[[:space:]]*[0-9]{4}-/) {
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
    [ -d "$DOC_DIR" ] || { echo "No $DOC_DIR. Run hooks/init.sh." >&2; return 1; }

    local tmp; tmp="$(mktemp)"
    local rowfile; rowfile="$(mktemp)"
    trap 'rm -f "$tmp" "$rowfile"' RETURN

    doc_index_header > "$tmp"

    : > "$rowfile"
    local count=0 f base date slug title tags
    shopt -s nullglob
    for f in "$DOC_DIR"/*.md; do
        base="$(basename "$f")"
        [ "$base" = "INDEX.md" ] && continue
        case "$base" in INDEX.md.bak.*) continue ;; esac
        [[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-.+\.md$ ]] || continue

        date="$(read_frontmatter "$f" date)"
        slug="$(read_frontmatter "$f" slug)"
        title="$(read_frontmatter "$f" title)"
        tags="$(read_frontmatter "$f" tags)"

        if [ -z "$date" ] || [ -z "$slug" ]; then
            [[ "$base" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-(.+)\.md$ ]] || continue
            [ -z "$date" ] && date="${BASH_REMATCH[1]}"
            [ -z "$slug" ] && slug="${BASH_REMATCH[2]}"
        fi
        [ -z "$title" ] || [ "$title" = "TODO one-line title" ] && title="(pending — fill frontmatter then rebuild)"
        [ -z "$tags" ] || [ "$tags" = "" ] && tags=""

        printf '%s\t| %s | %s | %s | %s |\n' "$date" "$date" "$slug" "$title" "$tags" >> "$rowfile"
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
    [ -n "$query" ] || { echo "Usage: doc.sh context search <query>" >&2; return 2; }
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
