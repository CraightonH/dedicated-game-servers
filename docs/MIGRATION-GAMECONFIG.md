# Migration Guide: gameConfig Structure Refactor

**Version**: game-server-library 2026.01.1+, factorio 2026.01.2+

## Overview

The `gameConfig` structure has been refactored to support more flexible configuration with nested config keys. This is a **breaking change** for existing installations.

## What Changed

### Old Structure (< 2026.01.1)

```yaml
gameConfig:
  enabled: true
  mountPath: /config
  files:
    server-settings.json: |
      {
        "name": "My Server",
        "max_players": 10
      }
    admin-list.txt: |
      admin1
      admin2
```

### New Structure (>= 2026.01.1)

```yaml
gameConfig:
  server-settings:
    enabled: true
    mountPath: /config
    configFormat: json
    config:
      name: "My Server"
      max_players: 10
  admin-list:
    enabled: true
    mountPath: /config
    file: |
      admin1
      admin2
```

## Key Differences

| Aspect | Old | New |
|--------|-----|-----|
| **Top-level structure** | `gameConfig.enabled`, `gameConfig.files` | Arbitrary keys under `gameConfig` |
| **File naming** | Explicit in `files` | Derived from key name + `configFormat` |
| **Config values** | Embedded in `files` as string | Separate `config` key with YAML/JSON values |
| **Enabling/disabling** | Single `enabled` for all files | Per-config-group `enabled` |
| **Mount paths** | Single `mountPath` for all files | Per-config-group `mountPath` |

## Migration Steps

### For Factorio Chart Users

If you're using the factorio chart with custom values:

**Old values.yaml:**
```yaml
gameConfig:
  enabled: true
  serverSettings:
    name: "My Server"
    maxPlayers: 20
    gamePassword: "secret"
```

**New values.yaml:**
```yaml
gameConfig:
  server-settings:
    enabled: true
    mountPath: /factorio/config
    configFormat: json
    config:
      name: "My Server"
      max_players: 20
      game_password: "secret"
```

**Key changes for Factorio:**
1. `gameConfig.enabled` → `gameConfig.server-settings.enabled`
2. `gameConfig.serverSettings` → `gameConfig.server-settings.config`
3. camelCase keys → snake_case keys (e.g., `maxPlayers` → `max_players`)

### For Custom Game Charts

If you've created your own game chart using the library:

1. **Update Chart.yaml dependency:**
   ```yaml
   dependencies:
     - name: game-server-library
       version: "^2026.01.1"  # Update to new version
       repository: "file://../game-server-library"
   ```

2. **Rebuild dependencies:**
   ```bash
   helm dependency build
   ```

3. **Update values.yaml:**
   - Move `gameConfig.files` entries to individual config groups
   - Add `enabled`, `mountPath`, and `configFormat` to each group
   - Move file content to either `config` (for structured data) or `file` (for raw strings)

4. **Update ConfigMap template (if you have one):**
   - Change from custom logic to `{{ include "game-server.configmap" . }}`
   - Remove any custom config generation logic

5. **Test your chart:**
   ```bash
   helm upgrade --install <release> ./charts/<your-chart>
   kubectl logs -f -l app=<your-chart>
   ```

## Example: Migrating a Custom Chart

### Before (using old library)

**values.yaml:**
```yaml
gameConfig:
  enabled: true
  mountPath: /server/config
  files:
    server.cfg: |
      name=My Server
      max_players=10
    admins.txt: |
      admin1
```

**templates/configmap.yaml:**
```yaml
{{ include "game-server.configmap" . }}
```

### After (using new library)

**values.yaml:**
```yaml
gameConfig:
  server-cfg:
    enabled: true
    mountPath: /server/config
    file: |
      name=My Server
      max_players=10
  admins:
    enabled: true
    mountPath: /server/config
    file: |
      admin1
```

**templates/configmap.yaml:**
```yaml
{{ include "game-server.configmap" . }}
```

Note: The template stays the same! The library handles the new structure automatically.

## Benefits of the New Structure

1. **More flexible**: Each config file can have its own mount path
2. **Better YAML support**: Use structured `config` instead of embedded strings
3. **Granular control**: Enable/disable individual config files independently
4. **Easier overrides**: Set nested values directly via `--set`
5. **Cleaner charts**: Downstream charts just call the library template

## Troubleshooting

### Chart fails to install after upgrade

**Symptom**: `Error: template: ...`

**Solution**: 
1. Check your values.yaml uses the new structure
2. Rebuild Helm dependencies: `helm dependency build`
3. Verify library version is >= 2026.01.1

### ConfigMap not being created

**Symptom**: No ConfigMap in `kubectl get cm`

**Solution**:
- Ensure at least one config group has `enabled: true`
- Check the library template is being called: `{{ include "game-server.configmap" . }}`

### Config files not mounting

**Symptom**: Pod running but config file missing inside container

**Solution**:
- Verify `mountPath` is correct for each config group
- Check logs: `kubectl logs <pod>`
- Verify the generated ConfigMap has the expected keys: `kubectl describe cm <name>-config`

### Wrong filename generated

**Symptom**: File is named `server-settings.json` but you expected `serverSettings.json`

**Solution**:
- The key name under `gameConfig` becomes the filename (with extension from `configFormat`)
- Use hyphenated keys to match expected filenames: `server-settings` → `server-settings.json`
- Or use `file` and the key name as-is for the filename

## Need Help?

- **Examples**: See the updated [factorio chart](../charts/factorio)
- **Library docs**: [game-server-library README](../charts/game-server-library/README.md)
- **Questions**: Open a GitHub Discussion
