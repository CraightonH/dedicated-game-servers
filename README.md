# Dedicated Game Servers

Simple Helm charts for deploying dedicated game servers on Kubernetes.

## Overview

This repository provides a collection of Helm charts for easily deploying game servers on Kubernetes using a shared library chart architecture.

**Design philosophy**: Deployment simplicity over lifecycle automation.

## Supported Games

| Game | Chart | Description |
|------|-------|-------------|
| **Factorio** | `dedicated-game-servers/factorio` | Factory building and automation |
| Valheim | _coming soon_ | Viking survival |
| Satisfactory | _coming soon_ | Factory building in 3D |

## Quick Start

### Add the Helm Repository

```bash
helm repo add dedicated-game-servers https://craightonh.github.io/dedicated-game-servers/
helm repo update
```

### Browse Available Games

```bash
helm search repo dedicated-game-servers
```

### Install a Game Server

#### Factorio

```bash
# Basic installation (works out of the box)
helm install factorio dedicated-game-servers/factorio

# With custom server name
helm install factorio dedicated-game-servers/factorio \
  --set gameConfig.files.server-settings\.json.name="My Factory"

# With custom values file
helm install factorio dedicated-game-servers/factorio -f my-values.yaml
```

See [charts/factorio/README.md](./charts/factorio/README.md) for full configuration options.

## Architecture

This repository uses a **library chart + per-game chart** architecture:

```
dedicated-game-servers/
├── charts/
│   ├── game-server-library/     # Shared templates (Deployment, Service, PVC, etc.)
│   │   ├── Chart.yaml           # type: library
│   │   └── templates/           # Reusable named templates
│   ├── factorio/                # Factorio-specific chart
│   │   ├── Chart.yaml           # depends: game-server-library
│   │   ├── values.yaml          # Factorio defaults
│   │   └── templates/           # Uses library templates
│   └── <game>/                  # Additional game charts
└── docs/                        # Documentation
```

**Benefits**:
- **Simple deployment**: `helm install factorio dedicated-game-servers/factorio` just works
- **Discoverable**: `helm search` shows all available games
- **Maintainable**: Common logic lives in the library chart
- **Independent versioning**: Each game can release at its own pace

## How It Works

Each game chart uses the [game-server-library](./charts/game-server-library) to deploy:
- **Deployment**: Single replica with Recreate strategy (game servers can't be scaled)
- **Service**: NodePort (for home clusters) or LoadBalancer
- **PersistentVolumeClaim**: For save data and game files
- **ConfigMap**: For game-specific configuration files

The library chart provides reusable templates, and each game chart provides sensible defaults.

## Configuration

### Per-Game Documentation

See individual game chart READMEs for detailed configuration:
- [Factorio](./charts/factorio/README.md)

### Common Patterns

All game charts support these common options:

```yaml
# Kubernetes resource name
name: my-server

# Docker image
image:
  repository: <game-image>
  tag: stable
  pullPolicy: IfNotPresent

# Service configuration
service:
  type: NodePort  # or LoadBalancer, ClusterIP
  ports:
    - name: game
      port: <game-port>
      nodePort: 30000  # 30000-32767 for NodePort
      protocol: UDP    # or TCP

# Persistent storage
persistence:
  enabled: true
  size: 10Gi
  storageClass: nfs-client  # or your cluster's storage class
  mountPath: /data

# Resources
resources:
  requests:
    memory: 2Gi
    cpu: 1000m
  limits:
    memory: 4Gi
    cpu: 2000m

# Security context
podSecurityContext:
  fsGroup: 1000
containerSecurityContext:
  runAsUser: 1000
  runAsNonRoot: true

# Game configuration files (optional)
gameConfig:
  enabled: true
  mountPath: /game/config
  files:
    config.json: |
      { "setting": "value" }

# Environment variables (optional)
env:
  - name: ENV_VAR
    value: "value"
```

## CI/CD & Testing

This repository includes automated testing:
- **Helm Lint**: Validates chart syntax
- **Deployment Tests**: Deploys charts to kind cluster
- **Game Validation**: Runs game-specific health checks

Tests run automatically on PRs for changed games.

## Why Not an Operator?

This project was originally a Kubernetes operator ([boilerr](https://github.com/CraightonH/boilerr)) but was simplified to Helm charts because:

- Primary need was **deployment**, not complex lifecycle management
- Helm charts are simpler to maintain and understand
- Adding new games is trivial (create a new chart directory)
- Advanced automation features (auto-updates, backups) were low priority

If you need advanced lifecycle management, check out [boilerr](https://github.com/CraightonH/boilerr).

## Contributing

We welcome contributions! See [CONTRIBUTING.md](./CONTRIBUTING.md) for how to:
- Add a new game chart
- Improve existing charts
- Submit pull requests

For detailed guidance on creating game charts, see [docs/creating-new-game-chart.md](./docs/creating-new-game-chart.md).

## Versioning

This repository uses **Calendar Versioning (CalVer)** for chart versions. See [docs/VERSIONING.md](./docs/VERSIONING.md) for details.

## License

MIT
