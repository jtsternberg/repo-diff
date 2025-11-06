#!/bin/bash
# Review all files in a specific directory with git difftool

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -z "$1" ]; then
    echo "Usage: $0 <directory-name>"
    echo ""
    echo "Available directories:"
    if [ -f "directories-with-changes.txt" ]; then
        cat directories-with-changes.txt | sed 's/^/  - /'
    fi
    exit 1
fi

DIR="$1"
FILE_LIST="by-directory/${DIR}-files.txt"

if [ ! -f "$FILE_LIST" ]; then
    echo "Error: $FILE_LIST not found"
    echo ""
    echo "Available directories:"
    if [ -f "directories-with-changes.txt" ]; then
        cat directories-with-changes.txt | sed 's/^/  - /'
    fi
    exit 1
fi

FILE_COUNT=$(wc -l < "$FILE_LIST")
echo "Reviewing $FILE_COUNT files in '$DIR/' directory with git difftool..."
echo ""

while IFS= read -r file; do
    if [ -f "source/$file" ] && [ -f "destination/$file" ]; then
        git difftool --no-index "source/$file" "destination/$file"
    else
        missing_file=''
        if [ -f "source/$file" ]; then
            missing_file='source'
        elif [ -f "destination/$file" ]; then
            missing_file='destination'
        fi
        echo "File not found in $missing_file/$file"
    fi
done < "$FILE_LIST"

echo ""
echo "Done! Reviewed all files in '$DIR/' directory."
