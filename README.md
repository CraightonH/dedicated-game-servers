# Dedicated Game Servers

A simple Helm chart for deploying dedicated game servers on Kubernetes.

## Purpose

This chart provides a straightforward way to deploy and manage dedicated game servers without the complexity of a custom operator. It handles:

- Deploying game server containers
- Generating game-specific configuration files
- Persistent storage for save data
- NodePort services for network access

## Supported Games

- **Factorio** - Factory building and automation
- Valheim _(coming soon)_
- Satisfactory _(coming soon)_

## Quick Start

### Install Factorio Server

```bash
helm install factorio ./chart \
  --values ./games/factorio/values.yaml \
  --set factorio.serverName="My Factorio Server" \
  --set factorio.password="changeme"
```

### Customize Settings

Each game has a `values.yaml` file in `games/<game-name>/` with game-specific settings. Copy and modify to suit your needs:

```bash
cp games/factorio/values.yaml my-factorio.yaml
# Edit my-factorio.yaml with your preferences
helm install factorio ./chart --values my-factorio.yaml
```

## Structure

```
dedicated-game-servers/
├── chart/              # Main Helm chart
│   ├── Chart.yaml
│   ├── values.yaml     # Default values (template)
│   └── templates/      # Kubernetes manifests
└── games/              # Game-specific configurations
    ├── factorio/
    │   ├── values.yaml
    │   └── README.md
    └── valheim/
        ├── values.yaml
        └── README.md
```

## How It Works

1. The Helm chart templates deploy:
   - A Deployment with your game server container
   - A PersistentVolumeClaim for save data
   - A ConfigMap with game-specific configuration
   - A NodePort Service for network access

2. Game configs are generated from Helm values and mounted into the container

3. Save data persists across pod restarts

## Configuration

See individual game READMEs in `games/<game-name>/` for detailed configuration options.

## Why Not an Operator?

This project started as a Kubernetes operator (boilerr) but was simplified to a Helm chart because:

- The primary need was **deployment**, not lifecycle management
- Advanced features (auto-updates, backups) were low priority
- A Helm chart is simpler to maintain and understand
- It's easier to add new games (just add a values file)

If you need advanced automation, consider [boilerr](https://github.com/CraightonH/boilerr).

## Contributing

To add a new game:

1. Create `games/<game-name>/` directory
2. Add `values.yaml` with game-specific settings
3. Add `README.md` documenting the configuration options
4. Test deployment

## License

MIT
