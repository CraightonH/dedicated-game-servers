# Game Server Library Chart

A Helm library chart providing common templates for game server deployments.

**Versioning**: This chart uses [Calendar Versioning (CalVer)](../../docs/VERSIONING.md) with the format `YYYY.MM.MICRO`.

## What is a Library Chart?

A library chart is a type of Helm chart that defines chart primitives or definitions which can be shared by other charts but does not create any resource instances itself. Library charts do not contain a `templates/` directory with Kubernetes resource manifests, but instead contain named templates that can be included by other charts.

## Purpose

This library chart provides reusable templates for common game server resources:
- **Deployment**: Standard game server deployment with support for init containers, security contexts, and volumes
- **Service**: NodePort/ClusterIP/LoadBalancer service configuration
- **PersistentVolumeClaim**: Storage for game data
- **ConfigMap**: Game configuration files

## Usage

### As a Dependency

Add this library chart as a dependency in your game-specific chart:

```yaml
# Chart.yaml
apiVersion: v2
name: my-game
version: 1.0.0
dependencies:
  - name: game-server-library
    version: "^1.0.0"
    repository: "https://craightonh.github.io/dedicated-game-servers/"
```

Then run:
```bash
helm dependency build
```

### Including Templates

In your game chart's templates, include the library templates:

**templates/deployment.yaml:**
```yaml
{{ include "game-server.deployment" . }}
```

**templates/service.yaml:**
```yaml
{{ include "game-server.service" . }}
```

**templates/pvc.yaml:**
```yaml
{{ include "game-server.pvc" . }}
```

**templates/configmap.yaml:**
```yaml
{{ include "game-server.configmap" . }}
```

## Available Templates

### `game-server.deployment`
Creates a Deployment for the game server.

**Features:**
- Single replica with Recreate strategy
- Support for init containers
- Support for pod and container security contexts
- Automatic config checksum annotation (for restarts on config changes)
- Volume mounts for data and config

### `game-server.service`
Creates a Service for the game server.

**Features:**
- Configurable service type (NodePort, ClusterIP, LoadBalancer)
- Support for multiple ports (TCP/UDP)
- Optional NodePort assignment

### `game-server.pvc`
Creates a PersistentVolumeClaim for game data.

**Features:**
- ReadWriteOnce access mode
- Configurable storage class
- Configurable size

### `game-server.configmap`
Creates a ConfigMap for game configuration files.

**Features:**
- Support for multiple config groups with arbitrary keys
- Each config group can be enabled/disabled independently
- Automatic file generation from `config` values in JSON or YAML format
- Optional direct file override via `file` key
- Automatic mounting at specified paths in the deployment

**Config Group Structure:**
Each key under `gameConfig` represents a config group and will generate a file:
- If `configFormat: json`, generates `<key>.json`
- If `configFormat: yaml`, generates `<key>.yaml`
- If `file` is provided, uses the key name as-is for the filename

**Example:**
```yaml
gameConfig:
  server-settings:
    enabled: true
    mountPath: /game/config
    configFormat: json
    config:
      name: "My Server"
      max_players: 10
  # Generates: server-settings.json mounted at /game/config/server-settings.json
```

### `game-server.env`
Processes environment variables for the container.

**Features:**
- Supports both map format (human-friendly) and list format (Kubernetes native)
- Automatic conversion of map to Kubernetes list format
- Support for `value` and `valueFrom` (secrets, configMaps)
- Type conversion for numbers and booleans

**Map Format (Recommended):**
```yaml
env:
  SERVER_NAME: "My Server"
  MAX_PLAYERS: 10
  ENABLE_PVP: true
```

To override values:
```bash
--set env.SERVER_NAME="New Name"
--set env.MAX_PLAYERS=20
```

**List Format (Also Supported):**
```yaml
env:
  - name: SERVER_NAME
    value: "My Server"
  - name: MAX_PLAYERS
    value: "10"
```

To override values (requires knowing array index):
```bash
--set env[0].value="New Name"
--set env[1].value="20"
```

**Advanced Usage with valueFrom:**
```yaml
env:
  SERVER_NAME: "My Server"
  ADMIN_PASSWORD:
    valueFrom:
      secretKeyRef:
        name: game-secrets
        key: password
```

## Helper Functions

The library also provides common helper functions:

- `game-server.name`: Get the name of the chart
- `game-server.fullname`: Get the full qualified app name
- `game-server.chart`: Get chart name and version
- `game-server.labels`: Get common labels
- `game-server.selectorLabels`: Get selector labels
- `game-server.serviceAccountName`: Get service account name

## Values Structure

See `values.yaml` for the complete values structure. Key sections:

```yaml
name: my-game-server

image:
  repository: example/game-server
  tag: latest

service:
  type: NodePort
  ports:
    - name: game
      port: 25565
      nodePort: 30565
      protocol: TCP

persistence:
  enabled: true
  storageClass: nfs-client
  size: 50Gi
  mountPath: /data

# Environment variables (map format - human friendly)
env:
  SERVER_NAME: "My Server"
  MAX_PLAYERS: "10"
  SERVER_PORT: 25565
  # Advanced: Use valueFrom for secrets
  ADMIN_PASSWORD:
    valueFrom:
      secretKeyRef:
        name: game-secrets
        key: admin-password

# Also supports list format (Kubernetes native)
# env:
#   - name: SERVER_NAME
#     value: "My Server"
#   - name: MAX_PLAYERS
#     value: "10"

gameConfig:
  # Each key represents a config group (e.g., serverSettings, adminList)
  server-properties:
    enabled: true
    mountPath: /config
    configFormat: yaml  # or json
    config:
      server-port: 25565
      motd: "Welcome!"
  # Optional: Direct file override
  admin-list:
    enabled: true
    mountPath: /config
    file: |
      admin1
      admin2
```

## Example Game Chart

See the `factorio` chart in this repository for a complete example of using this library chart.

## Contributing

When adding new common functionality:
1. Add the named template to the appropriate `_*.tpl` file
2. Document it in this README
3. Add sensible defaults to `values.yaml`
4. Test with at least one game chart

## License

MIT
