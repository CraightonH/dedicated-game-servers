# Chart Versioning Policy

## Overview

This repository uses **Calendar Versioning (CalVer)** for Helm charts with the format `YYYY.MM.MICRO`.

See [VERSIONING.md](VERSIONING.md) for the full rationale.

## When to Bump Versions

### MICRO (Patch) Increment

Increment the MICRO version whenever you change:
- `values.yaml` - any setting changed, added, or removed
- `templates/` - any template file modified
- `Chart.yaml` - dependencies, keywords, metadata
- Chart dependencies - upgrading library chart version

**Examples:**
- `2026.01.0` → `2026.01.1` (first patch in January 2026)
- `2026.01.1` → `2026.01.2` (second patch)
- `2026.01.99` → `2026.01.100` (no limit on MICRO)

### Do NOT bump for:
- `README.md` changes
- `test.sh` modifications
- `.helmignore` or `.gitignore` updates
- Documentation-only changes

## Version Check Workflow

The `version-check.yaml` workflow runs on all PRs and **fails** if:
- A chart's `values.yaml`, `templates/`, or `Chart.yaml` changed
- But the `version` field in `Chart.yaml` was not bumped

This ensures every release contains only intentional changes.

## Library Chart Changes

**Special case:** When `game-server-library` chart is updated:

1. Bump `charts/game-server-library/Chart.yaml` version
2. Bump **all game charts** that depend on it:
   - Update `charts/<game>/Chart.yaml` version (MICRO++)
   - Update `dependencies[].version` to match new library version

**Why:** Library changes affect all dependent charts, so they all need new releases.

### Example Library Update

Library chart changes from `2026.01.0` to `2026.01.1`:

```yaml
# charts/factorio/Chart.yaml
version: 2026.01.2  # Bump MICRO
dependencies:
  - name: game-server-library
    version: "2026.01.1"  # Update to new library version
```

```yaml
# charts/valheim/Chart.yaml
version: 2026.01.1  # Bump MICRO
dependencies:
  - name: game-server-library
    version: "2026.01.1"  # Update to new library version
```

## Automated Versioning

### Current: Manual

Currently, version bumps are **manual** and enforced by CI:
- ✅ Pros: Explicit control, clear changelog
- ⚠️ Cons: Easy to forget, requires discipline

### Future: Automated (Considered)

Potential automation approaches:

1. **Conventional Commits + Automatic Bumps**
   - Parse commit messages (`feat:`, `fix:`, `chore:`)
   - Auto-increment MICRO on merge to main
   - Generate changelog automatically

2. **GitHub Actions Release Workflow**
   - Manual trigger: "Release factorio chart"
   - Bumps version, creates tag, publishes
   - More control but still manual

3. **Pre-merge Version Bump Bot**
   - Bot comments on PR: "Bump factorio to 2026.01.X?"
   - Maintainer confirms
   - Bot pushes version bump commit

**Current decision:** Manual versioning with CI enforcement strikes the right balance for a small project.

## How to Bump a Version

### In Your PR

1. Identify which charts you modified
2. Edit `charts/<chart>/Chart.yaml`
3. Increment the `version` field:
   ```yaml
   version: 2026.01.1  # Was 2026.01.0
   ```
4. Commit:
   ```bash
   git add charts/<chart>/Chart.yaml
   git commit -m "chore(chart): bump version to 2026.01.1"
   ```

### Commit Message Format

Use conventional commit format:
```
chore(<chart>): bump version to <version>

- Reason for bump (e.g., "refactor gameConfig to serverSettings")
```

### If Version Check Fails

The CI will fail with:
```
❌ ERROR: Chart 'factorio' was modified but Chart.yaml version was not bumped!
```

**To fix:**
1. Check which chart failed
2. Bump the version in `Chart.yaml`
3. Push the fix

## Publishing

Charts are published to GitHub Pages when merged to `main`:
1. PR merged → `helm-publish.yaml` workflow runs
2. Packages all charts: `helm package charts/*`
3. Updates `index.yaml` on `gh-pages` branch
4. Charts available at: `https://craightonh.github.io/dedicated-game-servers/`

Users install via:
```bash
helm repo add dedicated-game-servers https://craightonh.github.io/dedicated-game-servers/
helm install factorio dedicated-game-servers/factorio --version 2026.01.1
```

## FAQ

### What if I only change README?

No version bump needed. The version-check workflow ignores README changes.

### What if I forget to bump the version?

CI will fail on your PR. Just push another commit with the version bump.

### Should I use semver ranges for dependencies?

For library chart dependencies, use `^` range:
```yaml
dependencies:
  - name: game-server-library
    version: "^2026.01.0"  # Allows 2026.01.x
```

This allows automatic patch updates without editing game charts.

### How do I know what MICRO version to use?

Look at the current version, add 1:
```bash
$ yq -r '.version' charts/factorio/Chart.yaml
2026.01.5

# Next version: 2026.01.6
```

### What happens on January 1st of next year?

Reset MICRO to 0 and increment YYYY:
- `2026.01.99` (December 2026)
- `2026.02.0` (February 2026)  
- `2027.01.0` (January 2027)

## Related Documentation

- [VERSIONING.md](VERSIONING.md) - Full CalVer explanation and rationale
- [CONTRIBUTING.md](../CONTRIBUTING.md) - How to contribute charts
- [creating-new-game-chart.md](creating-new-game-chart.md) - Step-by-step chart creation
