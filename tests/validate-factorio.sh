#!/bin/bash
set -e

POD=$(kubectl get pod -l app=factorio -o jsonpath='{.items[0].metadata.name}')

echo "🔍 Validating Factorio server deployment..."

# Wait for pod to be ready
echo "⏳ Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app=factorio --timeout=300s

# Check logs for success indicators
echo "📋 Checking server logs..."
LOGS=$(kubectl logs $POD --tail=100)

# Factorio-specific success patterns
if echo "$LOGS" | grep -q "Hosting game\|Loading map\|changing state from"; then
    echo "✅ Factorio server started successfully"
else
    echo "❌ Factorio server did not start properly"
    echo "Recent logs:"
    echo "$LOGS"
    exit 1
fi

# Check for errors
if echo "$LOGS" | grep -qi "error\|fatal\|failed"; then
    echo "⚠️  Warning: Found error messages in logs"
    echo "$LOGS" | grep -i "error\|fatal\|failed"
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
    echo "   Game port: $GAME_PORT"
else
    echo "❌ Service type is not NodePort: $SVC"
    exit 1
fi

echo ""
echo "✅ All Factorio validation checks passed!"
