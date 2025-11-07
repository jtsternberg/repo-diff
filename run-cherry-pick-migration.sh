#!/bin/bash
# Master script to run complete cherry-pick migration workflow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
CONFLICT_STRATEGY="pause"
MISMATCH_ACTION="report"
SKIP_EXISTING="true"

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Run the complete cherry-pick migration workflow."
    echo ""
    echo "Options:"
    echo "  --conflict-strategy=<strategy>  How to handle conflicts:"
    echo "                                  pause: Stop and prompt user (default)"
    echo "                                  skip: Skip conflicting commits"
    echo "                                  auto: Attempt auto-resolution"
    echo "  --mismatch-action=<action>      What to do if strategies differ:"
    echo "                                  report: Generate detailed report (default)"
    echo "                                  merge: Create 3-way merge commit"
    echo "                                  flag: Exit with error code for CI/CD"
    echo "  --no-skip-existing              Don't skip commits already in destination"
    echo "  -h, --help                      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                                        # Interactive mode"
    echo "  $0 --conflict-strategy=skip \\             # Automated CI/CD mode"
    echo "     --mismatch-action=flag"
    echo "  $0 --conflict-strategy=auto               # Auto-resolve conflicts"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --conflict-strategy=*)
            CONFLICT_STRATEGY="${1#*=}"
            shift
            ;;
        --mismatch-action=*)
            MISMATCH_ACTION="${1#*=}"
            shift
            ;;
        --no-skip-existing)
            SKIP_EXISTING="false"
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            ;;
    esac
done

echo "=========================================="
echo "Cherry-Pick Migration Workflow"
echo "=========================================="
echo ""
echo "This workflow will:"
echo "  1. Create file-based migration baseline"
echo "  2. Identify commits that caused changes"
echo "  3. Analyze and plan cherry-pick strategy"
echo "  4. Execute cherry-pick migration"
echo "  5. Compare both strategies"
echo ""
echo "Configuration:"
echo "  Conflict strategy: $CONFLICT_STRATEGY"
echo "  Mismatch action: $MISMATCH_ACTION"
echo "  Skip existing commits: $SKIP_EXISTING"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

# Check for source and destination directories
if [ ! -d "source" ]; then
    echo -e "${RED}Error: source directory not found${NC}"
    echo "Run the bootstrap script or clone repositories first"
    exit 1
fi

if [ ! -d "destination" ]; then
    echo -e "${RED}Error: destination directory not found${NC}"
    echo "Run the bootstrap script or clone repositories first"
    exit 1
fi

# Check for modified-files-list.txt
if [ ! -f "modified-files-list.txt" ]; then
    echo -e "${YELLOW}modified-files-list.txt not found${NC}"
    echo "Running ./run-all.sh to generate file lists..."
    ./run-all.sh
    echo ""
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo "Install jq with:"
    echo "  sudo apt-get install jq  (Debian/Ubuntu)"
    echo "  brew install jq          (macOS)"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Phase 1: File-based baseline
echo "=========================================="
echo "Phase 1: File-Based Migration Baseline"
echo "=========================================="
echo ""
./baseline-migration.sh
echo -e "${GREEN}✓ Phase 1 complete${NC}"
echo ""

# Phase 2: Discover commits
echo "=========================================="
echo "Phase 2: Identifying Commits"
echo "=========================================="
echo ""
./5-identify-commits.sh
echo -e "${GREEN}✓ Phase 2 complete${NC}"
echo ""

# Phase 3: Analyze commits
echo "=========================================="
echo "Phase 3: Analyzing Commits & Creating Plan"
echo "=========================================="
echo ""
./6-analyze-commits.sh
echo -e "${GREEN}✓ Phase 3 complete${NC}"
echo ""

# Phase 4: Execute cherry-picks
echo "=========================================="
echo "Phase 4: Executing Cherry-Pick Migration"
echo "=========================================="
echo ""

skip_flag=""
if [ "$SKIP_EXISTING" == "true" ]; then
    skip_flag="--skip-existing"
fi

./7-cherry-pick-commits.sh --conflict-strategy="$CONFLICT_STRATEGY" $skip_flag --yes
echo -e "${GREEN}✓ Phase 4 complete${NC}"
echo ""

# Phase 5: Compare results
echo "=========================================="
echo "Phase 5: Comparing Migration Strategies"
echo "=========================================="
echo ""
./8-compare-strategies.sh --mismatch-action="$MISMATCH_ACTION"
comparison_result=$?
echo -e "${GREEN}✓ Phase 5 complete${NC}"
echo ""

# Final summary
echo "=========================================="
echo "Migration Workflow Complete"
echo "=========================================="
echo ""
echo "Generated files:"
echo "  - commits-database.json       (discovered commits)"
echo "  - cherry-pick-plan.json       (ordered plan)"
echo "  - cherry-pick-log.txt         (execution log)"
echo "  - comparison-report.md        (comparison results)"
echo ""
echo "Git branches in destination:"
echo "  - migrate/file-baseline       (file-copy approach)"
echo "  - migrate/cherry-pick-baseline (cherry-pick approach)"
echo ""
echo "Git tags in destination:"
echo "  - migrate-file-baseline"
echo "  - migrate-cherry-pick-baseline"
echo ""

if [ $comparison_result -eq 0 ]; then
    echo -e "${GREEN}✓ Both strategies produced identical results!${NC}"
    echo "The cherry-pick migration successfully preserves git history."
else
    echo -e "${YELLOW}⚠ Strategies produced different results${NC}"
    echo "Review comparison-report.md for details."
fi

exit $comparison_result
