#!/bin/bash
# Generate complete diff report between source and destination directories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Accept optional parameters, default to 'source' and 'destination'
SOURCE_DIR_NAME="${1:-source}"
DEST_DIR_NAME="${2:-destination}"

SOURCE_DIR="$SCRIPT_DIR/$SOURCE_DIR_NAME"
DEST_DIR="$SCRIPT_DIR/$DEST_DIR_NAME"
OUTPUT_FILE="$SCRIPT_DIR/file-differences.txt"

# Validate directories exist
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory not found: $SOURCE_DIR"
    exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
    echo "Error: Destination directory not found: $DEST_DIR"
    exit 1
fi

echo "Comparing directories..."
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_DIR"
echo ""

# Run diff excluding common non-source directories
# --no-dereference: treat symlinks as files (don't follow them) to avoid broken symlink errors
diff -rq --no-dereference "$SOURCE_DIR" "$DEST_DIR" \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='.DS_Store' \
    --exclude='vendor' \
    > "$OUTPUT_FILE" 2>&1

echo "✓ Generated: $OUTPUT_FILE"
wc -l "$OUTPUT_FILE"
