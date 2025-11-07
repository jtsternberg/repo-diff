#!/bin/bash
# Identify all commits in source repo that modified the files we want to migrate

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SOURCE_DIR="${1:-$SCRIPT_DIR/source}"
DEST_DIR="${2:-$SCRIPT_DIR/destination}"

# Resolve directory paths
if [[ "$SOURCE_DIR" != /* ]]; then
    SOURCE_DIR="$SCRIPT_DIR/$SOURCE_DIR"
fi
if [[ "$DEST_DIR" != /* ]]; then
    DEST_DIR="$SCRIPT_DIR/$DEST_DIR"
fi

INPUT_FILE="$SCRIPT_DIR/modified-files-list.txt"
OUTPUT_FILE="$SCRIPT_DIR/commits-database.json"

# Create temp directory
TEMP_DIR="/tmp/repo-diff"
mkdir -p "$TEMP_DIR"

# Validate directories exist
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Error: Source directory not found: $SOURCE_DIR${NC}"
    exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
    echo -e "${RED}Error: Destination directory not found: $DEST_DIR${NC}"
    exit 1
fi

# Validate input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: $INPUT_FILE not found${NC}"
    echo "Run ./run-all.sh first to generate file lists"
    exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo "Install jq with: sudo apt-get install jq (Debian/Ubuntu)"
    echo "                 brew install jq (macOS)"
    exit 1
fi

echo "======================================"
echo "Identifying Commits That Changed Files"
echo "======================================"
echo ""
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_DIR"
echo "Input: $INPUT_FILE"
echo "Output: $OUTPUT_FILE"
echo ""

# Initialize JSON structure
cat > "$OUTPUT_FILE" << 'EOF'
{
  "files": {},
  "commits": {},
  "stats": {
    "total_files": 0,
    "total_commits": 0,
    "commits_to_pick": 0,
    "commits_already_exist": 0
  }
}
EOF

# Track statistics
total_files=0
total_commits_found=0
unique_commits=()
commits_in_dest=0

# Process each file
echo "Processing files..."
while IFS= read -r file; do
    # Skip empty lines
    [ -z "$file" ] && continue

    ((total_files++))
    echo -n "[$total_files] $file... "

    # Check if file exists in source
    if [ ! -f "$SOURCE_DIR/$file" ]; then
        echo -e "${YELLOW}not in source, skipping${NC}"
        continue
    fi

    # Get all commits that touched this file
    cd "$SOURCE_DIR"
    commits_json="[]"

    while IFS='|' read -r hash author email date message; do
        # Skip empty results
        [ -z "$hash" ] && continue

        # Check if commit exists in destination
        cd "$DEST_DIR"
        exists_in_dest="false"
        if git cat-file -t "$hash" &>/dev/null; then
            exists_in_dest="true"
            ((commits_in_dest++))
        fi
        cd "$SOURCE_DIR"

        # Get files touched by this commit (write to temp file to avoid arg list too long)
        git show --name-only --format="" "$hash" | jq -R -s -c 'split("\n") | map(select(length > 0))' > "$TEMP_DIR/files_touched.tmp"

        # Get parent commits (write to temp file)
        git show --format="%P" --no-patch "$hash" | tr ' ' '\n' | jq -R -s -c 'split("\n") | map(select(length > 0))' > "$TEMP_DIR/parents.tmp"

        # Check if it's a merge commit
        parent_count=$(jq 'length' < "$TEMP_DIR/parents.tmp")
        is_merge="false"
        if [ "$parent_count" -gt 1 ]; then
            is_merge="true"
        fi

        # Escape JSON strings
        message_escaped=$(echo "$message" | jq -R -s '.')

        # Build commit object using temp files
        commit_obj=$(jq -n \
            --arg hash "$hash" \
            --arg author "$author" \
            --arg email "$email" \
            --arg date "$date" \
            --argjson message "$message_escaped" \
            --arg exists "$exists_in_dest" \
            --slurpfile files "$TEMP_DIR/files_touched.tmp" \
            --slurpfile parents "$TEMP_DIR/parents.tmp" \
            --arg is_merge "$is_merge" \
            '{
                hash: $hash,
                author: $author,
                email: $email,
                date: $date,
                message: $message,
                exists_in_dest: ($exists == "true"),
                files_touched: $files[0],
                target_files: [],
                parents: $parents[0],
                is_merge: ($is_merge == "true")
            }')

        # Add to commits_json array (using temp file to avoid arg list too long)
        echo "$commit_obj" > "$TEMP_DIR/commit_obj.tmp"
        commits_json=$(echo "$commits_json" | jq --slurpfile obj "$TEMP_DIR/commit_obj.tmp" '. + $obj')

        # Track unique commits
        if [[ ! " ${unique_commits[@]} " =~ " ${hash} " ]]; then
            unique_commits+=("$hash")
            ((total_commits_found++))
        fi

    done < <(git log --format="%H|%an|%ae|%ad|%s" --date=iso --all --follow -- "$file" 2>/dev/null)

    # Add file and its commits to database
    if [ "$commits_json" != "[]" ]; then
        # Use temp file to avoid arg list too long
        echo "$commits_json" > "$TEMP_DIR/commits_array.tmp"
        jq --arg file "$file" --slurpfile commits "$TEMP_DIR/commits_array.tmp" \
            '.files[$file] = $commits[0]' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

        commit_count=$(echo "$commits_json" | jq 'length')
        echo -e "${GREEN}found $commit_count commits${NC}"
    else
        echo -e "${YELLOW}no commits found${NC}"
    fi

    cd "$SCRIPT_DIR"
done < "$INPUT_FILE"

echo ""
echo "Building commits index..."

# Build commits index and update target_files
cd "$SOURCE_DIR"
for hash in "${unique_commits[@]}"; do
    # Find all target files affected by this commit
    target_files="[]"
    while IFS= read -r file; do
        # Check if this commit touched this file
        if git log --format="%H" --all --follow -- "$file" 2>/dev/null | grep -q "^$hash$"; then
            target_files=$(echo "$target_files" | jq --arg f "$file" '. + [$f]')
        fi
    done < "$INPUT_FILE"

    # Get commit details again for the commits index
    IFS='|' read -r _ author email date message < <(git log --format="%H|%an|%ae|%ad|%s" --date=iso -n 1 "$hash")

    # Check if exists in dest
    cd "$DEST_DIR"
    exists_in_dest="false"
    if git cat-file -t "$hash" &>/dev/null; then
        exists_in_dest="true"
    fi
    cd "$SOURCE_DIR"

    # Get files touched and parents (write to temp files to avoid arg list too long)
    git show --name-only --format="" "$hash" | jq -R -s -c 'split("\n") | map(select(length > 0))' > "$TEMP_DIR/files_touched.tmp"
    git show --format="%P" --no-patch "$hash" | tr ' ' '\n' | jq -R -s -c 'split("\n") | map(select(length > 0))' > "$TEMP_DIR/parents.tmp"
    parent_count=$(jq 'length' < "$TEMP_DIR/parents.tmp")
    is_merge="false"
    if [ "$parent_count" -gt 1 ]; then
        is_merge="true"
    fi

    # Escape JSON strings and write target_files to temp file
    message_escaped=$(echo "$message" | jq -R -s '.')
    echo "$target_files" > "$TEMP_DIR/target_files.tmp"

    # Build commit object using temp files
    commit_obj=$(jq -n \
        --arg hash "$hash" \
        --arg author "$author" \
        --arg email "$email" \
        --arg date "$date" \
        --argjson message "$message_escaped" \
        --arg exists "$exists_in_dest" \
        --slurpfile files "$TEMP_DIR/files_touched.tmp" \
        --slurpfile target_files "$TEMP_DIR/target_files.tmp" \
        --slurpfile parents "$TEMP_DIR/parents.tmp" \
        --arg is_merge "$is_merge" \
        '{
            hash: $hash,
            author: $author,
            email: $email,
            date: $date,
            message: $message,
            exists_in_dest: ($exists == "true"),
            files_touched: $files[0],
            target_files: $target_files[0],
            parents: $parents[0],
            is_merge: ($is_merge == "true")
        }')

    # Add to commits index (using temp file to avoid arg list too long)
    cd "$SCRIPT_DIR"
    echo "$commit_obj" > "$TEMP_DIR/commit_obj.tmp"
    jq --arg hash "$hash" --slurpfile obj "$TEMP_DIR/commit_obj.tmp" \
        '.commits[$hash] = $obj[0]' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
done

# Update statistics
commits_to_pick=$((total_commits_found - commits_in_dest))
jq --arg total_files "$total_files" \
   --arg total_commits "$total_commits_found" \
   --arg commits_to_pick "$commits_to_pick" \
   --arg commits_already_exist "$commits_in_dest" \
   '.stats.total_files = ($total_files | tonumber) |
    .stats.total_commits = ($total_commits | tonumber) |
    .stats.commits_to_pick = ($commits_to_pick | tonumber) |
    .stats.commits_already_exist = ($commits_already_exist | tonumber)' \
   "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

echo ""
echo "======================================"
echo "✓ Commit identification complete!"
echo "======================================"
echo ""
echo "Statistics:"
echo "  Total files analyzed: $total_files"
echo "  Total commits found: $total_commits_found"
echo "  Commits to cherry-pick: $commits_to_pick"
echo "  Commits already in dest: $commits_in_dest"
echo ""
echo "Generated: $OUTPUT_FILE"
echo ""

# Clean up temp directory
rm -rf "$TEMP_DIR"
