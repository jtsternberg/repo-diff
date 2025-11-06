#!/bin/bash
# Migrate/copy all files from directory file lists from source to destination

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_usage() {
    echo "Usage: $0 [--yes] <source-dir> <dest-dir>"
    echo ""
    echo "Arguments:"
    echo "  --yes       Skip confirmation prompts (auto-confirm all migrations)"
    echo "  source-dir  Source directory"
    echo "  dest-dir    Destination directory"
    echo ""
    echo "Examples:"
    echo "  # Copy all files from all directory lists from source to destination"
    echo "  $0 source destination"
    echo ""
    echo "  # Copy all files from all directory lists from destination to source"
    echo "  $0 destination source"
    echo ""
    echo "  # Auto-confirm all migrations without prompts"
    echo "  $0 --yes source destination"
    echo ""
    echo "This script processes:"
    echo "  - depth-0-files.txt (root level files)"
    echo "  - by-directory/*-files.txt (all directory file lists)"
    exit 1
}

# Check arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
fi

# Check for --yes flag
YES_FLAG=""
if [[ "$1" == "--yes" ]]; then
    YES_FLAG="--yes"
    shift
fi

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

# Process depth-0 files (root level files)
if [ -f "$SCRIPT_DIR/depth-0-files.txt" ]; then
    bash "$SCRIPT_DIR/migrate-files.sh" "$SCRIPT_DIR/depth-0-files.txt" "$SOURCE_DIR" "$DEST_DIR" "$YES_FLAG"
fi

# Process all directory file lists
shopt -s dotglob
directoryfiles=($(for f in "$SCRIPT_DIR/by-directory"/*.txt; do
    [[ -f "$f" ]] && basename "$f"
done))
shopt -u dotglob

if [ ${#directoryfiles[@]} -gt 0 ]; then
    for directoryfile in "${directoryfiles[@]}"; do
        bash "$SCRIPT_DIR/migrate-files.sh" "$SCRIPT_DIR/by-directory/$directoryfile" "$SOURCE_DIR" "$DEST_DIR" "$YES_FLAG"
    done
fi