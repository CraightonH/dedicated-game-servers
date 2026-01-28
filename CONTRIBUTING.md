# Contributing to Dedicated Game Servers

Thanks for your interest in contributing! This guide will help you add new game charts or improve existing ones.

## Quick Links

- **Detailed guide**: See [docs/creating-new-game-chart.md](./docs/creating-new-game-chart.md) for step-by-step instructions
- **Example**: Check [charts/factorio](./charts/factorio) as a reference implementation
- **Architecture**: Review [docs/architecture-refactor-plan.md](./docs/architecture-refactor-plan.md) for design details

## Adding a New Game Chart

### High-Level Process

1. **Create chart directory**: `charts/<game-name>/`
2. **Set up Chart.yaml**: Define dependency on `game-server-library`
3. **Create values.yaml**: Game-specific defaults and configuration
4. **Create templates**: Use library chart named templates
5. **Write README.md**: Document configuration options
6. **Add test script**: `test.sh` for automated validation
7. **Test locally**: Deploy with kind cluster
8. **Submit PR**: Automated CI will validate

### Minimal Example

#### 1. Create Chart Directory

```bash
mkdir -p charts/<game-name>/templates
```

#### 2. Create `Chart.yaml`

```yaml
apiVersion: v2
name: <game-name>
version: 2026.01.0  # CalVer: YYYY.MM.MICRO
description: <Game Name> dedicated server
type: application
dependencies:
  - name: game-server-library
    version: "^2026.01.1"  # Use semver range
    repository: "file://../game-server-library"
```

#### 3. Create `values.yaml`

```yaml
# Unique deployment name
name: <game-name>

# Docker image
image:
  repository: <docker-hub-image>
  tag: stable
  pullPolicy: IfNotPresent

# Service configuration (NodePort for home clusters)
service:
  type: NodePort
  ports:
    - name: game
      port: <game-port>
      nodePort: <30000-32767>  # Pick unused port
      protocol: UDP  # or TCP

# Persistent storage
persistence:
  enabled: true
  storageClass: nfs-client  # Or leave empty for cluster default
  size: 10Gi
  mountPath: /data  # Where game saves data

# Security context (match container's UID/GID)
podSecurityContext:
  fsGroup: 1000
containerSecurityContext:
  runAsUser: 1000
  runAsNonRoot: true

# Resources (adjust based on game requirements)
resources:
  requests:
    memory: 2Gi
    cpu: 1000m
  limits:
    memory: 4Gi
    cpu: 2000m

# Game configuration files (if needed)
gameConfig:
  server-config:
    enabled: true
    mountPath: /game/config
    configFormat: json
    config:
      serverName: "My Server"
      maxPlayers: 10

# Environment variables (if needed)
env:
  - name: SERVER_NAME
    value: "My Server"
```

#### 4. Create Templates

Each template should include the corresponding library chart named template.

**`templates/deployment.yaml`**:
```yaml
{{- include "game-server.deployment" . -}}
```

**`templates/service.yaml`**:
```yaml
{{- include "game-server.service" . -}}
```

**`templates/pvc.yaml`**:
```yaml
{{- include "game-server.pvc" . -}}
```

**`templates/configmap-game-config.yaml`** (if using gameConfig):
```yaml
{{- include "game-server.configmap-game-config" . -}}
```

**`templates/NOTES.txt`** (game-specific connection instructions):
```txt
Congratulations! You've deployed a <Game Name> server.

Connection information:
{{- if eq .Values.service.type "NodePort" }}
  Get the node IP:
  kubectl get nodes -o wide
  
  Connect to: <node-ip>:{{ (index .Values.service.ports 0).nodePort }}
{{- else if eq .Values.service.type "LoadBalancer" }}
  Get the external IP:
  kubectl get svc {{ .Values.name }}
  
  Connect to: <external-ip>:{{ (index .Values.service.ports 0).port }}
{{- end }}

View logs:
  kubectl logs -f -l app={{ .Values.name }}

Backup saves:
  POD=$(kubectl get pod -l app={{ .Values.name }} -o jsonpath='{.items[0].metadata.name}')
  kubectl cp $POD:{{ .Values.persistence.mountPath }}/saves ./backup
```

#### 5. Create `README.md`

See [charts/factorio/README.md](./charts/factorio/README.md) as a template. Include:

- **TL;DR**: One-liner installation command
- **Introduction**: Brief description
- **Prerequisites**: Kubernetes/Helm versions, storage requirements
- **Installation**: Basic and customized examples
- **Configuration**: Table of all values
- **Connecting**: How players join
- **Managing**: Logs, backups, RCON (if applicable)
- **Troubleshooting**: Common issues
- **References**: Links to Docker image, game docs, library chart

