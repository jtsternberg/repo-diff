#!/bin/bash
# Compare file-based vs cherry-pick migration results

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DESTINATION_DIR="${1:-$SCRIPT_DIR/destination}"
MISMATCH_ACTION="report"

show_usage() {
    echo "Usage: $0 [destination-dir] [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --mismatch-action=<action>  What to do if strategies differ:"
    echo "                              report: Generate detailed report (default)"
    echo "                              merge: Create 3-way merge commit"
    echo "                              flag: Exit with error code for CI/CD"
    echo "  -h, --help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                           # Generate report only"
    echo "  $0 --mismatch-action=flag    # Exit with error if different"
    echo "  $0 --mismatch-action=merge   # Create combined branch"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mismatch-action=*)
            MISMATCH_ACTION="${1#*=}"
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            if [[ "$1" != -* ]]; then
                DESTINATION_DIR="$1"
            else
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
            fi
            shift
            ;;
    esac
done

# Validate mismatch action
if [[ ! "$MISMATCH_ACTION" =~ ^(report|merge|flag)$ ]]; then
    echo -e "${RED}Error: Invalid mismatch action: $MISMATCH_ACTION${NC}"
    echo "Must be one of: report, merge, flag"
    exit 1
fi

# Resolve directory path
if [[ "$DESTINATION_DIR" != /* ]]; then
    DESTINATION_DIR="$SCRIPT_DIR/$DESTINATION_DIR"
fi

# Validate destination directory exists
if [ ! -d "$DESTINATION_DIR" ]; then
    echo -e "${RED}Error: Destination directory not found: $DESTINATION_DIR${NC}"
    exit 1
fi

echo "======================================"
echo "Migration Strategy Comparison"
echo "======================================"
echo ""
echo "Destination: $DESTINATION_DIR"
echo ""

cd "$DESTINATION_DIR"

# Get the two tags
FILE_TAG="migrate-file-baseline"
CHERRY_TAG="migrate-cherry-pick-baseline"

# Verify tags exist
if ! git rev-parse "$FILE_TAG" &>/dev/null; then
    echo -e "${RED}Error: Tag '$FILE_TAG' not found${NC}"
    echo "Run ./baseline-migration.sh first"
    exit 1
fi

if ! git rev-parse "$CHERRY_TAG" &>/dev/null; then
    echo -e "${RED}Error: Tag '$CHERRY_TAG' not found${NC}"
    echo "Run ./7-cherry-pick-commits.sh first"
    exit 1
fi

echo "Comparing migration strategies..."
echo "  File-based tag:   $FILE_TAG"
echo "  Cherry-pick tag:  $CHERRY_TAG"
echo ""

# Compare the trees
if git diff --quiet "$FILE_TAG" "$CHERRY_TAG"; then
    echo -e "${GREEN}======================================"
    echo "✓ SUCCESS: Strategies Match!"
    echo "======================================${NC}"
    echo ""
    echo "Both migration strategies produced identical results."
    echo "The cherry-pick approach successfully replicated file-based migration"
    echo "while preserving full git history."
    echo ""
    exit 0
fi

echo -e "${YELLOW}======================================"
echo "⚠ MISMATCH: Strategies Differ"
echo "======================================${NC}"
echo ""
echo "The two migration strategies produced different results."
echo "Generating detailed comparison report..."
echo ""

# Generate detailed diff
REPORT="$SCRIPT_DIR/comparison-report.md"

cat > "$REPORT" << 'HEADER'
# Migration Strategy Comparison Report

## Summary

The file-based migration and cherry-pick migration produced different results.

## Tags Compared

- **File-based**: migrate-file-baseline
- **Cherry-pick**: migrate-cherry-pick-baseline

HEADER

# Count differences
files_changed=$(git diff --name-only "$FILE_TAG" "$CHERRY_TAG" | wc -l)
echo "  Files with differences: $files_changed"

# Get diff statistics
diff_stats=$(git diff --shortstat "$FILE_TAG" "$CHERRY_TAG")
echo "  $diff_stats"

echo "" >> "$REPORT"
echo "## Differences" >> "$REPORT"
echo "" >> "$REPORT"

# Files modified differently
echo "### Files Modified Differently" >> "$REPORT"
echo "" >> "$REPORT"
echo '```' >> "$REPORT"
git diff --name-only "$FILE_TAG" "$CHERRY_TAG" >> "$REPORT"
echo '```' >> "$REPORT"

# Files only in file-based
echo "" >> "$REPORT"
echo "### Files Only in File-Based Migration" >> "$REPORT"
echo "" >> "$REPORT"
files_only_file=$(git diff --name-only --diff-filter=D "$CHERRY_TAG" "$FILE_TAG")
if [ -n "$files_only_file" ]; then
    echo '```' >> "$REPORT"
    echo "$files_only_file" >> "$REPORT"
    echo '```' >> "$REPORT"
else
    echo "None" >> "$REPORT"
fi

# Files only in cherry-pick
echo "" >> "$REPORT"
echo "### Files Only in Cherry-Pick Migration" >> "$REPORT"
echo "" >> "$REPORT"
files_only_cherry=$(git diff --name-only --diff-filter=D "$FILE_TAG" "$CHERRY_TAG")
if [ -n "$files_only_cherry" ]; then
    echo '```' >> "$REPORT"
    echo "$files_only_cherry" >> "$REPORT"
    echo '```' >> "$REPORT"
else
    echo "None" >> "$REPORT"
fi

# Detailed diff
echo "" >> "$REPORT"
echo "### Detailed Diff" >> "$REPORT"
echo "" >> "$REPORT"
echo '```diff' >> "$REPORT"
git diff "$FILE_TAG" "$CHERRY_TAG" >> "$REPORT"
echo '```' >> "$REPORT"

# Statistics
echo "" >> "$REPORT"
echo "### Statistics" >> "$REPORT"
echo "" >> "$REPORT"
echo "- Files changed: $files_changed" >> "$REPORT"

insertions=$(echo "$diff_stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
deletions=$(echo "$diff_stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")

echo "- Lines added: ${insertions:-0}" >> "$REPORT"
echo "- Lines removed: ${deletions:-0}" >> "$REPORT"

echo ""
echo -e "${GREEN}✓ Generated detailed report: $REPORT${NC}"
echo ""

# Take action based on flag
case "$MISMATCH_ACTION" in
    report)
        echo "Action: Report only"
        echo ""
        echo "======================================"
        echo "Report Preview"
        echo "======================================"
        echo ""
        cat "$REPORT"
        echo ""
        echo "Full report saved to: $REPORT"
        exit 0
        ;;
    merge)
        echo "Action: Creating 3-way merge commit"
        echo ""
        git checkout -b migrate/combined
        echo "Created branch: migrate/combined"

        echo "Merging file-based migration..."
        if git merge "$FILE_TAG" --no-edit -m "Merge file-based migration"; then
            echo -e "${GREEN}✓ Merged file-based branch${NC}"
        fi

        echo "Merging cherry-pick migration..."
        if git merge "$CHERRY_TAG" --no-edit -m "Merge cherry-pick migration"; then
            echo -e "${GREEN}✓ Merged cherry-pick branch${NC}"
        else
            echo -e "${YELLOW}Manual merge resolution may be required${NC}"
        fi

        echo ""
        echo -e "${GREEN}✓ Created combined branch: migrate/combined${NC}"
        exit 0
        ;;
    flag)
        echo "Action: Flagging as failure for CI/CD"
        echo ""
        echo "======================================"
        echo "Report Preview"
        echo "======================================"
        echo ""
        cat "$REPORT"
        echo ""
        echo "Full report saved to: $REPORT"
        echo ""
        echo -e "${RED}Exiting with error code 1${NC}"
        exit 1
        ;;
esac
