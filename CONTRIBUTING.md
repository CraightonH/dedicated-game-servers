# Contributing to Dedicated Game Servers

Thanks for your interest in contributing! This guide will help you add new games or improve existing ones.

## Adding a New Game

### 1. Create Game Directory

```bash
mkdir -p games/<game-name>
```

### 2. Create `values.yaml`

Copy the template and customize:

```bash
cp chart/values.yaml games/<game-name>/values.yaml
```

Edit `games/<game-name>/values.yaml` with game-specific settings:

- `name`: Kubernetes resource name (e.g., `"factorio"`)
- `image`: Docker image for the game server
- `service.ports`: Game server ports (UDP/TCP)
- `gameConfig`: Configuration files the server needs
- `env`: Environment variables for the container
- `resources`: CPU/memory requirements

### 3. Create `README.md`

Document the configuration options in `games/<game-name>/README.md`.

See `games/factorio/README.md` for a good example. Include:

- **Quick Start** - How to deploy
- **Configuration Table** - All customizable options
- **Examples** - Common customizations
- **Connecting** - How players join the server
- **Troubleshooting** - Common issues

### 4. Create Test Script

Create `games/<game-name>/test.sh`:

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
if echo "$LOGS" | grep -q "<success-pattern>"; then
    echo "✅ Server started successfully"
else
    echo "❌ Server did not start"
    echo "$LOGS"
    exit 1
fi

# Verify config files
# Add game-specific checks here

echo "✅ All validation checks passed!"
```

Make it executable:
```bash
chmod +x games/<game-name>/test.sh
```

### 5. CI/CD Auto-Discovery

**No workflow changes needed!** The CI/CD workflow automatically:
1. Detects which games changed in the PR
2. Finds games with `test.sh` files
3. Runs tests for affected games

Your game will be tested automatically once you have:
- `games/<game-name>/values.yaml`
- `games/<game-name>/test.sh` (executable)

To add helm linting for your game, edit `.github/workflows/helm-lint.yaml`:
```yaml
- name: Lint <game-name> values
  run: |
    helm lint ./chart --values ./games/<game-name>/values.yaml
```

### 6. Test Locally

```bash
# Create test cluster
kind create cluster --name test

# Deploy your game
helm install <game-name> ./chart --values ./games/<game-name>/values.yaml

# Run validation
./tests/validate-<game-name>.sh

# Check it works
kubectl get pods -l app=<game-name>
kubectl logs -l app=<game-name>

# Cleanup
helm uninstall <game-name>
kind delete cluster --name test
```

### 7. Submit PR

1. Commit your changes:
   ```bash
   git checkout -b feat/add-<game-name>
   git add games/<game-name>/
   git commit -m "feat: add <game-name> support"
   git push -u origin feat/add-<game-name>
   ```

2. Open a PR on GitHub
3. CI will automatically test your game deployment
4. Once tests pass and review is complete, it will be merged!

## Improving Existing Games

To modify an existing game's configuration:

1. Edit `games/<game-name>/values.yaml` or `README.md`
2. Test locally (see step 6 above)
3. Submit PR
4. CI will verify the changes deploy successfully

## CI/CD Testing

All PRs automatically run:

- **Helm Lint** - Validates chart syntax
- **Deployment Test** - Deploys to kind cluster
- **Game Validation** - Runs game-specific health checks

Tests only run for games that were modified in the PR.

## Questions?

Open an issue or discussion on GitHub!
