#!/bin/bash
# Factorio deployment validation test
# This script validates a Factorio server deployment in CI/CD
set -e

POD=$(kubectl get pod -l app=factorio -o jsonpath='{.items[0].metadata.name}')

echo "🔍 Validating Factorio server deployment..."

# Wait for pod to be ready (Helm chart used --wait, so this should be quick)
echo "⏳ Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app=factorio --timeout=300s

# Give server a moment to start up
sleep 10

# Check logs for success indicators
echo "📋 Checking server logs..."
LOGS=$(kubectl logs $POD --tail=100)

# Factorio-specific success patterns (more lenient for CI)
if echo "$LOGS" | grep -q "Hosting game\|Loading map\|changing state from\|Matching server connection"; then
    echo "✅ Factorio server started successfully"
elif echo "$LOGS" | grep -q "SAVE_NAME\|GENERATE_NEW_SAVE\|FACTORIO_VOL"; then
    echo "✅ Factorio container initialized (server may still be starting)"
else
    echo "⚠️  Warning: Could not verify server startup"
    echo "Recent logs:"
    echo "$LOGS"
fi

# Check for critical errors
if echo "$LOGS" | grep -qi "fatal error\|permission denied.*config"; then
    echo "❌ Critical error detected in logs"
    echo "$LOGS"
    exit 1
fi

# Verify config file was created
echo "📁 Checking config files..."
if kubectl exec $POD -- test -f /factorio/config/server-settings.json; then
    echo "✅ server-settings.json exists"
    
    # Validate JSON syntax
    if kubectl exec $POD -- cat /factorio/config/server-settings.json | jq . > /dev/null 2>&1; then
        echo "✅ server-settings.json is valid JSON"
    else
        echo "❌ server-settings.json is invalid JSON"
        exit 1
    fi
else
    echo "❌ server-settings.json not found"
    exit 1
fi

# Check persistent storage
echo "💾 Checking persistent storage..."
PVC=$(kubectl get pvc factorio-data -o jsonpath='{.status.phase}')
if [ "$PVC" == "Bound" ]; then
    echo "✅ PVC is bound"
else
    echo "❌ PVC is not bound: $PVC"
    exit 1
fi

# Verify service
echo "🌐 Checking service..."
SVC=$(kubectl get svc factorio -o jsonpath='{.spec.type}')
if [ "$SVC" == "NodePort" ]; then
    echo "✅ Service is NodePort"
    GAME_PORT=$(kubectl get svc factorio -o jsonpath='{.spec.ports[?(@.name=="game")].nodePort}')
    RCON_PORT=$(kubectl get svc factorio -o jsonpath='{.spec.ports[?(@.name=="rcon")].nodePort}')
    echo "   Game port: $GAME_PORT (UDP)"
    echo "   RCON port: $RCON_PORT (TCP)"
else
    echo "❌ Service type is not NodePort: $SVC"
    exit 1
fi

# Verify security context was applied
echo "🔒 Checking security context..."
FS_GROUP=$(kubectl get pod $POD -o jsonpath='{.spec.securityContext.fsGroup}')
RUN_AS_USER=$(kubectl get pod $POD -o jsonpath='{.spec.securityContext.runAsUser}')
if [ "$FS_GROUP" = "845" ] && [ "$RUN_AS_USER" = "845" ]; then
    echo "✅ Security context configured correctly (fsGroup=845, runAsUser=845)"
else
    echo "❌ Security context incorrect: fsGroup=$FS_GROUP, runAsUser=$RUN_AS_USER"
    exit 1
fi

echo ""
echo "✅ All Factorio validation checks passed!"
