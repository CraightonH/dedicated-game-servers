# Versioning Strategy

This project uses **Calendar Versioning (CalVer)** for Helm charts.

## Format

**`YYYY.MM.MICRO`**

Where:
- **YYYY**: 4-digit year
- **MM**: 2-digit month (zero-padded)
- **MICRO**: Incremental number starting at 0 for the first release in that month

## Examples

- `2026.01.0` - First release in January 2026
- `2026.01.1` - Second release in January 2026
- `2026.02.0` - First release in February 2026

## Rationale

### Why CalVer Instead of SemVer?

**Calendar Versioning (CalVer)** is more appropriate for Helm charts than Semantic Versioning (SemVer) because:

1. **Helm charts are deployment artifacts, not libraries**
   - SemVer is designed for library versioning with strict API compatibility contracts
   - Helm charts describe how to deploy applications, not provide programmatic APIs

2. **Release timing is more meaningful than breaking changes**
   - Users care about "is this chart recent?" more than API compatibility
   - CalVer immediately shows when a chart was released
   - Example: `2026.01.0` is clearly newer than `2025.12.5`

3. **Kubernetes and game server changes are time-based**
   - Kubernetes API versions change on a schedule
   - Game server images update frequently with new releases
   - Chart updates often track these time-based changes

4. **Simpler versioning for users**
   - No need to interpret major/minor/patch semantics
   - "Latest" is always the highest year.month.micro

5. **Industry precedent**
   - Ubuntu uses CalVer (e.g., 22.04, 24.04)
   - Many container images use CalVer
   - Kubernetes itself uses a form of CalVer (1.28 = 2023-08)

### SemVer Limitations for Charts

SemVer's contract (`MAJOR.MINOR.PATCH`):
- **MAJOR**: Incompatible API changes
- **MINOR**: Backwards-compatible functionality
- **PATCH**: Backwards-compatible bug fixes

**Problems with this for Helm charts:**
- What constitutes a "breaking change" in a Helm chart?
  - Changing a default value? (inconvenient but not "breaking")
  - Upgrading Kubernetes API version? (often necessary, not a "break")
  - Changing resource limits? (tuning, not breaking)
- Most chart updates don't fit neatly into semver categories
- Forces artificial versioning decisions (is this 1.1.0 or 2.0.0?)

## Versioning Workflow

### For New Releases

1. **Same month as previous release**: Increment MICRO
   - `2026.01.0` → `2026.01.1`

2. **New month**: Reset MICRO to 0
   - `2026.01.5` → `2026.02.0`

3. **New year**: Use new year
   - `2026.12.3` → `2027.01.0`

### Chart Dependencies

Game charts depend on the library chart with an **exact version**:

```yaml
dependencies:
  - name: game-server-library
    version: "2026.01.0"  # Exact version, not range
```

**Why exact versions?**
- Ensures reproducible builds
- Prevents unexpected breakage from library changes
- Charts are lightweight; users can update easily

When the library chart is updated:
1. Library chart gets new version: `2026.02.0`
2. Game charts explicitly update their dependency reference
3. Both charts are released together

### Updating Charts

**Trigger a new release when:**
- Fixing bugs in chart templates
- Updating default values
- Adding new features
- Updating to new Kubernetes API versions
- Updating game server image tags (if pinned)

**Version bump rules:**
- Same month: increment MICRO
- New month: reset MICRO to 0

## Migration from SemVer

This project previously used SemVer (`1.0.0`, `1.0.1`, etc.).

**Migration strategy:**
- Old versions remain available in the Helm repository
- New versions use CalVer starting from `2026.01.0`
- No automatic migration path (users explicitly choose new version)

**Example:**
```bash
# Old way (semver)
helm install factorio dedicated-game-servers/factorio --version 1.0.0

# New way (calver)
helm install factorio dedicated-game-servers/factorio --version 2026.01.0

# Or just use latest (always highest calver)
helm install factorio dedicated-game-servers/factorio
```

## Version Comparisons

### CalVer Sorting

CalVer versions sort correctly as strings in most tools:

```
2026.01.0
2026.01.1
2026.02.0
2027.01.0
```

Helm and most package managers handle this correctly:
```bash
helm search repo dedicated-game-servers/factorio --versions
# Shows newest (highest) first
```

### Version Constraints

Since we use exact versions for dependencies, version constraints are not needed. If we ever need them:

**Not recommended** (but possible):
```yaml
dependencies:
  - name: game-server-library
    version: ">=2026.01.0"  # Any version in 2026 or later
```

**Recommended** (current approach):
```yaml
dependencies:
  - name: game-server-library
    version: "2026.01.0"  # Exact version
```

## References

- [Calendar Versioning (CalVer)](https://calver.org/)
- [Helm Best Practices - Chart Versions](https://helm.sh/docs/topics/chart_best_practices/#versions)
- [Ubuntu Versioning](https://ubuntu.com/about/release-cycle)

## Examples from This Project

### Library Chart

```yaml
# charts/game-server-library/Chart.yaml
version: 2026.01.0  # First release January 2026
```

### Game Charts

```yaml
# charts/factorio/Chart.yaml
version: 2026.01.0  # First release January 2026
dependencies:
  - name: game-server-library
    version: "2026.01.0"  # Exact library version
```

### Legacy Chart

```yaml
# chart/Chart.yaml (deprecated)
version: 2026.01.0  # Migrated to CalVer
```

## Future Considerations

### Alternate CalVer Schemes

If daily releases become common, consider:
- `YYYY.MM.DD` (e.g., `2026.01.27`) - Daily versioning
- `YYYY.0M.0D` (e.g., `2026.01.27`) - Explicit day format

Current choice of `YYYY.MM.MICRO` assumes:
- Multiple releases per month are possible
- Daily releases are not necessary
- Monthly granularity is sufficient for most users

This can be revisited if release frequency changes.
