# Game Configurations

This directory contains configuration and test files for each supported game.

## Structure

Each game has its own directory with:

```
games/<game-name>/
├── values.yaml    # Helm values for deploying this game
├── README.md      # Documentation and configuration guide
└── test.sh        # Automated validation test (optional but recommended)
```

## Supported Games

| Game | Status | Test | Description |
|------|--------|------|-------------|
| [factorio](./factorio/) | ✅ Ready | ✅ | Factory building and automation |
| [valheim](./valheim/) | 🚧 Coming soon | ❌ | Viking survival and exploration |

## Adding a New Game

See [CONTRIBUTING.md](../CONTRIBUTING.md) for detailed instructions.

**Quick summary:**

1. Create `games/<game-name>/` directory
2. Add `values.yaml` with game-specific Helm values
3. Add `README.md` documenting the configuration
4. Add `test.sh` for automated validation (recommended)
5. Make `test.sh` executable: `chmod +x games/<game-name>/test.sh`
6. Submit PR - CI will automatically test your game!

## Test Scripts

Test scripts (`test.sh`) validate that:
- The game server deploys successfully
- Config files are generated correctly
- The server starts and is ready for players
- No errors in logs

Tests run automatically in CI/CD when a game's files are modified.

### Running Tests Locally

```bash
# Deploy the game
helm install <game> ../chart --values values.yaml

# Run the test
./<game>/test.sh

# Cleanup
helm uninstall <game>
```

### Test Auto-Discovery

The CI/CD workflow automatically discovers and tests games:
1. Detects which files changed in your PR
2. Finds games with `test.sh` files
3. Runs tests only for affected games

No workflow modifications needed - just add your `test.sh`!

## Game-Specific Notes

### Factorio

- Uses `factoriotools/factorio` Docker image
- Generates `server-settings.json` from Helm values
- UDP game port 34197, TCP RCON port 27015
- Requires 2-4Gi RAM for reasonable gameplay

See [factorio/README.md](./factorio/README.md) for full documentation.

### Valheim

Coming soon! Interested in contributing? See [CONTRIBUTING.md](../CONTRIBUTING.md).
