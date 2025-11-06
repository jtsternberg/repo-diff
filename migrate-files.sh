#!/bin/bash
# Migrate/copy files from a file list from source to destination

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_usage() {
    echo "Usage: $0 <file-list> <source-dir> <dest-dir>"
    echo ""
    echo "Arguments:"
    echo "  file-list   Path to file containing list of files to migrate (one per line)"
    echo "  source-dir  Source directory"
    echo "  dest-dir    Destination directory"
    echo ""
    echo "Examples:"
    echo "  # Copy all depth-0 files from source to destination"
    echo "  $0 depth-0-files.txt source destination"
    echo ""
    echo "  # Copy all CLI files from destination to source"
    echo "  $0 by-directory/cli-files.txt destination source"
    echo ""
    echo "  # Copy specific files from a custom list"
    echo "  $0 my-files.txt source destination"
    echo ""
    echo "Available file lists:"
    echo "  - depth-0-files.txt"
    echo "  - by-directory/*-files.txt"
    exit 1
}

# Check arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
fi

FILE_LIST="$1"
SOURCE_DIR="${2:-source}"
DEST_DIR="${3:-destination}"

# Validate file list exists
if [ ! -f "$FILE_LIST" ]; then
    echo -e "${RED}Error: File list not found: $FILE_LIST${NC}"
    exit 1
fi

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

# Count files
TOTAL_FILES=$(wc -l < "$FILE_LIST")

echo "======================================"
echo "File Migration Tool"
echo "======================================"
echo "File list:   $FILE_LIST"
echo "Source:      $SOURCE_DIR"
echo "Destination: $DEST_DIR"
echo "Total files: $TOTAL_FILES"
echo ""

# Ask for confirmation
read -p "Proceed with migration? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

# Counters
SUCCESS_COUNT=0
SKIP_COUNT=0
ERROR_COUNT=0

echo ""
echo "Starting migration..."
echo ""

# Process each file
while IFS= read -r file; do
    # Skip empty lines
    if [ -z "$file" ]; then
        continue
    fi

    SOURCE_FILE="$SOURCE_DIR/$file"
    DEST_FILE="$DEST_DIR/$file"

    # Check if source file exists
    if [ ! -f "$SOURCE_FILE" ]; then
        echo -e "${YELLOW}[SKIP]${NC} $file (source not found)"
        ((SKIP_COUNT++))
        continue
    fi

    # Create destination directory if needed
    DEST_DIR_PATH=$(dirname "$DEST_FILE")
    if [ ! -d "$DEST_DIR_PATH" ]; then
        mkdir -p "$DEST_DIR_PATH"
        if [ $? -ne 0 ]; then
            echo -e "${RED}[ERROR]${NC} $file (failed to create directory)"
            ((ERROR_COUNT++))
            continue
        fi
    fi

    # Copy file
    cp "$SOURCE_FILE" "$DEST_FILE"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} $file"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}[ERROR]${NC} $file (copy failed)"
        ((ERROR_COUNT++))
    fi
done < "$FILE_LIST"

echo ""
echo "======================================"
echo "Migration Complete"
echo "======================================"
echo -e "${GREEN}Success:${NC} $SUCCESS_COUNT files"
echo -e "${YELLOW}Skipped:${NC} $SKIP_COUNT files"
echo -e "${RED}Errors:${NC}  $ERROR_COUNT files"
echo "======================================"

if [ $ERROR_COUNT -gt 0 ]; then
    exit 1
fi
