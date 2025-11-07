#!/bin/bash
# Migrate/copy all files from directory file lists from source to destination

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_usage() {
    echo "Usage: $0 [--yes] [--removals] <source-dir> <dest-dir>"
    echo ""
    echo "Arguments:"
    echo "  --yes        Skip confirmation prompts (auto-confirm all migrations)"
    echo "  --removals   Also delete files that only exist in destination"
    echo "  source-dir   Source directory"
    echo "  dest-dir     Destination directory"
    echo ""
    echo "Examples:"
    echo "  # Migrate all modified files AND additions (default behavior)"
    echo "  $0 source destination"
    echo ""
    echo "  # Migrate everything AND delete files only in destination"
    echo "  $0 --removals source destination"
    echo ""
    echo "  # Auto-confirm all operations without prompts"
    echo "  $0 --yes --removals source destination"
    echo ""
    echo "This script processes by default:"
    echo "  - modified-files-list.txt (files that exist in both but differ)"
    echo "  - additions-list.txt (files only in source)"
    echo "  - removals-list.txt (files only in destination, if --removals flag is used)"
    exit 1
}

# Check arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
fi

# Parse flags
YES_FLAG=""
REMOVALS_FLAG=""
while [[ "$1" == --* ]]; do
    case "$1" in
        --yes)
            YES_FLAG="--yes"
            shift
            ;;
        --removals)
            REMOVALS_FLAG="true"
            shift
            ;;
        *)
            echo -e "${RED}Unknown flag: $1${NC}"
            show_usage
            ;;
    esac
done

SOURCE_DIR="${1:-source}"
DEST_DIR="${2:-destination}"

# Resolve directory paths
if [[ "$SOURCE_DIR" != /* ]]; then
    SOURCE_DIR="$SCRIPT_DIR/$SOURCE_DIR"
fi
if [[ "$DEST_DIR" != /* ]]; then
    DEST_DIR="$SCRIPT_DIR/$DEST_DIR"
fi

# Validate directories exist
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Error: Source directory not found: $SOURCE_DIR${NC}"
    exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
    echo -e "${RED}Error: Destination directory not found: $DEST_DIR${NC}"
    exit 1
fi

echo "======================================"
echo "Migrate All Files"
echo "======================================"
echo "Source:      $SOURCE_DIR"
echo "Destination: $DEST_DIR"
echo "Removals:    ${REMOVALS_FLAG:-false}"
echo ""

# Process modified files list
if [ -f "$SCRIPT_DIR/modified-files-list.txt" ]; then
    MODIFIED_COUNT=$(wc -l < "$SCRIPT_DIR/modified-files-list.txt")
    if [ "$MODIFIED_COUNT" -gt 0 ]; then
        echo "[1/3] Migrating $MODIFIED_COUNT modified files..."
        bash "$SCRIPT_DIR/migrate-files.sh" "$SCRIPT_DIR/modified-files-list.txt" "$SOURCE_DIR" "$DEST_DIR" "$YES_FLAG"
        echo ""
    fi
fi

# Process additions (always included by default)
if [ -f "$SCRIPT_DIR/additions-list.txt" ]; then
    ADDITIONS_COUNT=$(wc -l < "$SCRIPT_DIR/additions-list.txt")
    if [ "$ADDITIONS_COUNT" -gt 0 ]; then
        echo "[2/3] Migrating $ADDITIONS_COUNT additions (files only in source)..."
        bash "$SCRIPT_DIR/migrate-files.sh" "$SCRIPT_DIR/additions-list.txt" "$SOURCE_DIR" "$DEST_DIR" "$YES_FLAG"
        echo ""
    else
        echo "[2/3] No additions to migrate (additions-list.txt is empty)"
        echo ""
    fi
fi

# Process removals if flag is set
if [ "$REMOVALS_FLAG" == "true" ] && [ -f "$SCRIPT_DIR/removals-list.txt" ]; then
    REMOVALS_COUNT=$(wc -l < "$SCRIPT_DIR/removals-list.txt")
    if [ "$REMOVALS_COUNT" -gt 0 ]; then
        echo "[3/3] Deleting $REMOVALS_COUNT files that only exist in destination..."
        bash "$SCRIPT_DIR/migrate-removals.sh" "$YES_FLAG"
        echo ""
    else
        echo "[3/3] No removals to process (removals-list.txt is empty)"
        echo ""
    fi
elif [ "$REMOVALS_FLAG" != "true" ]; then
    echo "[3/3] Skipping removals (use --removals flag to delete files only in destination)"
    echo ""
fi

echo "======================================"
echo "✓ All migrations complete!"
echo "======================================"