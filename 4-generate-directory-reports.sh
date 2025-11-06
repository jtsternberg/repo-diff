#!/bin/bash
# Generate directory-based file lists and review scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODIFIED_LIST="$SCRIPT_DIR/modified-files-list.txt"

if [ ! -f "$MODIFIED_LIST" ]; then
    echo "Error: $MODIFIED_LIST not found. Run 2-extract-modified-files.sh first."
    exit 1
fi

echo "Generating directory-based reports..."

# Depth 0 (root files)
grep -v "/" "$MODIFIED_LIST" > "$SCRIPT_DIR/depth-0-files.txt"
DEPTH0_COUNT=$(wc -l < "$SCRIPT_DIR/depth-0-files.txt")
echo "✓ Depth 0 (root): $DEPTH0_COUNT files -> depth-0-files.txt"

# Get list of top-level directories with changes
grep "/" "$MODIFIED_LIST" | cut -d'/' -f1 | sort -u > "$SCRIPT_DIR/directories-with-changes.txt"

echo ""
echo "Top-level directories with changes:"
while IFS= read -r dir; do
    count=$(grep "^$dir/" "$MODIFIED_LIST" | wc -l)
    printf "  %-30s %3d files\n" "$dir" "$count"
done < "$SCRIPT_DIR/directories-with-changes.txt"

# Generate file list for each directory
mkdir -p "$SCRIPT_DIR/by-directory"
while IFS= read -r dir; do
    grep "^$dir/" "$MODIFIED_LIST" > "$SCRIPT_DIR/by-directory/${dir}-files.txt"
done < "$SCRIPT_DIR/directories-with-changes.txt"

echo ""
echo "✓ Generated per-directory file lists in: by-directory/"

# Generate git difftool review script for depth-0
cat > "$SCRIPT_DIR/review-depth-0.sh" << 'REVIEWSCRIPT'
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
REVIEWSCRIPT
chmod +x "$SCRIPT_DIR/review-depth-0.sh"

# Generate a review script for a specific directory
cat > "$SCRIPT_DIR/review-directory.sh" << 'REVIEWSCRIPT'
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
REVIEWSCRIPT
chmod +x "$SCRIPT_DIR/review-directory.sh"

echo "✓ Generated: review-depth-0.sh"
echo "✓ Generated: review-directory.sh"
