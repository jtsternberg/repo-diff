#!/bin/bash
# Extract list of modified files from diff report

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFF_FILE="$SCRIPT_DIR/file-differences.txt"
OUTPUT_FILE="$SCRIPT_DIR/modified-files-list.txt"

if [ ! -f "$DIFF_FILE" ]; then
    echo "Error: $DIFF_FILE not found. Run 1-generate-diff.sh first."
    exit 1
fi

echo "Extracting modified files from diff report..."

# Extract lines starting with "Files" (modified files)
grep "^Files" "$DIFF_FILE" | \
    sed 's|Files .*/source/||' | \
    sed 's| and .*/destination/.*||' | \
    sort > "$OUTPUT_FILE"

echo "✓ Generated: $OUTPUT_FILE"
wc -l "$OUTPUT_FILE"
