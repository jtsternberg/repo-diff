#!/bin/bash
# Migrate files that only exist in source to destination

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/source"
DEST_DIR="$SCRIPT_DIR/destination"
ADDITIONS_FILE="$SCRIPT_DIR/additions-list.txt"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if additions list exists
if [ ! -f "$ADDITIONS_FILE" ]; then
    echo -e "${RED}Error: $ADDITIONS_FILE not found.${NC}"
    echo "Run ./run-all.sh first to generate the additions list."
    exit 1
fi

# Count files
TOTAL=$(wc -l < "$ADDITIONS_FILE")
if [ "$TOTAL" -eq 0 ]; then
    echo "No additions to migrate."
    exit 0
fi

echo "Found $TOTAL file(s) to add to destination"
echo ""

# Pass through to migrate-files.sh with proper arguments
exec "$SCRIPT_DIR/migrate-files.sh" "$ADDITIONS_FILE" "$SOURCE_DIR" "$DEST_DIR" "$@"
