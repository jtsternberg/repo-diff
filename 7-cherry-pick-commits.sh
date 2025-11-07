#!/bin/bash
# Execute cherry-pick plan and create migration branch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DESTINATION_DIR="${1:-$SCRIPT_DIR/destination}"
PLAN_FILE="$SCRIPT_DIR/cherry-pick-plan.json"
LOG_FILE="$SCRIPT_DIR/cherry-pick-log.txt"
STATE_FILE="$SCRIPT_DIR/.cherry-pick-state.json"
CONFLICTS_FILE="$SCRIPT_DIR/conflicts-encountered.txt"

# Default settings
CONFLICT_STRATEGY="pause"
SKIP_EXISTING="false"
AUTO_YES="false"
RESUME="false"

# Parse flags
show_usage() {
    echo "Usage: $0 [destination-dir] [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --conflict-strategy=<strategy>  How to handle conflicts:"
    echo "                                  pause: Stop and prompt user (default)"
    echo "                                  skip: Skip conflicting commits"
    echo "                                  auto: Attempt auto-resolution"
    echo "  --skip-existing                 Skip commits already in destination"
    echo "  --yes                           Auto-confirm prompts"
    echo "  --resume                        Resume from last failed commit"
    echo "  -h, --help                      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                                      # Use defaults"
    echo "  $0 --conflict-strategy=skip             # Skip conflicts"
    echo "  $0 --skip-existing --yes                # Skip existing, no prompts"
    echo "  $0 --resume                             # Resume from interruption"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --conflict-strategy=*)
            CONFLICT_STRATEGY="${1#*=}"
            shift
            ;;
        --skip-existing)
            SKIP_EXISTING="true"
            shift
            ;;
        --yes)
            AUTO_YES="true"
            shift
            ;;
        --resume)
            RESUME="true"
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            if [[ "$1" != -* ]]; then
                DESTINATION_DIR="$1"
            else
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
            fi
            shift
            ;;
    esac
done

# Validate conflict strategy
if [[ ! "$CONFLICT_STRATEGY" =~ ^(pause|skip|auto)$ ]]; then
    echo -e "${RED}Error: Invalid conflict strategy: $CONFLICT_STRATEGY${NC}"
    echo "Must be one of: pause, skip, auto"
    exit 1
fi

