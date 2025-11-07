# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a repository diff analysis tool for comparing two Git repositories (source and destination). It generates detailed reports on file differences and provides migration scripts to selectively copy files between repositories.

## Commands

### Initial Setup

```bash
# Quick setup with bootstrap script (one-liner)
curl -sSL https://raw.githubusercontent.com/jtsternberg/repo-diff/master/bootstrap.sh | \
    bash -s -- <source-repo-url> <destination-repo-url>

# Manual setup
git clone <source-repo-url> source
git clone <destination-repo-url> destination
```

### Generate Reports

```bash
# Run all analysis steps
./run-all.sh

# Individual steps
./1-generate-diff.sh           # Generate raw diff output
./2-extract-modified-files.sh  # Extract modified files (differ)
./2b-extract-additions.sh      # Extract additions (only in source)
./2c-extract-removals.sh       # Extract removals (only in destination)
./3-generate-summary.sh        # Generate markdown summary
./4-generate-directory-reports.sh  # Generate per-directory reports
```

### Review Changes

```bash
# Review root-level files with git difftool
./review-depth-0.sh

# List directories with changes
cat directories-with-changes.txt

# Review specific directory
./review-directory.sh <directory-name>
```

### Migrate Files

```bash
# Migrate everything (modified files + additions) - DEFAULT BEHAVIOR
./migrate-all.sh source destination

# Migrate everything AND delete files only in destination
./migrate-all.sh --removals source destination

# Auto-confirm without prompts
./migrate-all.sh --yes source destination
./migrate-all.sh --yes --removals source destination

# Migrate specific operations individually
./migrate-files.sh modified-files-list.txt source destination [--yes]
./migrate-additions.sh [--yes]
./migrate-removals.sh [--yes]

# Migrate specific file list
./migrate-files.sh <file-list> <source-dir> <dest-dir> [--yes]
```

## Repository Structure

```
repo-diff/
├── source/              # Source repository
├── destination/         # Destination repository
├── by-directory/        # Per-directory file lists
├── Generated reports:
│   ├── file-differences.txt         # Raw diff output
│   ├── modified-files-list.txt      # Files that differ
│   ├── additions-list.txt           # Files only in source
│   ├── removals-list.txt            # Files only in destination
│   ├── diff-summary.md              # Markdown summary
│   ├── depth-0-files.txt            # Root level files
│   └── directories-with-changes.txt # Directories with changes
└── Scripts:
    ├── run-all.sh                   # Master script
    ├── 1-generate-diff.sh           # Step 1: Generate diff
    ├── 2-extract-modified-files.sh  # Step 2: Extract modified files
    ├── 2b-extract-additions.sh      # Step 2b: Extract additions
    ├── 2c-extract-removals.sh       # Step 2c: Extract removals
    ├── 3-generate-summary.sh        # Step 3: Generate summary
    ├── 4-generate-directory-reports.sh  # Step 4: Directory reports
    ├── migrate-files.sh             # Migrate specific files
    ├── migrate-additions.sh         # Migrate additions only
    ├── migrate-removals.sh          # Delete removals only
    ├── migrate-all.sh               # Migrate everything (modified + additions by default)
    ├── review-depth-0.sh            # Review root files
    └── review-directory.sh          # Review directory
```

## Workflow

### Analyzing Differences

1. Clone or update both repositories
2. Run `./run-all.sh` to generate all reports
3. Review `diff-summary.md` for overview
4. Check `directories-with-changes.txt` for affected directories
5. Review specific directory file lists in `by-directory/`

### Migrating Changes

1. Identify files to migrate from reports
2. Use `review-directory.sh` to visually inspect changes with difftool
3. Migrate files using `migrate-files.sh` or `migrate-all.sh`
4. Add `--yes` flag to skip confirmation prompts

### Updating Repositories

```bash
cd source && git pull
cd ../destination && git pull
cd .. && ./run-all.sh  # Regenerate reports
```

## Output Files

- **file-differences.txt**: Raw output from `diff -rq` showing all differences
- **modified-files-list.txt**: Files that exist in both repos but differ in content
- **additions-list.txt**: Files that only exist in source (ready to add to destination)
- **removals-list.txt**: Files that only exist in destination (potentially remove from destination)
- **diff-summary.md**: Statistics and categorized file lists (modified, added, removed)
- **depth-0-files.txt**: Root level files only
- **directories-with-changes.txt**: Top-level directories with modifications
- **by-directory/*.txt**: Per-directory file lists (e.g., `cli-files.txt`, `includes-files.txt`)

## Exclusions

The diff automatically excludes:
- `.git` directories
- `node_modules` directories
- `vendor` directories

## Important Notes

- All scripts use absolute paths and work from any directory
- The `migrate-files.sh` script creates directories as needed
- Use `--yes` flag to skip confirmation prompts
- Scripts validate inputs and show colored output (✓ success, ⚠ skipped, ✗ error)
- Run scripts in order when executing manually (dependencies exist between steps)

## Working with Repository Content

When working with files in `source/` or `destination/`, refer to any CLAUDE.md or documentation files within those repositories for project-specific conventions and patterns.
