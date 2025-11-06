#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f "depth-0-files.txt" ]; then
    echo "Error: depth-0-files.txt not found"
    exit 1
fi

echo "Reviewing depth-0 (root) files with git difftool..."
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
done < depth-0-files.txt

echo ""
echo "Done! Reviewed all depth-0 files."
