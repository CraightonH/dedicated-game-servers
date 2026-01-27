# Test Scripts

This directory contains validation scripts for testing game server deployments in CI/CD.

## Scripts

### `validate-factorio.sh`

Validates a Factorio server deployment by checking:

- ✅ Pod is running and ready
- ✅ Server logs show successful startup
- ✅ Configuration file exists and is valid JSON
- ✅ PVC is bound
- ✅ Service is configured as NodePort
- ❌ No errors in logs

**Usage:**

```bash
# Deploy Factorio first
helm install factorio ../chart --values ../games/factorio/values.yaml

# Run validation
./validate-factorio.sh
```

## Adding Tests for New Games

To add validation for a new game:

1. Create `validate-<game>.sh` script
2. Follow the pattern from `validate-factorio.sh`:
   - Check pod is ready
   - Validate logs for game-specific success messages
   - Verify config files were generated correctly
   - Check PVC and service
3. Make it executable: `chmod +x validate-<game>.sh`
4. Add to `.github/workflows/test-deployment.yaml`:
   ```yaml
   - name: Run <game> validation
     run: |
       chmod +x ./tests/validate-<game>.sh
       ./tests/validate-<game>.sh
   ```

## Local Testing

You can run these scripts locally against a kind cluster:

```bash
# Create kind cluster
kind create cluster --name test

# Deploy game server
helm install <game> ../chart --values ../games/<game>/values.yaml

# Run validation
./validate-<game>.sh

# Cleanup
helm uninstall <game>
kind delete cluster --name test
```

## CI/CD Integration

These scripts are automatically run in GitHub Actions when:
- A PR modifies files in `chart/**` or `games/<game>/**`
- Changes are pushed to `main`

See `.github/workflows/test-deployment.yaml` for the full workflow.
