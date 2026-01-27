# Architecture Refactor Plan: Library Chart + Per-Game Charts

## Goal

Transform the current single generic chart into a library chart + dedicated per-game charts architecture, where:
- **Library chart** contains common reusable templates (Deployment, Service, PVC, ConfigMap, etc.)
- **Game-specific charts** depend on the library and provide game-specific defaults
- **One-command deployment**: `helm install factorio game-server/factorio` → running server with sane defaults

## Current Architecture

```
dedicated-game-servers/
├── chart/                    # Generic game-server chart
│   ├── Chart.yaml
│   ├── values.yaml          # Template values
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── pvc.yaml
│       └── configmap-game-config.yaml
└── games/                   # Game-specific values files
    ├── factorio/
    │   ├── values.yaml      # Override generic chart
    │   └── README.md
    └── valheim/
        └── values.yaml
```

**Issues with current approach:**
- Users must know which values to override for each game
- Game-specific knowledge scattered in values files
- No discoverability (can't `helm search` for specific games)
- Manual chart version management for each game
- Complex values files with game-specific hacks

## Target Architecture

```
dedicated-game-servers/
├── charts/
│   ├── game-server-library/     # Library chart (common templates)
│   │   ├── Chart.yaml           # type: library
│   │   ├── values.yaml          # Sensible defaults
│   │   └── templates/
│   │       ├── _deployment.tpl  # Named templates
│   │       ├── _service.tpl
│   │       ├── _pvc.tpl
│   │       └── _configmap.tpl
│   ├── factorio/                # Factorio chart
│   │   ├── Chart.yaml           # depends: game-server-library
│   │   ├── values.yaml          # Factorio-specific defaults
│   │   ├── templates/
│   │   │   └── _helpers.tpl     # Factorio-specific helpers
│   │   └── README.md
│   └── valheim/                 # Valheim chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── README.md
└── docs/
    └── architecture-refactor-plan.md  # This document
```

## Benefits

1. **Discoverability**: `helm search repo game-server` shows all available games
2. **Simplicity**: `helm install factorio game-server/factorio` just works
3. **Maintainability**: Common logic in one place (library chart)
4. **Versioning**: Each game chart can have independent versions
5. **Testing**: CI can test each game chart independently
6. **Documentation**: Per-game READMEs with specific instructions

## Implementation Plan

### Phase 1: Create Library Chart

**Goal**: Extract common templates into a reusable library chart.

**Steps**:
1. Create `charts/game-server-library/` directory
2. Set `Chart.yaml` with `type: library`
3. Convert existing templates to named templates:
   ```yaml
   # _deployment.tpl
   {{- define "game-server.deployment" -}}
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: {{ .Values.name }}
   ...
   {{- end -}}
   ```
4. Create `_helpers.tpl` with common functions:
   - `game-server.fullname`
   - `game-server.labels`
   - `game-server.selectorLabels`
   - `game-server.serviceAccountName`

**Resources to abstract**:
- ✅ Deployment (with init containers, security contexts, volumes)
- ✅ Service (NodePort/ClusterIP/LoadBalancer)
- ✅ PersistentVolumeClaim (storage configuration)
- ✅ ConfigMap (game config files)
- ⚠️ Optional: Ingress (future enhancement)
- ⚠️ Optional: HorizontalPodAutoscaler (not applicable to most game servers)

### Phase 2: Create Factorio Chart (Proof of Concept)

**Goal**: Validate library chart works with a real game.

**Steps**:
1. Create `charts/factorio/` directory
2. Add `Chart.yaml`:
   ```yaml
   apiVersion: v2
   name: factorio
   version: 1.0.0
   description: Factorio dedicated server
   dependencies:
     - name: game-server-library
       version: "^1.0.0"
       repository: "file://../game-server-library"
   ```
3. Add `values.yaml` with Factorio-specific defaults:
   ```yaml
   name: factorio
   image:
     repository: factoriotools/factorio
     tag: stable-rootless
   service:
     ports:
       - name: game
         port: 34197
         nodePort: 30197
         protocol: UDP
   gameConfig:
     enabled: true
     mountPath: /factorio/config
     files:
       server-settings.json: |
         { "name": "Factorio Server", ... }
   ```
4. Create `templates/_helpers.tpl` for Factorio-specific helpers (if needed)
5. Update README with installation instructions

**Validation**:
- `helm dependency build charts/factorio`
- `helm install factorio charts/factorio`
- Verify server starts successfully

### Phase 3: Migrate Remaining Games

**Goal**: Convert Valheim and future games to use the library chart.

**Steps**:
1. Create `charts/valheim/` (repeat Phase 2 structure)
2. Create `charts/satisfactory/` (if desired)
3. Test each chart independently
4. Update CI/CD to test all game charts

### Phase 4: Update Publishing Workflow

**Goal**: Publish library + game charts to GitHub Pages.

**Steps**:
1. Update `.github/workflows/helm-publish.yaml`:
   ```yaml
   - name: Package charts
     run: |
       mkdir -p .cr-release-packages
       
       # Package library chart
       helm package charts/game-server-library -d .cr-release-packages
       
       # Package game charts (with dependencies)
       for game in charts/*/; do
         if [ -f "$game/Chart.yaml" ] && [ "$game" != "charts/game-server-library/" ]; then
           cd "$game"
           helm dependency build
           cd ../..
           helm package "$game" -d .cr-release-packages
         fi
       done
   ```
2. Update Helm repository index with all charts
3. Verify charts are published correctly

### Phase 5: Documentation Updates

**Goal**: Update all documentation to reflect new architecture.

**Steps**:
1. Update main `README.md`:
   - Show `helm repo add` + `helm search repo game-server`
   - Update installation examples per game
2. Update per-game READMEs:
   - Remove references to generic chart
   - Show simple installation: `helm install <name> game-server/<game>`
3. Create `docs/creating-new-game-chart.md` guide
4. Update `CONTRIBUTING.md` with new workflow

### Phase 6: Deprecate Old Chart

**Goal**: Remove the old generic chart.

**Steps**:
1. Move `chart/` to `charts/game-server-legacy/` (temporarily)
2. Add deprecation notice in `Chart.yaml`:
   ```yaml
   deprecated: true
   description: "DEPRECATED: Use game-specific charts instead"
   ```
3. After 1-2 release cycles, remove completely

## Common Resources Abstraction

### Identified Common Patterns

All game servers share these resources:
- **Deployment**: Single replica, Recreate strategy, game container + optional init containers
- **Service**: NodePort (for home lab) or LoadBalancer, TCP/UDP ports
- **PersistentVolumeClaim**: Single RWO volume for save data
- **ConfigMap**: Game-specific configuration files

### Library Chart Template Structure

```
charts/game-server-library/templates/
├── _deployment.tpl       # {{ include "game-server.deployment" . }}
├── _service.tpl          # {{ include "game-server.service" . }}
├── _pvc.tpl              # {{ include "game-server.pvc" . }}
├── _configmap.tpl        # {{ include "game-server.configmap" . }}
└── _helpers.tpl          # Common helper functions
```

### Example Named Template

```yaml
{{/*
Standard Deployment template for game servers
Usage: {{ include "game-server.deployment" . }}
*/}}
{{- define "game-server.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.name }}
  labels:
    {{- include "game-server.labels" . | nindent 4 }}
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      {{- include "game-server.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "game-server.selectorLabels" . | nindent 8 }}
    spec:
      {{- if .Values.podSecurityContext }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      {{- end }}
      {{- if .Values.initContainers }}
      initContainers:
        {{- toYaml .Values.initContainers | nindent 8 }}
      {{- end }}
      containers:
      - name: game-server
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        {{- if .Values.containerSecurityContext }}
        securityContext:
          {{- toYaml .Values.containerSecurityContext | nindent 10 }}
        {{- end }}
        ports:
        {{- range .Values.service.ports }}
        - name: {{ .name }}
          containerPort: {{ .port }}
          protocol: {{ .protocol | default "TCP" }}
        {{- end }}
        {{- if .Values.persistence.enabled }}
        volumeMounts:
        - name: data
          mountPath: {{ .Values.persistence.mountPath }}
        {{- end }}
      {{- if .Values.persistence.enabled }}
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: {{ .Values.name }}-data
      {{- end }}
{{- end -}}
```

## Game Chart Template Structure

Each game chart should follow this structure:

```
charts/<game>/
├── Chart.yaml            # Game chart metadata + library dependency
├── values.yaml           # Game-specific sane defaults
├── templates/
│   ├── deployment.yaml   # {{ include "game-server.deployment" . }}
│   ├── service.yaml      # {{ include "game-server.service" . }}
│   ├── pvc.yaml          # {{ include "game-server.pvc" . }}
│   ├── configmap.yaml    # {{ include "game-server.configmap" . }}
│   └── NOTES.txt         # Game-specific connection instructions
└── README.md             # Game-specific documentation
```

### Game Chart `values.yaml` Structure

```yaml
# Required: Unique name for this game server instance
name: factorio

# Image configuration
image:
  repository: factoriotools/factorio
  tag: stable-rootless
  pullPolicy: IfNotPresent

# Service configuration (NodePort for home lab)
service:
  type: NodePort
  ports:
    - name: game
      port: 34197
      nodePort: 30197
      protocol: UDP
    - name: rcon
      port: 27015
      nodePort: 30015
      protocol: TCP

# Persistent storage
persistence:
  enabled: true
  storageClass: nfs-client
  size: 50Gi
  mountPath: /factorio

# Security contexts
podSecurityContext:
  fsGroup: 1000

containerSecurityContext:
  runAsUser: 1000
  runAsNonRoot: true

# Game-specific configuration files
gameConfig:
  enabled: true
  mountPath: /factorio/config
  files:
    server-settings.json: |
      {
        "name": "My Factorio Server",
        "description": "A Factorio server",
        "max_players": 10,
        "visibility": { "public": false, "lan": true }
      }

# Resources
resources:
  requests:
    memory: 2Gi
    cpu: 1000m
  limits:
    memory: 4Gi
    cpu: 2000m
```

## CI/CD Updates

### Test Each Game Chart Independently

```yaml
# .github/workflows/test-games.yaml
jobs:
  test:
    strategy:
      matrix:
        game: [factorio, valheim]
    steps:
      - name: Build dependencies
        run: |
          cd charts/${{ matrix.game }}
          helm dependency build
      
      - name: Install game chart
        run: |
          helm install ${{ matrix.game }}-test charts/${{ matrix.game }}
      
      - name: Run game validation
        run: |
          cd charts/${{ matrix.game }}
          ./test.sh
```

### Publish All Charts

```yaml
# .github/workflows/helm-publish.yaml
- name: Package and publish charts
  run: |
    # Package library
    helm package charts/game-server-library -d .cr-release-packages
    
    # Package games
    for game_chart in charts/*/; do
      if [ -f "$game_chart/Chart.yaml" ]; then
        cd "$game_chart"
        helm dependency build
        cd ../..
        helm package "$game_chart" -d .cr-release-packages
      fi
    done
    
    # Update index
    helm repo index .cr-release-packages --url https://craightonh.github.io/dedicated-game-servers/
```

## Migration Path

### For Existing Users

**Option 1: Migrate to new chart** (recommended)
```bash
# Uninstall old deployment
helm uninstall factorio

# Install new chart (data persists in PVC)
helm repo update
helm install factorio game-server/factorio
```

**Option 2: Continue using legacy chart**
```bash
# Old chart remains available (deprecated)
helm install factorio game-server/game-server-legacy --values factorio-values.yaml
```

### Data Persistence

**PVCs are not deleted** by `helm uninstall` by default, so save data persists across migrations.

Users can:
1. Backup saves: `kubectl cp <pod>:/factorio/saves ./backup`
2. Migrate: `helm uninstall old && helm install new`
3. Verify: Saves should be intact in the PVC

## Future Enhancements

Once the refactor is complete, these features become easier:

1. **Ingress Support**: Add ingress template to library chart for HTTP admin panels
2. **Backup CronJobs**: Add optional backup job template
3. **Multi-world Support**: Support multiple instances of the same game
4. **Auto-updates**: Add init container to check for game updates
5. **Metrics Exporters**: Add sidecar containers for Prometheus metrics

## Open Questions

1. **Versioning strategy**: Should library and game charts have independent versions?
   - **Recommendation**: Yes, decouple versions. Library can have breaking changes without affecting games.

2. **Chart repository structure**: Single repo or separate per game?
   - **Recommendation**: Keep all in one repo for now, publish all charts from single workflow.

3. **Dependency version constraints**: Should game charts pin library version or use ranges?
   - **Recommendation**: Use `^1.0.0` (semver range) to allow patch/minor updates automatically.

4. **Testing depth**: How much CI testing per game?
   - **Recommendation**: Validate resource creation + basic smoke test (pod starts). Full game testing optional.

5. **Documentation location**: Per-chart README vs. centralized docs?
   - **Recommendation**: Both. Per-chart README for quick start, centralized docs for advanced topics.

## Success Criteria

The refactor is successful when:

- ✅ `helm repo add game-server https://...` → users can discover all game charts
- ✅ `helm search repo game-server` → shows factorio, valheim, etc.
- ✅ `helm install factorio game-server/factorio` → running server with zero configuration
- ✅ Library chart can be updated independently without breaking game charts
- ✅ Adding a new game requires only creating a new chart directory with values
- ✅ CI tests each game chart automatically
- ✅ Documentation is clear and comprehensive

## Timeline Estimate

- **Phase 1** (Library chart): 1-2 days
- **Phase 2** (Factorio PoC): 1 day
- **Phase 3** (Migrate games): 1 day per game
- **Phase 4** (Publishing): 1 day
- **Phase 5** (Documentation): 1 day
- **Phase 6** (Deprecation): N/A (happens over time)

**Total**: ~1 week for initial refactor + ongoing migration

## References

- [Helm Library Charts](https://helm.sh/docs/topics/library_charts/)
- [Helm Chart Dependencies](https://helm.sh/docs/helm/helm_dependency/)
- [Helm Named Templates](https://helm.sh/docs/chart_template_guide/named_templates/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