#### 6. Create `test.sh`

**Important**: Wait for game-specific startup messages to confirm the server is actually running, not just that the pod is ready.

**Example: Factorio-style test with explicit startup detection**

```bash
#!/bin/bash
# <Game Name> deployment validation test
set -e

echo "🔍 Validating <game-name> server deployment..."

# Wait for pod ready
echo "⏳ Waiting for pod readiness..."
kubectl wait --for=condition=ready pod -l app=<game-name> --timeout=300s

# Get pod name
POD=$(kubectl get pod -l app=<game-name> -o jsonpath='{.items[0].metadata.name}')
echo "✅ Pod is ready: $POD"

# Wait up to 30 seconds for game-specific startup message
# CRITICAL: Replace <SUCCESS_MESSAGE> with the actual message your game logs
# Examples:
#   Factorio: "Hosting game at IP ADDR"
#   Valheim: "Game server connected"
#   Satisfactory: "Server is ready"
echo "📋 Waiting for <game-name> server to start (up to 30 seconds)..."
SUCCESS=false
for i in {1..30}; do
    # Get recent logs
    LOGS=$(kubectl logs $POD --tail=50 2>/dev/null || echo "")
    
    # Check for game-specific success message
    if echo "$LOGS" | grep -q "<SUCCESS_MESSAGE>"; then
        echo "✅ Found '<SUCCESS_MESSAGE>' in logs"
        SUCCESS=true
        break
    fi
    
    # Check if pod is still running
    POD_PHASE=$(kubectl get pod $POD -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [ "$POD_PHASE" != "Running" ]; then
        echo "❌ Pod is no longer running (phase: $POD_PHASE)"
        echo "Recent logs:"
        echo "$LOGS"
        exit 1
    fi
    
    # Wait 1 second before next check
    sleep 1
done

# Check if we found the success message
if [ "$SUCCESS" = false ]; then
    echo "❌ Server did not start within 30 seconds"
    echo "Recent logs:"
    kubectl logs $POD --tail=100
    exit 1
fi

# Verify pod is still running after finding the message
POD_PHASE=$(kubectl get pod $POD -o jsonpath='{.status.phase}')
if [ "$POD_PHASE" != "Running" ]; then
    echo "❌ Pod stopped running after startup (phase: $POD_PHASE)"
    exit 1
fi

echo "✅ Server started successfully and is still running"

# Verify config file (if using gameConfig)
if kubectl exec $POD -- test -f /game/config/config.json 2>/dev/null; then
    echo "✅ Config file mounted"
else
    echo "⚠️  Config file not found (may be expected if gameConfig disabled)"
fi

# Check PVC
PVC_NAME="<game-name>-data"
PVC_STATUS=$(kubectl get pvc $PVC_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "$PVC_STATUS" == "Bound" ]; then
    echo "✅ PVC is bound: $PVC_NAME"
else
    echo "❌ PVC not bound: $PVC_STATUS"
    exit 1
fi

# Verify service
SVC_TYPE=$(kubectl get svc <game-name> -o jsonpath='{.spec.type}')
if [ "$SVC_TYPE" == "NodePort" ]; then
    echo "✅ Service is NodePort"
else
    echo "⚠️  Service type is $SVC_TYPE (expected NodePort for tests)"
fi

echo "✅ All validation checks passed!"
```

**How to find the success message for your game:**

1. Deploy the server manually:
   ```bash
   helm install test ./charts/<game-name>
   ```

2. Watch the logs until the server is ready:
   ```bash
   kubectl logs -f -l app=<game-name>
   ```

3. Look for a message that indicates the server is accepting connections
   - Examples:
     - Factorio: `Hosting game at IP ADDR`
     - Valheim: `Game server connected`
     - Minecraft: `Done (X.XXXs)! For help, type "help"`
     - 7 Days to Die: `GameServer.Init successful`

4. Use that exact string in the `grep -q "<SUCCESS_MESSAGE>"` line

**Why this matters:**
- Pod readiness ≠ server ready
- Many game servers take 10-30 seconds to initialize after the pod is ready
- Testing must wait for the actual server to start, not just the container

Make it executable:
```bash
chmod +x charts/<game-name>/test.sh
```

### Testing Locally

