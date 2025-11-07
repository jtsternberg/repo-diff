# Roadmap

Future enhancements and features for the repository diff tool.

## Planned Features

### 1. Intelligent Commit Cherry-Picking (Priority: High)

**Goal**: Automatically identify and cherry-pick the commits from the source repository that caused specific file changes.

**Problem Statement**: Currently, the tool identifies *what* has changed between repositories, but not *why* or *when*. When repositories have diverged, manually finding and applying the relevant commits is time-consuming and error-prone.

**Proposed Solution**: Create scripts that:
1. For each modified file, use `git log` to identify commits that changed that file in the source repo
2. Analyze commit diffs to determine which commits contain the relevant changes
3. Filter out commits that already exist in the destination (by commit hash or similar content)
4. Generate a recommended cherry-pick sequence
5. Optionally apply the cherry-picks automatically with conflict detection

**Challenges**:
- Determining which commits are already applied (different hashes but same content)
- Handling commit dependencies and ordering
- Managing merge conflicts during cherry-pick
- Dealing with commits that modify files outside the diff scope
- Handling renamed or moved files

**Potential Approach**:
- Use `git log --follow <file>` to track file history including renames
- Compare commit patches using `git patch-id` to identify equivalent commits
- Build a dependency graph of commits based on file modifications
- Use LLM prompts to analyze commit messages and code changes for semantic matching
- Generate an interactive review process for cherry-pick candidates

**Implementation Ideas**:
```bash
# Potential script structure
./5-identify-commits.sh          # Identify relevant commits for each file
./6-analyze-commits.sh           # Analyze and deduplicate commits
./cherry-pick-interactive.sh     # Interactive cherry-pick with conflict handling
./cherry-pick-all.sh            # Automated cherry-pick with --yes flag
```

**LLM Integration**:
- Analyze commit messages to understand intent
- Compare code changes semantically to identify equivalent commits
- Suggest commit groupings based on related functionality
- Generate conflict resolution strategies

---

## Future Considerations

### 2. Enhanced Diff Visualization
- Generate side-by-side HTML diff reports
- Interactive web UI for reviewing changes
- Syntax-highlighted diffs with context

### 3. Selective File Filtering
- Filter diffs by file type, directory patterns, or custom rules
- Support for .gitignore-style patterns
- Exclude/include specific file patterns from analysis

### 4. Merge Strategy Recommendations
- Analyze changes and recommend merge strategies (cherry-pick, merge, rebase)
- Identify potential conflict zones before migration
- Suggest atomic commit groups for safer migrations

### 5. Commit History Preservation
- Maintain commit history when migrating files (not just copying)
- Generate git patches for manual review
- Create feature branches with proper commit history

### 6. Configuration Management
- Config file support for repository-specific settings
- Preset configurations for common scenarios
- Custom exclusion patterns and migration rules

---

## Contributing Ideas

Have ideas for new features? Open an issue or submit a pull request with your proposals.
