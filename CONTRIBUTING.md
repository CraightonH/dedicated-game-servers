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

### 4. Create Validation Script

Create `tests/validate-<game-name>.sh`:

```bash
#!/bin/bash
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
chmod +x tests/validate-<game-name>.sh
```

### 5. Add to CI/CD

Edit `.github/workflows/test-deployment.yaml`:

1. Add to the `detect-changes` job filters:
   ```yaml
   <game-name>:
     - 'games/<game-name>/**'
     - 'chart/**'
   ```

2. Add a new job (copy and modify `test-factorio`):
   ```yaml
   test-<game-name>:
     needs: detect-changes
     if: needs.detect-changes.outputs.<game-name> == 'true'
     runs-on: ubuntu-latest
     steps:
       - name: Checkout
         uses: actions/checkout@v4
       
       - name: Set up Helm
         uses: azure/setup-helm@v4
       
       - name: Set up kind cluster
         uses: helm/kind-action@v1
       
       - name: Deploy <game-name>
         run: |
           helm install <game-name>-test ./chart \
             --values ./games/<game-name>/values.yaml \
             --set persistence.storageClass="" \
             --wait --timeout=5m
       
       - name: Run validation
         run: |
           chmod +x ./tests/validate-<game-name>.sh
           ./tests/validate-<game-name>.sh
       
       - name: Get logs
         if: always()
         run: kubectl logs -l app=<game-name> --tail=100
       
       - name: Cleanup
         if: always()
         run: helm uninstall <game-name>-test || true
   ```

3. Add to helm-lint.yaml:
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
   git add games/<game-name>/ tests/validate-<game-name>.sh .github/
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