# Resolve directory path
if [[ "$DESTINATION_DIR" != /* ]]; then
    DESTINATION_DIR="$SCRIPT_DIR/$DESTINATION_DIR"
fi

# Validate destination directory exists
if [ ! -d "$DESTINATION_DIR" ]; then
    echo -e "${RED}Error: Destination directory not found: $DESTINATION_DIR${NC}"
    exit 1
fi

# Validate plan file exists
if [ ! -f "$PLAN_FILE" ]; then
    echo -e "${RED}Error: $PLAN_FILE not found${NC}"
    echo "Run ./6-analyze-commits.sh first to generate the cherry-pick plan"
    exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    exit 1
fi

echo "======================================"
echo "Cherry-Pick Migration Execution"
echo "======================================"
echo ""
echo "Destination: $DESTINATION_DIR"
echo "Plan: $PLAN_FILE"
echo "Log: $LOG_FILE"
echo ""
echo "Configuration:"
echo "  Conflict strategy: $CONFLICT_STRATEGY"
echo "  Skip existing: $SKIP_EXISTING"
echo "  Auto-confirm: $AUTO_YES"
echo "  Resume mode: $RESUME"
echo ""

# Initialize log file
echo "Cherry-Pick Execution Log - $(date)" > "$LOG_FILE"
echo "Configuration: conflict-strategy=$CONFLICT_STRATEGY, skip-existing=$SKIP_EXISTING" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Initialize conflicts file
echo "Conflicts Encountered - $(date)" > "$CONFLICTS_FILE"
echo "" >> "$CONFLICTS_FILE"

# Navigate to destination
cd "$DESTINATION_DIR"

# Get total commits
total_commits=$(jq '.summary.total_commits' "$PLAN_FILE")
commits_to_pick=$(jq '.summary.commits_to_pick' "$PLAN_FILE")

echo "Cherry-pick plan:"
echo "  Total commits: $total_commits"
echo "  To cherry-pick: $commits_to_pick"
echo ""

# Determine starting point
start_order=1
if [ "$RESUME" == "true" ] && [ -f "$STATE_FILE" ]; then
    last_order=$(jq -r '.current' "$STATE_FILE")
    start_order=$((last_order + 1))
    echo -e "${BLUE}Resuming from commit #$start_order${NC}"
    echo ""
fi

# Create or checkout branch
if [ "$RESUME" == "false" ]; then
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" == "migrate/cherry-pick-baseline" ]; then
        echo -e "${YELLOW}Already on branch: migrate/cherry-pick-baseline${NC}"
    else
        if git show-ref --verify --quiet refs/heads/migrate/cherry-pick-baseline; then
            echo -e "${YELLOW}Branch migrate/cherry-pick-baseline already exists${NC}"
            if [ "$AUTO_YES" == "false" ]; then
                read -p "Delete and recreate? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "Aborting."
                    exit 1
                fi
            fi
            git branch -D migrate/cherry-pick-baseline
        fi
        echo "Creating branch: migrate/cherry-pick-baseline"
        git checkout -b migrate/cherry-pick-baseline
    fi
    echo ""
fi

# Counters
current=0
successful=0
failed=0
skipped=0

# Process each commit
while read -r commit_json; do
    order=$(echo "$commit_json" | jq -r '.order')

    # Skip if before resume point
    if [ "$order" -lt "$start_order" ]; then
        continue
    fi

    ((current++))

    hash=$(echo "$commit_json" | jq -r '.hash')
    is_merge=$(echo "$commit_json" | jq -r '.is_merge')
    message=$(echo "$commit_json" | jq -r '.message')
    exists_in_dest=$(echo "$commit_json" | jq -r '.exists_in_dest')

    echo "[$current/$commits_to_pick] Commit $order/$total_commits"
    echo "  Hash: $hash"
    echo "  Message: $message"

    # Check if already exists and skip if requested
    if [[ "$exists_in_dest" == "true" && "$SKIP_EXISTING" == "true" ]]; then
        echo -e "  ${YELLOW}⊘ SKIP: Commit already exists in destination${NC}"
        echo "[$order] SKIP: $hash - already in destination" >> "$LOG_FILE"
        ((skipped++))
        echo ""
        continue
    fi

    # Build cherry-pick command
    if [[ "$is_merge" == "true" ]]; then
        cmd="git cherry-pick -x -m 1 $hash"
        echo "  Type: Merge commit (using -m 1)"
    else
        cmd="git cherry-pick -x $hash"
        echo "  Type: Regular commit"
    fi

    # Execute cherry-pick
    echo "  Executing: $cmd"
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        echo -e "  ${GREEN}✓ SUCCESS${NC}"
        echo "[$order] SUCCESS: $hash" >> "$LOG_FILE"
        ((successful++))
    else
        # Conflict detected
        echo -e "  ${RED}✗ CONFLICT${NC}"
        echo "[$order] CONFLICT: $hash - $message" >> "$LOG_FILE"
        echo "Commit: $hash" >> "$CONFLICTS_FILE"
        echo "Message: $message" >> "$CONFLICTS_FILE"
        echo "" >> "$CONFLICTS_FILE"

        case "$CONFLICT_STRATEGY" in
            pause)
                echo ""
                echo -e "${RED}Conflict encountered. Manual resolution required.${NC}"
                echo ""
                echo "Options:"
                echo "  git cherry-pick --continue  # After resolving conflicts"
                echo "  git cherry-pick --skip      # Skip this commit"
                echo "  git cherry-pick --abort     # Abort entire process"
                echo ""
                echo "After resolving, run:"
                echo "  $0 --resume"
                echo ""
                # Save state
                echo "{\"current\": $order, \"hash\": \"$hash\"}" > "$STATE_FILE"
                exit 1
                ;;
            skip)
                echo -e "  ${YELLOW}⊘ SKIP: Skipping due to conflict${NC}"
                git cherry-pick --skip >> "$LOG_FILE" 2>&1
                ((failed++))
                ;;
            auto)
                echo -e "  ${BLUE}→ AUTO: Attempting automatic resolution${NC}"
                git cherry-pick --abort >> "$LOG_FILE" 2>&1
                if git cherry-pick -x --strategy-option=theirs "$hash" >> "$LOG_FILE" 2>&1; then
                    echo -e "  ${GREEN}✓ AUTO-RESOLVED${NC}"
                    echo "[$order] AUTO-RESOLVED: $hash" >> "$LOG_FILE"
                    ((successful++))
                else
                    echo -e "  ${YELLOW}⊘ SKIP: Auto-resolution failed${NC}"
                    git cherry-pick --skip >> "$LOG_FILE" 2>&1
                    ((failed++))
                fi
                ;;
        esac
    fi

    # Save state
    echo "{\"current\": $order, \"hash\": \"$hash\"}" > "$STATE_FILE"
    echo ""

done < <(jq -c '.commits[]' "$PLAN_FILE")

# Final commit
echo "Creating final migration commit..."
git commit --allow-empty -m "Migration complete: Cherry-pick approach

Successfully cherry-picked $successful commits
Failed/skipped: $failed commits
Already existed: $skipped commits

Generated by: 7-cherry-pick-commits.sh
Conflict strategy: $CONFLICT_STRATEGY" >> "$LOG_FILE" 2>&1

echo ""

# Tag the commit
echo "Tagging commit..."
if git tag -l | grep -q "^migrate-cherry-pick-baseline$"; then
    git tag -d migrate-cherry-pick-baseline
fi
git tag migrate-cherry-pick-baseline
echo -e "${GREEN}✓ Tagged commit: migrate-cherry-pick-baseline${NC}"
echo ""

# Clean up state file
rm -f "$STATE_FILE"

echo "======================================"
echo "✓ Cherry-Pick Migration Complete!"
echo "======================================"
echo ""
echo "Summary:"
echo "  Total processed: $current"
echo "  Successful: $successful"
echo "  Failed: $failed"
echo "  Skipped (already exist): $skipped"
echo ""
echo "Created:"
echo "  - Branch: migrate/cherry-pick-baseline"
echo "  - Tag: migrate-cherry-pick-baseline"
echo ""
echo "Logs:"
echo "  - Execution log: $LOG_FILE"
if [ $failed -gt 0 ]; then
    echo "  - Conflicts: $CONFLICTS_FILE"
fi
echo ""
echo "Next step: Run ./8-compare-strategies.sh to compare results"
