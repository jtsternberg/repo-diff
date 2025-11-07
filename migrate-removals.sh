#!/bin/bash
# Delete files that only exist in destination

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$SCRIPT_DIR/destination"
REMOVALS_FILE="$SCRIPT_DIR/removals-list.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if removals list exists
if [ ! -f "$REMOVALS_FILE" ]; then
    echo -e "${RED}Error: $REMOVALS_FILE not found.${NC}"
    echo "Run ./run-all.sh first to generate the removals list."
    exit 1
fi

# Count files
TOTAL=$(wc -l < "$REMOVALS_FILE")
if [ "$TOTAL" -eq 0 ]; then
    echo "No files to remove."
    exit 0
fi

echo "======================================"
echo "Delete Files Only in Destination"
echo "======================================"
echo "Destination: $DEST_DIR"
echo "Total files: $TOTAL"
echo ""
echo -e "${YELLOW}WARNING: This will DELETE $TOTAL files from destination!${NC}"
echo ""

# Ask for confirmation (unless --yes flag is set)
YES_FLAG="$1"
if [[ "$YES_FLAG" != "--yes" ]]; then
    read -p "Are you sure you want to delete these files? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deletion cancelled."
        exit 0
    fi
fi

# Counters
SUCCESS_COUNT=0
SKIP_COUNT=0
ERROR_COUNT=0

echo ""
echo "Starting deletion..."
echo ""

# Process each file
while IFS= read -r file; do
    # Skip empty lines
    if [ -z "$file" ]; then
        continue
    fi

    DEST_FILE="$DEST_DIR/$file"

    # Check if file exists
    if [ ! -f "$DEST_FILE" ]; then
        echo -e "${YELLOW}[SKIP]${NC} $file (not found)"
        ((SKIP_COUNT++))
        continue
    fi

    # Delete file
    rm "$DEST_FILE"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[DELETED]${NC} $file"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}[ERROR]${NC} $file (deletion failed)"
        ((ERROR_COUNT++))
    fi
done < "$REMOVALS_FILE"

echo ""
echo "======================================"
echo "Deletion Complete"
echo "======================================"
echo -e "${GREEN}Deleted:${NC} $SUCCESS_COUNT files"
echo -e "${YELLOW}Skipped:${NC} $SKIP_COUNT files"
echo -e "${RED}Errors:${NC}  $ERROR_COUNT files"
echo "======================================"

if [ $ERROR_COUNT -gt 0 ]; then
    exit 1
fi
