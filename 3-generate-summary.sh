#!/bin/bash
# Generate markdown summary of differences

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFF_FILE="$SCRIPT_DIR/file-differences.txt"
OUTPUT_FILE="$SCRIPT_DIR/diff-summary.md"

if [ ! -f "$DIFF_FILE" ]; then
    echo "Error: $DIFF_FILE not found. Run 1-generate-diff.sh first."
    exit 1
fi

echo "Generating summary..."

# Count different types of changes
TOTAL_LINES=$(wc -l < "$DIFF_FILE")
MODIFIED_COUNT=$(grep "^Files" "$DIFF_FILE" | wc -l)
ONLY_SOURCE=$(grep "^Only in.*source" "$DIFF_FILE" | wc -l)
ONLY_DEST=$(grep "^Only in.*destination" "$DIFF_FILE" | wc -l)

# Generate summary
cat > "$OUTPUT_FILE" << EOF
# File Differences: source vs destination

## Summary Statistics
- **Modified files** (exist in both, content differs): $MODIFIED_COUNT
- **Files only in source** (missing from destination): $ONLY_SOURCE
- **Files only in destination** (new in destination): $ONLY_DEST
- **Total differences**: $TOTAL_LINES lines

## Modified Files (Content Differs)
EOF

# Add modified files
grep "^Files" "$DIFF_FILE" | \
    sed 's|Files .*/source/||' | \
    sed 's| and .*/destination/.*||' | \
    sort >> "$OUTPUT_FILE"

# Add files only in source
cat >> "$OUTPUT_FILE" << 'EOF'

## Files Only in source
EOF

grep "^Only in.*source" "$DIFF_FILE" | \
    sed 's|Only in .*/source||' | \
    sed 's|: | -> |' | \
    sort >> "$OUTPUT_FILE"

# Add files only in destination
cat >> "$OUTPUT_FILE" << 'EOF'

## Files Only in destination
EOF

grep "^Only in.*destination" "$DIFF_FILE" | \
    sed 's|Only in .*/destination||' | \
    sed 's|: | -> |' | \
    sort >> "$OUTPUT_FILE"

echo "✓ Generated: $OUTPUT_FILE"
echo ""
echo "Summary:"
echo "  Modified: $MODIFIED_COUNT files"
echo "  Only in source: $ONLY_SOURCE files"
echo "  Only in destination: $ONLY_DEST files"