```bash
# Create test cluster
kind create cluster --name game-test

# Build chart dependencies
cd charts/<game-name>
helm dependency build
cd ../..

# Install chart
helm install <game-name>-test charts/<game-name>

# Run validation
charts/<game-name>/test.sh

# Check pod/logs
kubectl get pods -l app=<game-name>
kubectl logs -l app=<game-name>

# Cleanup
helm uninstall <game-name>-test
kind delete cluster --name game-test
```

### Submitting a PR

```bash
# Create feature branch
git checkout -b feat/add-<game-name>

# Add your chart
git add charts/<game-name>/

# Commit with conventional commit format
git commit -m "feat: add <game-name> Helm chart"

# Push branch
git push -u origin feat/add-<game-name>
```

Then open a PR on GitHub. CI will automatically:
- Lint your chart syntax
- Build dependencies
- Deploy to kind cluster
- Run your test.sh validation
- Report results

## Improving Existing Charts

To modify an existing game chart:

1. Create a feature branch: `git checkout -b fix/<game-name>-<issue>`
2. Make changes to `charts/<game-name>/`
3. Test locally (see above)
4. Update chart version in `Chart.yaml` (bump MICRO for patches, MM for features)
5. Update README if configuration changed
6. Submit PR

## Improving the Library Chart

The [game-server-library](./charts/game-server-library) provides shared templates.

**When to modify the library**:
- Adding a new common resource type (e.g., Ingress)
- Fixing bugs in existing templates
- Improving template flexibility

**Steps**:
1. Update templates in `charts/game-server-library/templates/`
2. Bump library chart version in `charts/game-server-library/Chart.yaml`
3. Test with at least one game chart
4. Update game charts that need the new library version
5. Submit PR

**Note**: Library changes may affect all game charts, so test thoroughly.

## CI/CD Workflow

### Automated Tests

All PRs automatically run:
- **Helm Lint**: Validates chart syntax
- **Dependency Build**: Ensures library chart is available
- **Deployment Test**: Deploys to kind cluster
- **Game Validation**: Runs `test.sh` if it exists

### Path-Based Testing

CI only tests charts that changed:
- Changes to `charts/<game>/**` → test that game
- Changes to `charts/game-server-library/**` → test all games
- Changes to `docs/**` → skip tests

## Git Workflow

### Branch Naming

- `feat/add-<game>` - New game chart
- `fix/<game>-<issue>` - Bug fix for existing game
- `docs/<game>-<change>` - Documentation updates
- `chore/library-<change>` - Library chart updates

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat(<game>): add new game chart`
- `fix(<game>): correct port mapping`
- `docs(<game>): improve README examples`
- `chore(library): update Deployment template`

## Documentation Standards

### README Structure

Required sections:
1. **TL;DR** - One-command installation
2. **Introduction** - Brief description
3. **Prerequisites** - Requirements
4. **Installing the Chart** - Multiple examples
5. **Uninstalling** - How to clean up
6. **Configuration** - Values table
7. **Connecting** - How to join the server
8. **Managing** - Common tasks (logs, backups)
9. **Troubleshooting** - Common issues
10. **References** - External links

### Configuration Tables

Use Markdown tables with these columns:
- **Parameter**: YAML path (e.g., `service.type`)
- **Description**: What it does
- **Default**: Default value

Example:
```markdown
| Parameter | Description | Default |
|-----------|-------------|---------|
| `name` | Server name | `factorio` |
| `image.repository` | Docker image | `factoriotools/factorio` |
```

## Common Pitfalls

### Port Conflicts

Check that your chosen NodePort (30000-32767) doesn't conflict with existing games:
- Factorio: 30197 (game), 30015 (RCON)

### UID/GID Mismatch

Ensure `podSecurityContext.fsGroup` and `containerSecurityContext.runAsUser` match the Docker image's user.

### Resource Limits

Game servers can be resource-intensive. Set realistic limits:
- **Small** (2-4 players): 1-2Gi RAM, 500-1000m CPU
- **Medium** (5-10 players): 2-4Gi RAM, 1000-2000m CPU
- **Large** (10+ players): 4-8Gi RAM, 2000-4000m CPU

### Test Success Patterns

Choose a log message that reliably indicates the server started. Avoid:
- Messages that appear before the server is ready
- Messages that might not always appear
- Messages that are too generic

## Questions?

- **Detailed guide**: See [docs/creating-new-game-chart.md](./docs/creating-new-game-chart.md)
- **Issues**: Open a GitHub issue
- **Discussions**: Use GitHub Discussions for questions

## License

By contributing, you agree your contributions will be licensed under the MIT License.
