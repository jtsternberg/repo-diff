#!/bin/bash
# Master script to run all diff analysis steps

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "======================================"
echo "Repository Diff Analysis Pipeline"
echo "======================================"
echo ""

# Step 1: Generate diff
echo "[1/6] Generating diff report..."
./1-generate-diff.sh
echo ""

# Step 2: Extract modified files
echo "[2/6] Extracting modified files list..."
./2-extract-modified-files.sh
echo ""

# Step 2b: Extract additions
echo "[2b/6] Extracting additions list..."
./2b-extract-additions.sh
echo ""

# Step 2c: Extract removals
echo "[2c/6] Extracting removals list..."
./2c-extract-removals.sh
echo ""

# Step 3: Generate summary
echo "[3/6] Generating summary..."
./3-generate-summary.sh
echo ""

# Step 4: Generate directory reports
echo "[4/6] Generating directory-based reports..."
./4-generate-directory-reports.sh
echo ""

echo "======================================"
echo "✓ All reports generated successfully!"
echo "======================================"
echo ""
echo "Generated files:"
echo "  - file-differences.txt         (raw diff output)"
echo "  - modified-files-list.txt      (files that differ)"
echo "  - additions-list.txt           (files only in source)"
echo "  - removals-list.txt            (files only in destination)"
echo "  - diff-summary.md              (markdown summary)"
echo "  - depth-0-files.txt            (root level files)"
echo "  - directories-with-changes.txt (directories with changes)"
echo "  - by-directory/*.txt           (per-directory file lists)"
echo ""
echo "Next steps:"
echo "  - View summary: cat diff-summary.md"
echo "  - Review root files: ./review-depth-0.sh"
echo "  - Review a directory: ./review-directory.sh <dirname>"
echo "  - Migrate everything: ./migrate-all.sh source destination"
echo "  - Migrate with deletions: ./migrate-all.sh --removals source destination"
