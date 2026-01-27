# Factorio Dedicated Server

Deploy a Factorio dedicated server on Kubernetes using this Helm chart.

## Quick Start

```bash
helm install factorio ../../chart --values values.yaml
```

## Configuration Options

### Basic Settings

| Setting | Description | Default |
|---------|-------------|---------|
| `name` | Server deployment name | `factorio` |
| `image.repository` | Docker image | `factoriotools/factorio` |
| `image.tag` | Image version | `stable` |

### Server Settings (server-settings.json)

All settings in `gameConfig.files.server-settings.json` correspond to Factorio's [server-settings.json](https://wiki.factorio.com/Multiplayer#Setting_up_a_multiplayer_game).

| Setting | Description | Default |
|---------|-------------|---------|
| `name` | Server name shown in browser | `"My Factorio Server"` |
| `description` | Server description | `"A Factorio server..."` |
| `max_players` | Maximum players (0 = unlimited) | `10` |
| `visibility.public` | Publish to official server browser | `false` |
| `visibility.lan` | Visible on LAN | `true` |
| `game_password` | Password to join (leave empty for none) | `""` |
| `require_user_verification` | Require factorio.com account | `false` |
| `allow_commands` | Console commands (`true`, `false`, `admins-only`) | `"admins-only"` |
| `autosave_interval` | Minutes between autosaves | `10` |
| `autosave_slots` | Number of autosave slots | `5` |
| `auto_pause` | Pause when no players online | `true` |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `UPDATE_MODS_ON_START` | Auto-update mods on server start | `false` |
| `SAVE_NAME` | Name of save file to load | `save1` |
| `GENERATE_NEW_SAVE` | Create new world on first start | `false` |

### Network Configuration

| Setting | Description | Default |
|---------|-------------|---------|
| `service.type` | Service type | `NodePort` |
| `service.ports[0].port` | Game port | `34197` (UDP) |
| `service.ports[0].nodePort` | NodePort mapping | `30197` |
| `service.ports[1].port` | RCON port | `27015` (TCP) |
| `service.ports[1].nodePort` | RCON NodePort | `30015` |

### Resources

| Setting | Description | Default |
|---------|-------------|---------|
| `resources.requests.memory` | Minimum memory | `2Gi` |
| `resources.requests.cpu` | Minimum CPU | `1000m` |
| `resources.limits.memory` | Maximum memory | `4Gi` |
| `resources.limits.cpu` | Maximum CPU | `2000m` |

### Storage

| Setting | Description | Default |
|---------|-------------|---------|
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.storageClass` | Storage class name | `nfs-client` |
| `persistence.size` | PVC size | `10Gi` |
| `persistence.mountPath` | Mount path in container | `/factorio` |

## Customization Examples

### Set Server Name and Password

```yaml
gameConfig:
  files:
    server-settings.json: |
      {
        "name": "Epic Factory",
        "game_password": "hunter2",
        "max_players": 20
      }
```

### Public Server (requires factorio.com account)

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
        "password": "your-factorio-password"
      }
```

### Pin to High-Memory Node

```yaml
nodeSelector:
  kubernetes.io/hostname: node1
resources:
  requests:
    memory: "4Gi"
  limits:
    memory: "8Gi"
```

### Auto-Update Mods

```yaml
env:
  - name: UPDATE_MODS_ON_START
    value: "true"
```

## Connecting to Your Server

1. **Get the node IP** where the pod is running:
   ```bash
   kubectl get pods -l app=factorio -o wide
   ```

2. **Connect in Factorio**:
   - Open Factorio → Multiplayer → Connect to address
   - Enter: `<node-ip>:30197` (or your configured NodePort)

## Managing the Server

### View Logs

```bash
kubectl logs -l app=factorio -f
```

### Access RCON Console

```bash
# Port forward RCON port
kubectl port-forward svc/factorio 27015:27015

# Use RCON client (e.g., mcrcon)
mcrcon -H localhost -P 27015 -p <your-rcon-password>
```

### Backup Saves

Saves are stored in the PVC at `/factorio/saves`. To back up:

```bash
POD=$(kubectl get pod -l app=factorio -o jsonpath='{.items[0].metadata.name}')
kubectl cp $POD:/factorio/saves ./factorio-saves-backup
```

### Restore Saves

```bash
POD=$(kubectl get pod -l app=factorio -o jsonpath='{.items[0].metadata.name}')
kubectl cp ./factorio-saves-backup $POD:/factorio/saves
kubectl delete pod $POD  # Restart to load the save
```

## Troubleshooting

### Server Won't Start

Check logs for errors:
```bash
kubectl logs -l app=factorio
```

Common issues:
- Incorrect save file name in `SAVE_NAME`
- Invalid server-settings.json syntax
- Insufficient memory/CPU

### Can't Connect

1. Verify pod is running:
   ```bash
   kubectl get pods -l app=factorio
   ```

2. Check service and NodePort:
   ```bash
   kubectl get svc factorio
   ```

3. Ensure firewall allows UDP traffic on the NodePort

### Performance Issues

Increase resources:
```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "2000m"
  limits:
    memory: "8Gi"
    cpu: "4000m"
```

## Testing

This game includes an automated test script (`test.sh`) that validates deployments in CI/CD.

To test locally:
```bash
# Deploy Factorio
helm install factorio ../../chart --values values.yaml

# Run validation
./test.sh

# Cleanup
helm uninstall factorio
```

The test validates:
- Pod readiness
- Server startup logs
- Config file generation
- PVC binding
- Service configuration

## References

- [Factorio Docker Image](https://github.com/factoriotools/factorio-docker)
- [Factorio Multiplayer Guide](https://wiki.factorio.com/Multiplayer)
- [Server Settings Documentation](https://wiki.factorio.com/Multiplayer#Setting_up_a_multiplayer_game)
