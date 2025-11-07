#!/bin/bash
# Analyze discovered commits and create an ordered cherry-pick plan

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

INPUT_FILE="$SCRIPT_DIR/commits-database.json"
OUTPUT_FILE="$SCRIPT_DIR/cherry-pick-plan.json"

# Validate input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: $INPUT_FILE not found${NC}"
    echo "Run ./5-identify-commits.sh first to generate the commits database"
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
echo "Analyzing Commits & Creating Plan"
echo "======================================"
echo ""
echo "Input: $INPUT_FILE"
echo "Output: $OUTPUT_FILE"
echo ""

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Processing commits..."

# Extract unique commits, sort by date (oldest first), and build ordered plan
commits_array=$(jq -r '
    .commits
    | to_entries
    | map(.value)
    | sort_by(.date)
' "$INPUT_FILE")

# Count commits and categorize
total_commits=$(echo "$commits_array" | jq 'length')
merge_commits=$(echo "$commits_array" | jq '[.[] | select(.is_merge == true)] | length')
regular_commits=$((total_commits - merge_commits))
commits_to_pick=$(echo "$commits_array" | jq '[.[] | select(.exists_in_dest == false)] | length')
commits_already_exist=$(echo "$commits_array" | jq '[.[] | select(.exists_in_dest == true)] | length')

echo "  Total commits: $total_commits"
echo "  Regular commits: $regular_commits"
echo "  Merge commits: $merge_commits"
echo "  Need to cherry-pick: $commits_to_pick"
echo "  Already in destination: $commits_already_exist"
echo ""

# Get directories affected
echo "Analyzing affected directories..."
directories=$(jq -r '
    .commits
    | to_entries
    | map(.value.target_files[])
    | map(split("/")[0])
    | unique
    | sort
' "$INPUT_FILE")

directory_count=$(echo "$directories" | jq 'length')
echo "  Affected directories: $directory_count"
echo ""

# Estimate time (rough estimate: 1 commit per 2 seconds)
estimated_seconds=$((commits_to_pick * 2))
estimated_minutes=$((estimated_seconds / 60))

# Build the plan with order numbers
echo "Building cherry-pick plan..."
plan_commits=$(echo "$commits_array" | jq --argjson start 1 '
    to_entries | map(
        .value + {
            order: (.key + $start),
            merge_strategy: (if .value.is_merge then "-m 1" else null end),
            expected_conflicts: false
        }
    )
')

# Create the final plan structure
jq -n \
    --arg version "1.0" \
    --arg timestamp "$TIMESTAMP" \
    --argjson commits "$plan_commits" \
    --arg total "$total_commits" \
    --arg merge "$merge_commits" \
    --arg regular "$regular_commits" \
    --argjson directories "$directories" \
    --arg est_time "~$estimated_minutes minutes" \
    --arg commits_to_pick "$commits_to_pick" \
    --arg commits_exist "$commits_already_exist" \
    '{
        plan_version: $version,
        generated_at: $timestamp,
        commits: $commits,
        summary: {
            total_commits: ($total | tonumber),
            commits_to_pick: ($commits_to_pick | tonumber),
            commits_already_exist: ($commits_exist | tonumber),
            merge_commits: ($merge | tonumber),
            regular_commits: ($regular | tonumber),
            directories_affected: $directories,
            estimated_time: $est_time
        }
    }' > "$OUTPUT_FILE"

echo ""
echo "======================================"
echo "✓ Cherry-pick plan created!"
echo "======================================"
echo ""
echo "Plan Summary:"
echo "  Total commits in plan: $total_commits"
echo "  Commits to cherry-pick: $commits_to_pick"
echo "  Already in destination: $commits_already_exist"
echo "  Merge commits: $merge_commits"
echo "  Regular commits: $regular_commits"
echo "  Affected directories: $directory_count"
echo "  Estimated time: ~$estimated_minutes minutes"
echo ""
echo "Generated: $OUTPUT_FILE"
echo ""
echo "Next step: Run ./7-cherry-pick-commits.sh to execute the plan"
