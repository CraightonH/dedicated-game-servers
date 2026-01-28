# Factorio Dedicated Server Helm Chart

Deploy a Factorio dedicated server on Kubernetes with a single command.

**Versioning**: This chart uses [Calendar Versioning (CalVer)](../../docs/VERSIONING.md) with the format `YYYY.MM.MICRO`.

## TL;DR

```bash
helm repo add dedicated-game-servers https://craightonh.github.io/dedicated-game-servers/
helm install factorio dedicated-game-servers/factorio
```

That's it! You now have a running Factorio server.

## Introduction

This chart deploys a Factorio dedicated server on Kubernetes using the [game-server-library](../game-server-library) for common templates.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PersistentVolume provisioner support in the underlying infrastructure (or configure `persistence.storageClass`)

## Installing the Chart

### Basic Installation

```bash
helm install factorio dedicated-game-servers/factorio
```

### With Custom Server Name

```bash
helm install factorio dedicated-game-servers/factorio \
  --set gameConfig.files.server-settings\.json.name="My Awesome Factory"
```

### With Custom Values File

```bash
helm install factorio dedicated-game-servers/factorio -f my-values.yaml
```

## Uninstalling the Chart

```bash
helm uninstall factorio
```

**Note**: By default, the PersistentVolumeClaim is not deleted. Your save data will persist.

To also delete the PVC:
```bash
kubectl delete pvc factorio-data
```

## Configuration

See [values.yaml](values.yaml) for the full list of configuration options.

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `name` | Server deployment name | `factorio` |
| `image.repository` | Factorio Docker image | `factoriotools/factorio` |
| `image.tag` | Image tag | `stable-rootless` |
| `service.type` | Service type | `NodePort` |
| `service.ports[0].nodePort` | Game port (UDP) | `30197` |
| `service.ports[1].nodePort` | RCON port (TCP) | `30015` |
| `persistence.size` | Storage size | `50Gi` |
| `persistence.storageClass` | Storage class | `nfs-client` |
| `gameConfig.files.server-settings.json.name` | Server name | `My Factorio Server` |
| `gameConfig.files.server-settings.json.game_password` | Game password | `""` (no password) |
| `gameConfig.files.server-settings.json.max_players` | Max players | `10` |

### Server Settings

All Factorio server settings can be configured via `gameConfig.files.server-settings.json`. See the [Factorio wiki](https://wiki.factorio.com/Multiplayer#Setting_up_a_multiplayer_game) for all available options.

Example customization:

```yaml
gameConfig:
  files:
    server-settings.json: |
      {
        "name": "Epic Factory",
        "description": "Build the factory!",
        "max_players": 20,
        "game_password": "secret123",
        "visibility": {
          "public": false,
          "lan": true
        },
        "auto_pause": true,
        "autosave_interval": 5
      }
```

### Environment Variables

Configure Factorio server behavior via environment variables:

```yaml
env:
  - name: UPDATE_MODS_ON_START
    value: "true"  # Auto-update mods
  - name: SAVE_NAME
    value: "my-save"
  - name: GENERATE_NEW_SAVE
    value: "false"
```

### Resources

Adjust resource limits based on your server size:

```yaml
resources:
  requests:
    memory: 4Gi
    cpu: 2000m
  limits:
    memory: 8Gi
    cpu: 4000m
```

### Node Selection

Pin the server to a specific node (useful for nodes with more RAM):

```yaml
nodeSelector:
  kubernetes.io/hostname: node1
```

## Connecting to Your Server

### Finding the Connection Address

#### NodePort (default)

```bash
# Get the node IP
kubectl get pod -l app=factorio -o wide

# Connect to <node-ip>:30197
```

#### LoadBalancer

```bash
# Get external IP
kubectl get svc factorio

# Connect to <external-ip>:34197
```

### In Factorio Client

1. Open Factorio
2. Click "Multiplayer"
3. Click "Connect to address"
4. Enter the address from above

## Managing Your Server

### View Logs

```bash
kubectl logs -f -l app=factorio
```

### Backup Saves

```bash
POD=$(kubectl get pod -l app=factorio -o jsonpath='{.items[0].metadata.name}')
kubectl cp $POD:/factorio/saves ./factorio-backup
```

### Restore Saves

```bash
POD=$(kubectl get pod -l app=factorio -o jsonpath='{.items[0].metadata.name}')
kubectl cp ./factorio-backup $POD:/factorio/saves
kubectl delete pod $POD  # Restart to load saves
```

### Access RCON Console

```bash
# Port forward RCON
kubectl port-forward svc/factorio 27015:27015

# Use an RCON client (e.g., mcrcon)
mcrcon -H localhost -P 27015 -p <rcon-password>
```

The RCON password is auto-generated and stored in `/factorio/config/rconpw` inside the pod.

## Troubleshooting

### Server Won't Start

Check the logs:
```bash
kubectl logs -l app=factorio
```

Common issues:
- Invalid `server-settings.json` syntax
- Insufficient memory/CPU
- Wrong save file name in `SAVE_NAME`

### Can't Connect

1. Verify pod is running:
   ```bash
   kubectl get pods -l app=factorio
   ```

2. Check service:
   ```bash
   kubectl get svc factorio
   ```

3. Ensure firewall allows UDP traffic on the NodePort

### Permission Errors

This chart uses the `stable-rootless` image which runs as UID 1000. If you see permission errors:

1. Check the PVC permissions match UID 1000
2. Consider adding an init container to fix permissions (see `initContainers` in values.yaml)

## Advanced Configuration

### Public Server (factorio.com listing)

```yaml
gameConfig:
  files:
    server-settings.json: |
      {
        "name": "My Public Server",
        "visibility": {
          "public": true,
          "lan": true
        },
        "username": "your-factorio-username",
        "password": "your-factorio-password",
        "require_user_verification": true
      }
```

### Auto-Update Mods

```yaml
env:
  - name: UPDATE_MODS_ON_START
    value: "true"
```

### Multiple Servers

Deploy multiple independent Factorio servers:

```bash
helm install factorio1 dedicated-game-servers/factorio --set name=factorio1 --set service.ports[0].nodePort=30198
helm install factorio2 dedicated-game-servers/factorio --set name=factorio2 --set service.ports[0].nodePort=30199
```

## Architecture

This chart uses the [game-server-library](../game-server-library) for common Kubernetes resources:
- **Deployment**: Single replica with Recreate strategy
- **Service**: NodePort or LoadBalancer
- **PersistentVolumeClaim**: For game saves and mods
- **ConfigMap**: For server-settings.json

## References

- [Factorio Docker Image](https://github.com/factoriotools/factorio-docker)
- [Factorio Multiplayer Guide](https://wiki.factorio.com/Multiplayer)
- [Server Settings Documentation](https://wiki.factorio.com/Multiplayer#Setting_up_a_multiplayer_game)
- [Game Server Library](../game-server-library)

## License

MIT
