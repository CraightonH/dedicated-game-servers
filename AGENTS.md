# Agent Instructions

This document provides instructions for AI agents working in this repository.

## Repository Purpose

A simplified Helm chart for deploying dedicated game servers on Kubernetes. Replaces an over-engineered operator (boilerr) with a straightforward Helm-based approach.

**Core principle:** Deployment simplicity over lifecycle automation.

## Repository Structure

```
dedicated-game-servers/
├── charts/                         # Helm charts
│   ├── game-server-library/       # Library chart (shared templates)
│   │   ├── Chart.yaml             # Library chart metadata (type: library)
│   │   ├── values.yaml            # Default values
│   │   └── templates/             # Named templates
│   │       ├── _deployment.tpl    # Deployment template
│   │       ├── _service.tpl       # Service template
│   │       ├── _pvc.tpl          # PVC template
│   │       └── _configmap.tpl    # ConfigMap template
│   └── <game-name>/               # Game-specific chart
│       ├── Chart.yaml             # Chart metadata + library dependency
│       ├── values.yaml            # Game-specific defaults
│       ├── templates/             # Template includes
│       │   ├── deployment.yaml    # Include library deployment
│       │   ├── service.yaml       # Include library service
│       │   ├── pvc.yaml          # Include library PVC
│       │   └── NOTES.txt         # Game-specific instructions
│       ├── README.md              # Game documentation
│       └── test.sh                # Automated validation
├── docs/                          # Documentation
│   ├── architecture-refactor-plan.md  # Architecture design
│   ├── creating-new-game-chart.md     # Contributor guide
│   └── VERSIONING.md              # CalVer versioning scheme
└── .github/workflows/             # CI/CD
    ├── helm-lint.yaml            # Syntax validation
    ├── helm-publish.yaml         # Publish to GitHub Pages
    └── test-games.yaml           # Deployment testing
```

## Adding a New Game Chart

**See [docs/creating-new-game-chart.md](docs/creating-new-game-chart.md) for the comprehensive guide.**

### Quick Overview

### 1. Create Chart Directory

```bash
mkdir -p charts/<game-name>/templates
```

### 2. Create Chart.yaml

```yaml
apiVersion: v2
name: <game-name>
version: 2026.01.0  # CalVer format
description: <Game Name> dedicated server
type: application
dependencies:
  - name: game-server-library
    version: "^2026.1.0"
    repository: "file://../game-server-library"
```

### 3. Create values.yaml

**Required fields:**

```yaml
name: "<game-name>"                    # Kubernetes resource identifier
image:
  repository: "<docker-image>"          # Docker Hub image
  tag: "stable"                         # Or specific version
  pullPolicy: IfNotPresent

service:
  type: NodePort                        # Always use NodePort (home cluster)
  ports:
    - name: game
      port: <port-number>               # Game server port
      nodePort: <30000-32767>           # NodePort mapping
      protocol: UDP                     # or TCP

persistence:
  enabled: true
  storageClass: "nfs-client"            # Or cluster default
  size: "10Gi"
  mountPath: "/data"                    # Container path for save data

resources:
  requests:
    memory: "<amount>Gi"                # Minimum RAM
    cpu: "<amount>m"
  limits:
    memory: "<amount>Gi"                # Maximum RAM
    cpu: "<amount>m"

# If game needs config files:
gameConfig:
  enabled: true
  mountPath: "/path/in/container"
  files:
    config-file.json: |
      { "setting": "value" }

# Environment variables (if needed):
env:
  - name: ENV_VAR
    value: "value"

# Security context (match container's user):
securityContext:
  fsGroup: <gid>
  runAsUser: <uid>
  runAsNonRoot: true
```

**Research required:**
- Official Docker image name
- Typical resource requirements
- Required ports (UDP vs TCP)
- Config file format and location
- Container user/group IDs

### 3. Create README.md

**Required sections:**

```markdown
# <Game Name> Dedicated Server

## Quick Start
[Basic deployment command]

## Configuration Options

### Basic Settings
[Table of name, image settings]

### Server Settings
[Table of game-specific settings from values.yaml]

### Network Configuration
[Ports, NodePort mappings]

### Resources
[Memory/CPU recommendations]

### Storage
[PVC settings]

## Customization Examples
[2-3 common use cases]

## Connecting to Your Server
[How players join - IP, port, etc.]

## Managing the Server
[View logs, backup saves, etc.]

## Troubleshooting
[Common issues and solutions]

## References
- [Docker Image]
- [Game Server Documentation]
```

### 4. Create test.sh (Recommended)

**Template:**

```bash
#!/bin/bash
# <Game Name> deployment validation test
set -e

POD=$(kubectl get pod -l app=<game-name> -o jsonpath='{.items[0].metadata.name}')

echo "🔍 Validating <game-name> server deployment..."

# Wait for pod ready
kubectl wait --for=condition=ready pod -l app=<game-name> --timeout=300s

# Check logs for game-specific success messages
LOGS=$(kubectl logs $POD --tail=100)
if echo "$LOGS" | grep -q "<SUCCESS_PATTERN>"; then
    echo "✅ Server started successfully"
else
    echo "❌ Server did not start"
    echo "$LOGS"
    exit 1
fi

# Verify config files (if using gameConfig)
if kubectl exec $POD -- test -f /path/to/config.json; then
    echo "✅ Config file exists"
else
    echo "❌ Config file not found"
    exit 1
fi

# Check PVC
PVC=$(kubectl get pvc <game-name>-data -o jsonpath='{.status.phase}')
if [ "$PVC" == "Bound" ]; then
    echo "✅ PVC is bound"
else
    echo "❌ PVC is not bound: $PVC"
    exit 1
fi

# Verify service
SVC=$(kubectl get svc <game-name> -o jsonpath='{.spec.type}')
if [ "$SVC" == "NodePort" ]; then
    echo "✅ Service is NodePort"
else
    echo "❌ Service type is not NodePort: $SVC"
    exit 1
fi

echo "✅ All validation checks passed!"
```

