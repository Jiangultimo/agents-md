#!/bin/bash
# Print the root index filename for the current project: AGENTS.md or CLAUDE.md.
# Detection order favors explicit tool traces; AGENTS.md is the default.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

cd "$PROJECT_ROOT"

if [ -d .claude ] || [ -f CLAUDE.md ]; then
    echo "CLAUDE.md"
elif [ -d .codex ] || [ -d .config/opencode ] || [ -f AGENTS.md ]; then
    echo "AGENTS.md"
else
    echo "AGENTS.md"
fi
