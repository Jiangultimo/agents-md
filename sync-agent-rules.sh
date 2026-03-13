#!/bin/bash

# Define paths
SRC="README.md"
DEST_DIR="$HOME/.config/opencode"
DEST_FILE="$DEST_DIR/AGENTS.md"

# Check if source file exists
if [ ! -f "$SRC" ]; then
    echo "Error: Source file $SRC not found"
    exit 1
fi

# Backup existing target file if it exists
if [ -f "$DEST_FILE" ]; then
    # Generate timestamp
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    BACKUP_FILE="$DEST_DIR/AGENTS.bak.$TIMESTAMP.md"
    echo "Backing up existing AGENTS.md to: $BACKUP_FILE"
    cp "$DEST_FILE" "$BACKUP_FILE"
fi

# Sync file
echo "Syncing $SRC to $DEST_FILE"
cp "$SRC" "$DEST_FILE"

echo "Sync complete!"