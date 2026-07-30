#!/bin/bash
# PreToolUse hook (matcher: Bash) — deterministic backstop for the arc-based
# snapshot SOP: if this session ever declared a "Pending snapshot:", block the
# first `git commit` once (exit 2) so the agent flushes — or consciously
# dismisses — the pending snapshot before committing. The model still judges
# WHETHER a flush applies; the hook only guarantees the judgment happens.
# Sessions that never declared a pending snapshot commit with zero friction.
#
# Wire-up (user-level ~/.claude/settings.json):
#   hooks.PreToolUse += { matcher: "Bash",
#     hooks: [{ type: "command", command: "~/.agent-hooks/pre-commit-flush-reminder.sh" }] }
#
# Requires python3 (stock on macOS) for JSON parsing. Fails open: any parse
# problem exits 0 so a broken hook never blocks real work.
set -euo pipefail

input="$(cat)"

# Prints "<session_id>\t<transcript_path>" only when tool_input.command is a
# git commit invocation; prints nothing otherwise. The regex keeps `git` and
# `commit` within one shell command (no crossing |, ;, &) to avoid matching
# e.g. `git log; echo commit`.
meta="$(printf '%s' "$input" | python3 -c '
import json, re, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
cmd = (d.get("tool_input") or {}).get("command") or ""
if not re.search(r"\bgit\b[^|;&]*\bcommit\b", cmd):
    sys.exit(0)
print((d.get("session_id") or "unknown") + "\t" + (d.get("transcript_path") or ""))
' || true)"

[ -n "$meta" ] || exit 0

tab=$'\t'
session_id="${meta%%"$tab"*}"
transcript_path="${meta#*"$tab"}"

# No transcript, or no pending declaration ever made → nothing to remind about.
[ -f "$transcript_path" ] || exit 0
grep -qF "Pending snapshot:" "$transcript_path" || exit 0

# Remind at most once per session; afterwards commits pass silently. A stale
# marker is harmless — it is keyed by session id and lives in TMPDIR.
marker="${TMPDIR:-/tmp}/agent-hooks-flush-reminded-${session_id}"
[ -e "$marker" ] && exit 0
: > "$marker"

cat >&2 <<'MSG'
[hooks SOP] A "Pending snapshot:" was declared earlier in this session. Flush it
now (doc.sh context new + fill template + rebuild) — or state explicitly that it
no longer applies — then re-run the commit. This reminder fires once per session.
MSG
exit 2
