# Repository Diff Analysis Scripts

Scripts to compare two Git repositories and identify all differences.

## Quick Setup (One-Liner)

Set up everything with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/jtsternberg/repo-diff/master/bootstrap.sh | \
    bash -s -- \
    <source-repo-url> \
    <destination-repo-url>
```

This will:
1. Clone the `repo-diff` repository
2. Clone the source repository into `repo-diff/source/`
3. Clone the destination repository into `repo-diff/destination/`

Example:
```bash
curl -sSL https://raw.githubusercontent.com/jtsternberg/repo-diff/master/bootstrap.sh | \
    bash -s -- \
    git@github.com:user/source-repo.git \
    git@github.com:user/dest-repo.git
```

## Setup

Before using these scripts, you need to clone the source and destination repositories:

```bash
# Clone the source repository
git clone <source-repo-url> source

# Clone the destination repository
git clone <destination-repo-url> destination
```

The scripts expect these directories to exist:
- `source/` - The source repository to compare from
- `destination/` - The destination repository to compare to

## Directory Structure

```
repo-diff/
├── source/              # Source repository
├── destination/         # Destination repository
├── run-all.sh                   # Master script (runs all steps)
├── 1-generate-diff.sh           # Step 1: Generate diff report
├── 2-extract-modified-files.sh  # Step 2: Extract modified files
├── 3-generate-summary.sh        # Step 3: Generate summary
├── 4-generate-directory-reports.sh  # Step 4: Generate directory-based reports
├── migrate-files.sh                 # Migrate files from source to destination
├── migrate-all.sh                    # Migrate all files from all directory lists
├── review-depth-0.sh                 # Review root files
├── review-directory.sh               # Review specific directory
└── Generated files:
    ├── file-differences.txt         # Raw diff output
    ├── modified-files-list.txt      # List of modified files
    ├── diff-summary.md              # Markdown summary
    ├── depth-0-files.txt            # Root level files
    ├── directories-with-changes.txt # List of directories with changes
    └── by-directory/                # Per-directory file lists
```

## Quick Start

Once you have cloned both repositories, generate all reports:

```bash
cd repo-diff
./run-all.sh
```

This runs all 4 steps automatically.

## Manual Step-by-Step

Run individual scripts if you only need specific outputs:

```bash
# Step 1: Generate raw diff
./1-generate-diff.sh

# Step 2: Extract modified files list
./2-extract-modified-files.sh

# Step 3: Generate markdown summary
./3-generate-summary.sh

# Step 4: Generate directory-based reports
./4-generate-directory-reports.sh
```

## Review Changes with git difftool

After running the scripts, review files visually:

```bash
# Review root-level files
./review-depth-0.sh

# List available directories
cat directories-with-changes.txt

# Review all files in a specific directory (e.g., 'includes')
./review-directory.sh includes

# Review all files in another directory (e.g., 'cli')
./review-directory.sh cli
```

These scripts use `git difftool --no-index` to open your configured diff tool for each file pair.

## Output Files

### file-differences.txt
Raw output from `diff -rq` command showing all differences.

### modified-files-list.txt
Clean list of files that exist in both repos but have different content.

### diff-summary.md
Markdown-formatted summary with:
- Statistics (modified, added, removed files)
- List of modified files
- Files only in source
- Files only in fork

### depth-0-files.txt
Root level files only (e.g., `composer.json`, `.gitignore`)

### directories-with-changes.txt
List of all top-level directories that contain modified files.

### by-directory/*.txt
Individual file lists for each directory. For example:
- `by-directory/cli-files.txt` - All changes in `cli/` directory
- `by-directory/includes-files.txt` - All changes in `includes/` directory (includes subdirectories)

## What Gets Excluded

The diff excludes:
- `.git` directories
- `node_modules` directories
- `vendor` directories

## Migrating Files

After reviewing changes, you can migrate files from one repo to another:

```bash
# Copy all root-level files from source to destination
./migrate-files.sh depth-0-files.txt source destination

# Copy all CLI files from destination to source
./migrate-files.sh by-directory/cli-files.txt destination source

# Copy files from a custom list
echo "includes/api/user.inc.php" > my-files.txt
echo "cli/script.php" >> my-files.txt
./migrate-files.sh my-files.txt source destination

# Copy all files from all directory lists (processes depth-0-files.txt and all by-directory/*.txt files)
./migrate-all.sh source destination
```

The scripts will:
- Ask for confirmation before copying
- Create directories as needed
- Show colored output (✓ success, ⚠ skipped, ✗ error)
- Provide summary statistics

## Updating Repositories

When you update either repository:

```bash
cd repo-diff/source
git pull

cd repo-diff/destination
git pull

cd repo-diff
./run-all.sh  # Regenerate all reports
```

## Future Development

See [ROADMAP.md](ROADMAP.md) for planned features and enhancements, including:
- Intelligent commit cherry-picking to identify and apply source commits
- Enhanced diff visualization
- Merge strategy recommendations

## Notes

- All scripts use absolute paths and can be run from any directory
- Scripts will error if dependencies are missing (e.g., running step 2 before step 1)
- The `run-all.sh` script ensures correct execution order
