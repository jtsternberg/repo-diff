#!/bin/bash
# Extract list of files that only exist in destination (potential removals)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFF_FILE="$SCRIPT_DIR/file-differences.txt"
OUTPUT_FILE="$SCRIPT_DIR/removals-list.txt"
DEST_DIR="$SCRIPT_DIR/destination"

if [ ! -f "$DIFF_FILE" ]; then
    echo "Error: $DIFF_FILE not found. Run 1-generate-diff.sh first."
    exit 1
fi

echo "Extracting files only in destination (potential removals)..."

# Extract "Only in" lines for destination and convert to file paths
# Then expand directories to individual files using find
{
    grep "^Only in.*destination" "$DIFF_FILE" | \
    sed 's|Only in .*/destination/\(.*\): \(.*\)|\1/\2|' | \
    while IFS= read -r path; do
        full_path="$DEST_DIR/$path"
        if [ -f "$full_path" ]; then
            echo "$path"
        elif [ -d "$full_path" ]; then
            # Find all files in this directory
            find "$full_path" -type f | sed "s|$DEST_DIR/||"
        fi
    done
} | sort -u > "$OUTPUT_FILE"

echo "✓ Generated: $OUTPUT_FILE"
wc -l "$OUTPUT_FILE"