**Make it executable:**
```bash
chmod +x charts/<game-name>/test.sh
```

### 4. Create Template Files

Each template includes the library chart named template:

**charts/<game-name>/templates/deployment.yaml**:
```yaml
{{- include "game-server.deployment" . -}}
```

**charts/<game-name>/templates/service.yaml**:
```yaml
{{- include "game-server.service" . -}}
```

**charts/<game-name>/templates/pvc.yaml**:
```yaml
{{- include "game-server.pvc" . -}}
```

### 5. Test Locally

```bash
# Build chart dependencies
cd charts/<game-name>
helm dependency build
cd ../..

# Create test cluster
kind create cluster --name test

# Deploy your game chart
helm install <game-name>-test ./charts/<game-name>

# Verify it works
kubectl get pods -l app=<game-name>
kubectl logs -l app=<game-name>

# Run validation
./charts/<game-name>/test.sh

# Cleanup
helm uninstall <game-name>-test
kind delete cluster --name test
```

## CI/CD Behavior

**Auto-discovery:**
- Workflows automatically detect games with `test.sh` files
- Tests run only when relevant files change
- No workflow modifications needed for new games

**On PR:**
1. Helm lint validates syntax
2. Deployment test runs (if game has test.sh)
3. Game-specific validation runs
4. Results reported in PR

**Path filtering:**
- Changes to `charts/game-server-library/**` trigger tests for all game charts
- Changes to `charts/<game>/**` trigger tests for only that game chart

## Git Workflow

**Branch naming:**
- `feat/add-<game-name>` for new games
- `fix/<game-name>-<issue>` for bug fixes
- `docs/<game-name>-<change>` for documentation

**Commits:**
- Use conventional commit format: `feat:`, `fix:`, `docs:`, etc.
- Be specific: `feat(factorio): add server settings`

**PRs:**
- One game per PR (unless changes affect multiple)
- Include test.sh if possible
- Update README with configuration tables

## Common Patterns

### ConfigMap Generation

Use `gameConfig` to generate config files from Helm values:

```yaml
gameConfig:
  enabled: true
  mountPath: "/game/config"
  files:
    server.json: |
      {
        "serverName": "{{ .Values.serverName }}",
        "maxPlayers": {{ .Values.maxPlayers }}
      }
```

The chart will create a ConfigMap and mount files at the specified path.

### NodePort Selection

- Use ports 30000-32767
- Avoid conflicts with existing games
- Document the port in README

### Resource Sizing

**Guidelines:**
- Small games (2-4 players): 1-2Gi RAM, 500-1000m CPU
- Medium games (5-10 players): 2-4Gi RAM, 1000-2000m CPU
- Large games (10+ players): 4-8Gi RAM, 2000-4000m CPU

Set requests at ~50% of limits for overcommit.

### Storage Sizing

- Factorio: 10Gi (large factories)
- Valheim: 5-10Gi (world size)
- Most games: 5-10Gi default

Use `nfs-client` storage class by default (matches repo owner's cluster).

## Debugging Failed Workflows

**If test-games.yaml fails:**

1. Check the "Detect changed games" step output
2. Verify game has `test.sh` and it's executable
3. Look at pod logs in "Get pod logs on failure" step
4. Test locally with kind cluster

**Common issues:**
- Missing `test.sh` executable bit
- Invalid YAML in values.yaml
- Wrong success pattern in test.sh
- Container crashes before readiness

## Documentation Standards

**README tables:**
- Use Markdown tables for configuration options
- Include description and default value
- Link to external documentation

**Code comments:**
- Explain non-obvious values.yaml settings
- Document required vs optional fields

**Examples:**
- Provide 2-3 common customization examples
- Show real-world use cases (passwords, player limits, etc.)

## Testing Standards

**Test script requirements:**
- Exit with non-zero on failure
- Check pod readiness
- Validate config file generation
- Verify PVC and service
- Parse logs for success indicators

**Don't test:**
- Actual game functionality (connecting clients)
- Long-running operations (>5 minutes)
- External services (authentication, etc.)

## Security Considerations

**Never commit:**
- Passwords in values.yaml (use placeholders)
- API keys or tokens
- Personal server names (use generic defaults)

**Security context:**
- Always set `runAsNonRoot: true`
- Match container's UID/GID
- Don't use root unless absolutely required

## Questions?

When uncertain:
1. Check existing game implementations (factorio is the reference)
2. Review CONTRIBUTING.md for contributor guidance
3. Test locally before submitting PR
4. Ask in PR comments if something is unclear

## Key Principles

1. **Simplicity over features** - This repo chose Helm over operators for a reason
2. **Self-contained games** - Each game folder has everything it needs
3. **NodePort by default** - Home cluster assumption
4. **Test everything** - If it has a test.sh, it gets tested automatically
5. **Document thoroughly** - README tables should answer most questions
