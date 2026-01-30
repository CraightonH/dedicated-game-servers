# Valheim Dedicated Server Helm Chart

Deploy a Valheim dedicated server on Kubernetes with a single command.

**Versioning**: This chart uses [Calendar Versioning (CalVer)](../../docs/VERSIONING.md) with the format `YYYY.MM.MICRO`.

## TL;DR

```bash
helm repo add dedicated-game-servers https://craightonh.github.io/dedicated-game-servers/
helm install valheim dedicated-game-servers/valheim \
  --set env[2].value="YourPassword123"
```

That's it! You now have a running Valheim server.

## Introduction

This chart deploys a Valheim dedicated server on Kubernetes using the [game-server-library](../game-server-library) for common templates. It uses the [lloesche/valheim-server](https://github.com/lloesche/valheim-server-docker) Docker image which includes support for BepInEx and ValheimPlus mods.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PersistentVolume provisioner support in the underlying infrastructure (or configure `persistence.storageClass`)
- At least 3 GB RAM available per server instance

## Installing the Chart

### Basic Installation

```bash
helm install valheim dedicated-game-servers/valheim \
  --set env[2].value="MySecurePass123"
```

⚠️ **Important**: The server password must be at least 5 characters long!

### With Custom Server Name and World

```bash
helm install valheim dedicated-game-servers/valheim \
  --set env[0].value="Vikings United" \
  --set env[1].value="Midgard" \
  --set env[2].value="SecurePassword"
```

### With Custom Values File

Create a `my-values.yaml`:

```yaml
env:
  - name: SERVER_NAME
    value: "My Valheim Server"
  - name: WORLD_NAME
    value: "MyWorld"
  - name: SERVER_PASS
    value: "VerySecurePassword123"
  - name: SERVER_PUBLIC
    value: "false"
```

Install:

```bash
helm install valheim dedicated-game-servers/valheim -f my-values.yaml
```

## Uninstalling the Chart

```bash
helm uninstall valheim
```

To also delete the PersistentVolumeClaim (world data):

```bash
kubectl delete pvc valheim-data
```

## Configuration

### Common Configuration Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `name` | Kubernetes deployment name | `valheim` |
| `image.repository` | Docker image repository | `lloesche/valheim-server` |
| `image.tag` | Docker image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `service.type` | Kubernetes service type | `NodePort` |
| `service.ports[0].nodePort` | External game port (UDP) | `30456` |
| `service.ports[1].nodePort` | External query port (UDP) | `30457` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | PVC storage size | `20Gi` |
| `persistence.storageClass` | Storage class for PVC | `""` (cluster default) |
| `persistence.mountPath` | Mount path in container | `/config` |
| `resources.requests.memory` | Memory request | `3Gi` |
| `resources.requests.cpu` | CPU request | `1000m` |
| `resources.limits.memory` | Memory limit | `6Gi` |
| `resources.limits.cpu` | CPU limit | `2000m` |

### Environment Variables

The Valheim server is configured through environment variables. See the [lloesche/valheim-server documentation](https://github.com/lloesche/valheim-server-docker#environment-variables) for all available options.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `env[0].value` (SERVER_NAME) | Server name shown in browser | `My Valheim Server` |
| `env[1].value` (WORLD_NAME) | World name (without extension) | `Dedicated` |
| `env[2].value` (SERVER_PASS) | Server password (min 5 chars!) | `secret` |
| `env[3].value` (SERVER_PUBLIC) | List in server browser | `false` |
| `env[4].value` (UPDATE_CRON) | Update check schedule | `*/15 * * * *` |
| `env[5].value` (UPDATE_IF_IDLE) | Only update when idle | `true` |
| `env[6].value` (RESTART_CRON) | Daily restart schedule | `0 5 * * *` |
| `env[7].value` (RESTART_IF_IDLE) | Only restart when idle | `true` |
| `env[8].value` (BACKUPS) | Enable automatic backups | `true` |
| `env[9].value` (BACKUPS_CRON) | Backup schedule | `0 * * * *` |
| `env[10].value` (BACKUPS_DIRECTORY) | Backup directory path | `/config/backups` |
| `env[11].value` (BACKUPS_MAX_AGE) | Days to keep backups | `3` |
| `env[12].value` (TZ) | Server timezone | `America/Denver` |

## Connecting to Your Server

### Finding Your Server

1. **Get a node IP**:
   ```bash
   kubectl get nodes -o wide
   ```

2. **Note the NodePort** (default: 30456)

3. **In Valheim**:
   - Launch Valheim
   - Press F2 or click "Join Game"
   - Click "Add server" (bottom right)
   - Enter: `<node-ip>:30456`
   - Connect and enter your password

### Port Forwarding for External Access

If you want players outside your network to connect:

1. **Forward UDP ports** on your router:
   - Port 30456 → Kubernetes node IP
   - Port 30457 → Kubernetes node IP

2. **Get your public IP**:
   ```bash
   curl ifconfig.me
   ```

3. **Share with players**: `<public-ip>:30456`

## Managing Your Server

### View Server Logs

```bash
kubectl logs -f -l app=valheim
```

### Watch Server Startup

```bash
kubectl logs -f -l app=valheim | grep -E "Game server|DungeonDB"
```

### Restart Server

```bash
kubectl delete pod -l app=valheim
```

Kubernetes will automatically create a new pod.

### Access Server Shell

```bash
POD=$(kubectl get pod -l app=valheim -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD -- /bin/bash
```

### Manual Backup

```bash
POD=$(kubectl get pod -l app=valheim -o jsonpath='{.items[0].metadata.name}')
kubectl cp $POD:/config/worlds ./valheim-backup-$(date +%Y%m%d)
```

### Restore World from Backup

```bash
POD=$(kubectl get pod -l app=valheim -o jsonpath='{.items[0].metadata.name}')
kubectl cp ./valheim-backup/MyWorld.db $POD:/config/worlds/
kubectl cp ./valheim-backup/MyWorld.fwl $POD:/config/worlds/
kubectl delete pod -l app=valheim  # Restart to load backup
```

### List Automatic Backups

```bash
POD=$(kubectl get pod -l app=valheim -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- ls -lh /config/backups
```

### Import Existing World

If you have an existing Valheim world from a local game:

1. **Find your local world files** (Windows):
   ```
   C:\Users\<username>\AppData\LocalLow\IronGate\Valheim\worlds\
   ```

2. **Copy to server**:
   ```bash
   POD=$(kubectl get pod -l app=valheim -o jsonpath='{.items[0].metadata.name}')
   kubectl cp MyWorld.db $POD:/config/worlds/
   kubectl cp MyWorld.fwl $POD:/config/worlds/
   ```

3. **Update WORLD_NAME**:
   ```bash
   helm upgrade valheim dedicated-game-servers/valheim \
     --set env[1].value="MyWorld"
   ```

## Troubleshooting

### Server Not Showing in Browser

**Symptom**: Can't find server in the in-game browser

**Solution**:
- Server defaults to `SERVER_PUBLIC=false`
- Use "Add server" feature with IP:port instead
- Or set `SERVER_PUBLIC=true` in values

### Can't Connect

**Symptom**: "Failed to connect" message

**Possible causes**:

1. **Server still starting**: Valheim takes 2-3 minutes to fully start
   ```bash
   kubectl logs -f -l app=valheim | grep "Game server connected"
   ```

2. **Wrong password**: Must be at least 5 characters
   ```bash
   helm upgrade valheim dedicated-game-servers/valheim \
     --set env[2].value="NewPassword123"
   ```

3. **Firewall/NodePort**: Check ports are accessible
   ```bash
   # From another machine
   nc -zvu <node-ip> 30456
   ```

### Pod CrashLoopBackOff

**Symptom**: Pod keeps restarting

**Check logs**:
```bash
kubectl logs -l app=valheim --tail=100
```

**Common causes**:
- Password less than 5 characters
- Insufficient memory (needs 3+ GB)
- Permission issues with PVC

### PersistentVolumeClaim Pending

**Symptom**: `kubectl get pvc` shows `Pending` status

**Solution**:
```bash
# Check storage classes
kubectl get storageclass

# Use a specific storage class
helm upgrade valheim dedicated-game-servers/valheim \
  --set persistence.storageClass=nfs-client
```

### Out of Memory

**Symptom**: Server crashes or becomes unresponsive with many players

**Solution**: Increase memory limits
```bash
helm upgrade valheim dedicated-game-servers/valheim \
  --set resources.limits.memory=8Gi \
  --set resources.requests.memory=4Gi
```

### Permission Denied Errors

**Symptom**: Logs show permission errors writing to `/config`

**Solution**: The init container should fix this, but you can manually fix:
```bash
POD=$(kubectl get pod -l app=valheim -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- chown -R 1000:1000 /config
```

## Advanced Configuration

### Mods: BepInEx

Enable BepInEx mod support:

```yaml
env:
  - name: BEPINEX
    value: "true"
```

Place mods in `/config/bepinex/plugins/`:

```bash
POD=$(kubectl get pod -l app=valheim -o jsonpath='{.items[0].metadata.name}')
kubectl cp my-mod.dll $POD:/config/bepinex/plugins/
kubectl delete pod -l app=valheim  # Restart
```

### Mods: ValheimPlus

Enable ValheimPlus:

```yaml
env:
  - name: VALHEIM_PLUS
    value: "true"
```

Configure ValheimPlus settings:

```bash
POD=$(kubectl get pod -l app=valheim -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD -- vi /config/valheimplus/valheim_plus.cfg
kubectl delete pod -l app=valheim  # Restart
```

### Admin Users

Set admin SteamIDs:

```yaml
env:
  - name: ADMINLIST_IDS
    value: "76561198012345678 76561198087654321"
```

### Ban Users

Set banned SteamIDs:

```yaml
env:
  - name: BANNEDLIST_IDS
    value: "76561198012345678"
```

### Whitelist (Permitted Users)

Allow only specific SteamIDs:

```yaml
env:
  - name: PERMITTEDLIST_IDS
    value: "76561198012345678 76561198087654321"
```

### Custom Update Schedule

Only check for updates at night:

```yaml
env:
  - name: UPDATE_CRON
    value: "0 3 * * *"  # 3 AM daily
```

Disable automatic updates:

```yaml
env:
  - name: UPDATE_CRON
    value: ""
```

### Custom Restart Schedule

Restart every 6 hours:

```yaml
env:
  - name: RESTART_CRON
    value: "0 */6 * * *"
```

### Backup to External Storage

Use a post-backup hook to copy backups elsewhere:

```yaml
env:
  - name: POST_BACKUP_HOOK
    value: 'scp @BACKUP_FILE@ user@backup-server:~/valheim-backups/'
```

### Discord Notifications

Notify on Discord when server starts:

```yaml
env:
  - name: PRE_BOOTSTRAP_HOOK
    value: 'curl -X POST -H "Content-Type: application/json" -d "{\"content\":\"Valheim server starting!\"}" "YOUR_DISCORD_WEBHOOK_URL"'
```

### Use LoadBalancer Instead of NodePort

For cloud environments with LoadBalancer support:

```yaml
service:
  type: LoadBalancer
  ports:
    - name: game
      port: 2456
      protocol: UDP
    - name: query
      port: 2457
      protocol: UDP
```

### Pin to Specific Node

If you have a node with more resources:

```yaml
nodeSelector:
  kubernetes.io/hostname: high-memory-node
```

## Resource Requirements

### Minimum

- **CPU**: 1 core
- **RAM**: 3 GB
- **Storage**: 5 GB

### Recommended

- **CPU**: 2 cores
- **RAM**: 4-6 GB
- **Storage**: 20 GB

### Per-Player Impact

Each additional player adds approximately:
- **RAM**: +200-300 MB
- **CPU**: +5-10% usage

For 10+ players, consider:
- **RAM**: 8 GB
- **CPU**: 4 cores (high clock speed preferred)

## Architecture

This chart uses the [game-server-library](../game-server-library/README.md) which provides reusable templates for common game server resources:

- **Deployment**: Single replica with `Recreate` strategy (game servers don't scale horizontally)
- **Service**: Exposes game ports (UDP)
- **PersistentVolumeClaim**: Stores world saves and backups
- **Init Container**: Fixes volume permissions

Valheim-specific features:
- Automatic updates (configurable)
- Automatic restarts (configurable)
- Automatic backups (hourly by default)
- Mod support (BepInEx and ValheimPlus)

## References

- **Docker Image**: [lloesche/valheim-server](https://github.com/lloesche/valheim-server-docker)
- **Game**: [Valheim on Steam](https://store.steampowered.com/app/892970/Valheim/)
- **Wiki**: [Valheim Wiki](https://valheim.fandom.com/wiki/Valheim_Wiki)
- **Library Chart**: [game-server-library](../game-server-library/README.md)
- **Versioning**: [CalVer Documentation](../../docs/VERSIONING.md)

## License

MIT

## Support

- **Issues**: [GitHub Issues](https://github.com/CraightonH/dedicated-game-servers/issues)
- **Discussions**: [GitHub Discussions](https://github.com/CraightonH/dedicated-game-servers/discussions)
