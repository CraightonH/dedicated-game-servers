# Changelog

All notable changes to the game-server-library chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Calendar Versioning](../../docs/VERSIONING.md).

## [2026.01.2] - 2026-01-30

### Added
- **Environment Variable Map Format**: The `env` field now supports both map and list formats
  - Map format (human-friendly): `env: { SERVER_NAME: "My Server", MAX_PLAYERS: 10 }`
  - List format (Kubernetes native): `env: [{ name: SERVER_NAME, value: "My Server" }]`
  - Map format allows easier helm overrides: `--set env.SERVER_NAME="New Name"`
  - List format still supported for backwards compatibility
- New `game-server.env` template helper for processing environment variables

### Changed
- Updated deployment template to use `game-server.env` helper instead of direct YAML output

### Migration Guide
To migrate from list format to map format:

**Before:**
```yaml
env:
  - name: SERVER_NAME
    value: "My Server"
  - name: MAX_PLAYERS
    value: "10"
```

**After:**
```yaml
env:
  SERVER_NAME: "My Server"
  MAX_PLAYERS: 10
```

**Helm overrides before:**
```bash
--set env[0].value="New Name"  # Requires knowing array index
```

**Helm overrides after:**
```bash
--set env.SERVER_NAME="New Name"  # Direct key access
```

## [2026.01.1] - 2026-01-XX

### Initial Features
- Deployment template with Recreate strategy
- Service template (NodePort/LoadBalancer/ClusterIP)
- PersistentVolumeClaim template
- ConfigMap template with JSON/YAML support
- Common helper functions (labels, names, etc.)
