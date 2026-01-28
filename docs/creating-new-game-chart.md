# Creating a New Game Chart

This guide walks you through creating a Helm chart for a new game server using the game-server-library.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Research Phase](#research-phase)
3. [Chart Structure](#chart-structure)
4. [Step-by-Step Guide](#step-by-step-guide)
5. [Testing](#testing)
6. [Documentation](#documentation)
7. [Submission](#submission)

## Prerequisites

**Knowledge**:
- Basic Helm chart concepts
- Kubernetes resources (Deployment, Service, PVC)
- YAML syntax
- The game you're adding (installation, configuration)

**Tools**:
- Helm 3.0+
- kubectl
- kind (for local testing)
- Git

**Repository**:
```bash
git clone https://github.com/CraightonH/dedicated-game-servers.git
cd dedicated-game-servers
```

## Research Phase

Before creating the chart, gather information about the game server:

### 1. Find the Docker Image

Search Docker Hub for official or community-maintained images:
- **Factorio**: `factoriotools/factorio`
- **Valheim**: `lloesche/valheim-server`

Verify:
- Image is maintained (recent updates)
- Documentation exists
- Tags are semantic (e.g., `stable`, version numbers)

### 2. Identify Required Ports

Determine which ports the game uses and their protocols:

```markdown
| Port | Protocol | Purpose |
|------|----------|---------|
| 2456 | UDP | Game traffic |
| 2457 | UDP | Query |
```

### 3. Understand Configuration

How does the server configure itself?
- **Config files**: What format? Where mounted?
- **Environment variables**: Which ones are required/optional?
- **Command-line arguments**: Does the container accept them?

### 4. Determine Resource Requirements

Check the Docker image documentation or community forums:
- Minimum RAM
- Typical CPU usage
- Storage needs (save file sizes)

### 5. Find the Container User

Run the container locally to check:
```bash
docker run --rm <image> id
# Output: uid=1000(user) gid=1000(user) groups=1000(user)
```

This informs `securityContext` values.

## Chart Structure

```
charts/<game-name>/
├── Chart.yaml              # Chart metadata + library dependency
├── values.yaml             # Game-specific defaults
├── templates/
│   ├── deployment.yaml     # {{ include "game-server.deployment" . }}
│   ├── service.yaml        # {{ include "game-server.service" . }}
│   ├── pvc.yaml            # {{ include "game-server.pvc" . }}
│   ├── configmap-game-config.yaml  # (if needed)
│   ├── _helpers.tpl        # (optional) Game-specific helpers
│   └── NOTES.txt           # Post-install instructions
├── README.md               # Documentation
└── test.sh                 # Automated validation
```

## Step-by-Step Guide

### Step 1: Create Chart Directory

```bash
mkdir -p charts/<game-name>/templates
cd charts/<game-name>
```

### Step 2: Create `Chart.yaml`

```yaml
apiVersion: v2
name: <game-name>
version: 2026.01.0  # CalVer: YYYY.MM.MICRO
description: <Game Name> dedicated server Helm chart
type: application
keywords:
  - game-server
  - <game-name>
home: https://github.com/CraightonH/dedicated-game-servers
sources:
  - https://github.com/CraightonH/dedicated-game-servers
maintainers:
  - name: CraightonH
    url: https://github.com/CraightonH
dependencies:
  - name: game-server-library
    version: "^2026.1.0"
    repository: "file://../game-server-library"
```

**Notes**:
- Use CalVer versioning (see [VERSIONING.md](./VERSIONING.md))
- Update `sources` if the game has official repos
- Use semver range `^` for library dependency (allows patch/minor updates)

### Step 3: Create `values.yaml`

Start with sensible defaults that work out-of-the-box:

```yaml
# Deployment name (Kubernetes resource identifier)
name: <game-name>

# Docker image configuration
image:
  repository: <docker-hub-image>
  tag: stable  # or latest, or specific version
  pullPolicy: IfNotPresent

# Service configuration
service:
  type: NodePort  # Home cluster default
  ports:
    - name: game
      port: <game-port>        # Container port
      nodePort: <30000-32767>  # External port (pick unused)
      protocol: UDP            # or TCP

# Add more ports if needed:
#   - name: query
#     port: <query-port>
#     nodePort: <30000-32767>
#     protocol: UDP

# Persistent storage for save data
persistence:
  enabled: true
  storageClass: nfs-client  # Or "" for cluster default
  size: 10Gi  # Adjust based on game requirements
  mountPath: /data  # Where the container stores saves

# Security context (match container's UID/GID)
podSecurityContext:
  fsGroup: 1000  # From docker run <image> id

containerSecurityContext:
  runAsUser: 1000
  runAsNonRoot: true

# Resource requests and limits
resources:
  requests:
    memory: 2Gi    # Minimum RAM
    cpu: 1000m     # 1 CPU core
  limits:
    memory: 4Gi    # Maximum RAM
    cpu: 2000m     # 2 CPU cores

# Game-specific configuration files
# Only include if the game needs config files
gameConfig:
  enabled: true
  mountPath: /game/config  # Where to mount in container
  files:
    # Example: server config file
    server.json: |
      {
        "serverName": "My Server",
        "maxPlayers": 10,
        "password": "",
        "public": false
      }

# Environment variables (if the container uses them)
env: []
# Example:
# env:
#   - name: SERVER_NAME
#     value: "My Server"
#   - name: MAX_PLAYERS
#     value: "10"

# Node selector (optional - for advanced users)
nodeSelector: {}
# Example:
# nodeSelector:
#   kubernetes.io/hostname: server-node-1

# Tolerations (optional)
tolerations: []

# Affinity (optional)
affinity: {}
```

**Tips**:
- Choose a unique NodePort not used by other games
- Set realistic resource limits (check game forums/wikis)
- Provide working defaults (user can override with `--set`)

### Step 4: Create Template Files

Each template file includes a named template from the library chart.

#### `templates/deployment.yaml`

```yaml
{{- include "game-server.deployment" . -}}
```

#### `templates/service.yaml`

```yaml
{{- include "game-server.service" . -}}
```

#### `templates/pvc.yaml`

```yaml
{{- include "game-server.pvc" . -}}
```

#### `templates/configmap-game-config.yaml`

Only create this if you set `gameConfig.enabled: true` in values.yaml:

```yaml
{{- if .Values.gameConfig.enabled }}
{{- include "game-server.configmap-game-config" . -}}
{{- end }}
```

#### `templates/NOTES.txt`

Provide post-install instructions:

```txt
Congratulations! You've deployed a {{ .Chart.Name }} server.

{{- if eq .Values.service.type "NodePort" }}

Connection Information:
  1. Get a node IP:
       kubectl get nodes -o wide

  2. Connect to:
       <node-ip>:{{ (index .Values.service.ports 0).nodePort }}
{{- else if eq .Values.service.type "LoadBalancer" }}

Connection Information:
  1. Get the external IP:
       kubectl get svc {{ .Values.name }} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

  2. Connect to:
       <external-ip>:{{ (index .Values.service.ports 0).port }}
{{- end }}

Useful Commands:

  View logs:
    kubectl logs -f -l app={{ .Values.name }}

  Backup save data:
    POD=$(kubectl get pod -l app={{ .Values.name }} -o jsonpath='{.items[0].metadata.name}')
    kubectl cp $POD:{{ .Values.persistence.mountPath }}/saves ./backup

  Restart server:
    kubectl delete pod -l app={{ .Values.name }}

For more information, see the README:
  https://github.com/CraightonH/dedicated-game-servers/blob/main/charts/{{ .Chart.Name }}/README.md
```

#### `templates/_helpers.tpl` (Optional)

Only create this if you need game-specific helper functions. Most games won't need this.

Example (custom labels):
```yaml
{{/*
Custom labels for <game-name>
*/}}
{{- define "<game-name>.customLabels" -}}
game: {{ .Chart.Name }}
version: {{ .Values.image.tag }}
{{- end }}
```

### Step 5: Create `.helmignore`

```
# Ignore test script
test.sh
README.md
```

### Step 6: Build Dependencies

```bash
cd charts/<game-name>
helm dependency build
```

This downloads the game-server-library chart to `charts/` subdirectory.

### Step 7: Create `README.md`

See [Factorio README](../charts/factorio/README.md) as a template.

**Required sections**:

1. **Title**: `# <Game Name> Dedicated Server Helm Chart`
2. **TL;DR**: Quick install command
3. **Introduction**: What this chart does
4. **Prerequisites**: Kubernetes/Helm versions, storage class
5. **Installing the Chart**: Basic + customized examples
6. **Uninstalling**: How to remove
7. **Configuration**: Table of all values.yaml options
8. **Connecting to Your Server**: How players join
9. **Managing Your Server**: Logs, backups, restarts
10. **Troubleshooting**: Common problems
11. **Advanced Configuration**: Optional features
12. **Architecture**: Link to library chart
13. **References**: Docker image, game docs

**Configuration table format**:

```markdown
| Parameter | Description | Default |
|-----------|-------------|---------|
| `name` | Deployment name | `<game-name>` |
| `image.repository` | Docker image | `<image>` |
| `image.tag` | Image tag | `stable` |
| `service.type` | Service type | `NodePort` |
| `service.ports[0].nodePort` | External game port | `30XXX` |
| `persistence.size` | PVC size | `10Gi` |
| `gameConfig.files.<file>.serverName` | Server name | `My Server` |
```

### Step 8: Create `test.sh`

Automated validation script for CI:

```bash
#!/bin/bash
# <Game Name> deployment validation test
set -e

echo "🔍 Validating <game-name> server deployment..."

# 1. Wait for pod to be ready
echo "⏳ Waiting for pod readiness..."
kubectl wait --for=condition=ready pod -l app=<game-name> --timeout=300s

# Get pod name
POD=$(kubectl get pod -l app=<game-name> -o jsonpath='{.items[0].metadata.name}')
echo "✅ Pod is ready: $POD"

# 2. Check logs for success indicators
echo "📋 Checking server logs..."
LOGS=$(kubectl logs $POD --tail=100)

# Look for game-specific success message
# IMPORTANT: Research what log message indicates the server is ready
if echo "$LOGS" | grep -qi "server is ready\|listening on\|started successfully"; then
    echo "✅ Server started successfully"
else
    echo "❌ Server did not start properly"
    echo "Recent logs:"
    echo "$LOGS"
    exit 1
fi

# 3. Verify config file was mounted (if using gameConfig)
if kubectl exec $POD -- test -f /game/config/server.json 2>/dev/null; then
    echo "✅ Config file mounted correctly"
else
    echo "⚠️  Config file not found (may be expected if gameConfig disabled)"
fi

# 4. Check PVC is bound
PVC_NAME="<game-name>-data"
PVC_STATUS=$(kubectl get pvc $PVC_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "$PVC_STATUS" == "Bound" ]; then
    echo "✅ PVC is bound: $PVC_NAME"
else
    echo "❌ PVC not bound: $PVC_STATUS"
    kubectl get pvc $PVC_NAME || true
    exit 1
fi

# 5. Verify service
SVC_TYPE=$(kubectl get svc <game-name> -o jsonpath='{.spec.type}')
if [ "$SVC_TYPE" == "NodePort" ]; then
    NODE_PORT=$(kubectl get svc <game-name> -o jsonpath='{.spec.ports[0].nodePort}')
    echo "✅ Service is NodePort on port $NODE_PORT"
else
    echo "❌ Unexpected service type: $SVC_TYPE"
    exit 1
fi

# 6. Optional: Check container resources
REQUESTS_MEM=$(kubectl get pod $POD -o jsonpath='{.spec.containers[0].resources.requests.memory}')
LIMITS_MEM=$(kubectl get pod $POD -o jsonpath='{.spec.containers[0].resources.limits.memory}')
echo "ℹ️  Resources: requests=$REQUESTS_MEM, limits=$LIMITS_MEM"

echo "✅ All validation checks passed!"
```

**Important notes**:
- Replace `<game-name>` with your actual game name
- Research the correct log message for "server ready"
- Adjust file paths based on your `gameConfig.mountPath`
- Make the script executable: `chmod +x test.sh`

### Step 9: Test Locally

```bash
# Create a test Kubernetes cluster
kind create cluster --name <game-name>-test

# Install your chart
helm install <game-name>-test ./charts/<game-name>

# Watch pod come up
kubectl get pods -w

# Run validation
./charts/<game-name>/test.sh

# Check logs
kubectl logs -f -l app=<game-name>

# Optional: Port-forward to test locally
kubectl port-forward svc/<game-name> <local-port>:<game-port>

# Cleanup
helm uninstall <game-name>-test
kind delete cluster --name <game-name>-test
```

**Common issues**:
- **ImagePullBackOff**: Check image name/tag is correct
- **CrashLoopBackOff**: Check logs, likely config issue
- **Permission denied**: Check security context UIDs match
- **PVC pending**: kind doesn't have storage by default (use `hostPath` provisioner)

### Step 10: Lint the Chart

```bash
helm lint ./charts/<game-name>
```

Fix any warnings or errors before submitting.

## Testing

### Local Testing with kind

```bash
# Install kind storage provisioner (for PVC support)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Set as default storage class
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Install chart
helm install <game>-test ./charts/<game>

# Run test script
./charts/<game>/test.sh
```

### Manual Smoke Test

1. **Pod running**: `kubectl get pods`
2. **Logs look good**: `kubectl logs -f <pod>`
3. **Config file present** (if applicable): `kubectl exec <pod> -- ls -la /game/config`
4. **PVC bound**: `kubectl get pvc`
5. **Service exists**: `kubectl get svc`
6. **Try connecting** (if you can test the actual game client)

### CI/CD Testing

Once you submit a PR, GitHub Actions will:
1. Lint the chart
2. Build dependencies
3. Deploy to kind cluster
4. Run your `test.sh` script
5. Report pass/fail

## Documentation

### README Checklist

- [ ] TL;DR with one-command install
- [ ] Clear introduction
- [ ] Prerequisites listed
- [ ] Multiple installation examples
- [ ] Uninstall instructions
- [ ] Configuration values table (all options)
- [ ] How to connect (with examples)
- [ ] How to manage (logs, backups)
- [ ] Troubleshooting section
- [ ] Links to Docker image + game docs

### values.yaml Comments

Add comments explaining non-obvious settings:

```yaml
service:
  ports:
    - name: game
      port: 2456  # Main game port
      nodePort: 30456
      protocol: UDP
    - name: query
      port: 2457  # Query port for server lists
      nodePort: 30457
      protocol: UDP
```

## Submission

### Pre-Submit Checklist

- [ ] Chart lints successfully (`helm lint`)
- [ ] Dependencies build (`helm dependency build`)
- [ ] Deploys to kind cluster
- [ ] `test.sh` passes
- [ ] README is complete
- [ ] values.yaml has sensible defaults
- [ ] NOTES.txt provides useful instructions
- [ ] All files have correct permissions (`chmod +x test.sh`)

### Git Workflow

```bash
# Create feature branch
git checkout -b feat/add-<game-name>

# Add files
git add charts/<game-name>/

# Commit
git commit -m "feat: add <game-name> Helm chart"

# Push
git push -u origin feat/add-<game-name>
```

### Pull Request

1. Go to GitHub and create PR from your branch
2. Fill out PR template (if exists)
3. Wait for CI to run
4. Address any review feedback
5. Once approved, it will be merged!

## Common Patterns

### Multiple Config Files

```yaml
gameConfig:
  enabled: true
  mountPath: /game/config
  files:
    server-settings.json: |
      { "name": "Server" }
    admin-list.txt: |
      player1
      player2
    banned-players.txt: ""
```

### Init Containers

For fixing permissions or downloading files:

```yaml
initContainers:
  - name: fix-permissions
    image: busybox
    command: ['sh', '-c', 'chown -R 1000:1000 /data']
    volumeMounts:
      - name: data
        mountPath: /data
```

### Secrets

For passwords or API keys (user must create secret):

```yaml
env:
  - name: SERVER_PASSWORD
    valueFrom:
      secretKeyRef:
        name: <game>-secrets
        key: password
```

## Tips

1. **Start simple**: Get basic deployment working first, then add features
2. **Use Factorio as reference**: It's a complete, well-documented example
3. **Test thoroughly**: Don't just check if the pod runs—verify logs show success
4. **Document edge cases**: What if storage class doesn't exist? What if LoadBalancer is used?
5. **Provide examples**: Show common customizations in README
6. **Keep defaults simple**: Out-of-the-box experience should "just work"

## Getting Help

- **Example charts**: See [charts/factorio](../charts/factorio)
- **Library chart**: See [charts/game-server-library](../charts/game-server-library)
- **Architecture**: Read [architecture-refactor-plan.md](./architecture-refactor-plan.md)
- **Questions**: Open a GitHub Discussion

## Next Steps

Once your chart is merged:
- It will be published to the Helm repository
- Users can install with `helm install <game> dedicated-game-servers/<game>`
- Consider adding more games!
