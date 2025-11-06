#!/usr/bin/env bash
# curl -sSL https://raw.githubusercontent.com/jtsternberg/repo-diff/master/bootstrap.sh | bash -s -- <source-repo-url> <destination-repo-url>

set -e

SOURCE_REPO="${1}"
DEST_REPO="${2}"

if [ -z "$SOURCE_REPO" ] || [ -z "$DEST_REPO" ]; then
	echo "Usage: $0 <source-repo-url> <destination-repo-url>"
	echo "Example: $0 https://github.com/user/source-repo.git https://github.com/user/dest-repo.git"
	exit 1
fi

REPO_DIFF_DIR="repo-diff"

echo ">>> Cloning repo-diff repository..."
if [ ! -d "$REPO_DIFF_DIR" ]; then
	git clone https://github.com/jtsternberg/repo-diff.git "$REPO_DIFF_DIR"
else
	echo ">>> repo-diff directory already exists, skipping clone"
fi

cd "$REPO_DIFF_DIR"

echo ">>> Cloning source repository..."
if [ ! -d "source" ]; then
	git clone "$SOURCE_REPO" source
else
	echo ">>> source directory already exists, skipping clone"
fi

echo ">>> Cloning destination repository..."
if [ ! -d "destination" ]; then
	git clone "$DEST_REPO" destination
else
	echo ">>> destination directory already exists, skipping clone"
fi

echo ""
echo ">>> Setup complete!"
echo ">>> Next steps:"
echo ">>>   cd $REPO_DIFF_DIR"
echo ">>>   ./run-all.sh"

