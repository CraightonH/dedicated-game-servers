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

# Check logs for success indicators
echo "📋 Checking server logs..."
LOGS=$(kubectl logs $POD --tail=100)

# Factorio server ready indicators
if echo "$LOGS" | grep -qi "changing state from(CreatingGame) to(InGame)\|Hosting game at\|ConnectionAcceptOrDeny"; then
    echo "✅ Factorio server started successfully"
else
    echo "❌ Server did not start properly"
    echo "Recent logs:"
    echo "$LOGS"
    exit 1
fi

# Verify config file was mounted (if using gameConfig)
if kubectl exec $POD -- test -f /factorio/config/server-settings.json 2>/dev/null; then
    echo "✅ Config file mounted correctly"
    # Verify JSON is valid
    if kubectl exec $POD -- cat /factorio/config/server-settings.json | jq . > /dev/null 2>&1; then
        echo "✅ server-settings.json is valid JSON"
    else
        echo "❌ server-settings.json is not valid JSON"
        kubectl exec $POD -- cat /factorio/config/server-settings.json || true
        exit 1
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
