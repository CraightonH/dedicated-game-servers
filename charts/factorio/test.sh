#!/bin/bash
# Factorio deployment validation test
set -e

echo "🔍 Validating factorio server deployment..."

# Wait for pod to be ready
echo "⏳ Waiting for pod readiness..."
kubectl wait --for=condition=ready pod -l app=factorio --timeout=300s

# Get pod name
POD=$(kubectl get pod -l app=factorio -o jsonpath='{.items[0].metadata.name}')
echo "✅ Pod is ready: $POD"

# Wait up to 30 seconds for Factorio server to start
echo "📋 Waiting for Factorio server to start (up to 30 seconds)..."
SUCCESS=false
for i in {1..30}; do
    # Get recent logs
    LOGS=$(kubectl logs $POD --tail=50 2>/dev/null || echo "")
    
    # Check for "Hosting game at IP ADDR" message
    if echo "$LOGS" | grep -q "Hosting game at IP ADDR"; then
        echo "✅ Found 'Hosting game at IP ADDR' in logs"
        SUCCESS=true
        break
    fi
    
    # Check if pod is still running
    POD_PHASE=$(kubectl get pod $POD -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [ "$POD_PHASE" != "Running" ]; then
        echo "❌ Pod is no longer running (phase: $POD_PHASE)"
        echo "Recent logs:"
        echo "$LOGS"
        exit 1
    fi
    
    # Wait 1 second before next check
    sleep 1
done

# Check if we found the success message
if [ "$SUCCESS" = false ]; then
    echo "❌ Server did not start within 30 seconds"
    echo "Recent logs:"
    kubectl logs $POD --tail=100
    exit 1
fi

# Verify pod is still running after finding the message
POD_PHASE=$(kubectl get pod $POD -o jsonpath='{.status.phase}')
if [ "$POD_PHASE" != "Running" ]; then
    echo "❌ Pod stopped running after startup (phase: $POD_PHASE)"
    exit 1
fi

echo "✅ Factorio server started successfully and is still running"

# Verify config file was mounted (if using gameConfig)
if kubectl exec $POD -- test -f /factorio/config/server-settings.json 2>/dev/null; then
    echo "✅ Config file mounted correctly"
    # Verify it contains expected content (basic check without jq)
    CONFIG_CONTENT=$(kubectl exec $POD -- cat /factorio/config/server-settings.json 2>/dev/null)
    if echo "$CONFIG_CONTENT" | grep -q '"name"' && echo "$CONFIG_CONTENT" | grep -q '"max_players"'; then
        echo "✅ server-settings.json contains expected fields"
    else
        echo "❌ server-settings.json is missing expected fields"
        echo "$CONFIG_CONTENT"
        exit 1
    fi
    
    # Verify rconpw was created (shows directory is writable)
    if kubectl exec $POD -- test -f /factorio/config/rconpw 2>/dev/null; then
        echo "✅ RCON password file created (config directory is writable)"
    else
        echo "⚠️  RCON password file not found yet (may still be initializing)"
    fi
else
    echo "⚠️  Config file not found (may be expected if gameConfig disabled)"
fi

# Check PVC is bound
PVC_NAME="factorio-data"
PVC_STATUS=$(kubectl get pvc $PVC_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "$PVC_STATUS" == "Bound" ]; then
    echo "✅ PVC is bound: $PVC_NAME"
else
    echo "❌ PVC not bound: $PVC_STATUS"
    kubectl get pvc $PVC_NAME || true
    exit 1
fi

# Verify service
SVC_TYPE=$(kubectl get svc factorio -o jsonpath='{.spec.type}')
if [ "$SVC_TYPE" == "NodePort" ]; then
    GAME_PORT=$(kubectl get svc factorio -o jsonpath='{.spec.ports[?(@.name=="game")].nodePort}')
    RCON_PORT=$(kubectl get svc factorio -o jsonpath='{.spec.ports[?(@.name=="rcon")].nodePort}')
    echo "✅ Service is NodePort"
    echo "   Game port: $GAME_PORT (UDP)"
    echo "   RCON port: $RCON_PORT (TCP)"
else
    echo "⚠️  Service type is $SVC_TYPE (expected NodePort for tests)"
fi

# Check container resources
REQUESTS_MEM=$(kubectl get pod $POD -o jsonpath='{.spec.containers[0].resources.requests.memory}')
LIMITS_MEM=$(kubectl get pod $POD -o jsonpath='{.spec.containers[0].resources.limits.memory}')
echo "ℹ️  Resources: requests=$REQUESTS_MEM, limits=$LIMITS_MEM"

echo "✅ All validation checks passed!"
