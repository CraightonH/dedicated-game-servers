#!/bin/bash
# Valheim deployment validation test
set -e

echo "🔍 Validating valheim server deployment..."

# Wait for pod to be ready
echo "⏳ Waiting for pod readiness..."
kubectl wait --for=condition=ready pod -l app=valheim --timeout=300s

# Get pod name
POD=$(kubectl get pod -l app=valheim -o jsonpath='{.items[0].metadata.name}')
echo "✅ Pod is ready: $POD"

# Wait up to 900 seconds for Valheim server to start  
# Valheim takes much longer than Factorio (downloads 1.78 GB game files on first start)
# Download can take 10+ minutes on CI, plus server needs 3-5 minutes to initialize
echo "📋 Waiting for Valheim server to start (up to 900 seconds / 15 minutes)..."
SUCCESS=false
for i in {1..900}; do
    # Get recent logs
    LOGS=$(kubectl logs $POD --tail=100 2>/dev/null || echo "")
    
    # Check for "Game server connected" message
    # This is the definitive message that indicates the server is ready
    if echo "$LOGS" | grep -q "Game server connected"; then
        echo "✅ Found 'Game server connected' in logs"
        SUCCESS=true
        break
    fi
    
    # Alternative success indicators (any of these is good)
    if echo "$LOGS" | grep -q "DungeonDB Start"; then
        echo "✅ Found 'DungeonDB Start' in logs (server initializing)"
    fi
    
    # Check if pod is still running
    POD_PHASE=$(kubectl get pod $POD -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [ "$POD_PHASE" != "Running" ]; then
        echo "❌ Pod is no longer running (phase: $POD_PHASE)"
        echo "Recent logs:"
        echo "$LOGS"
        exit 1
    fi
    
    # Progress indicator every 60 seconds
    if [ $((i % 60)) -eq 0 ]; then
        echo "   Still waiting... ($i/900 seconds, ~$((i/60)) minutes)"
    fi
    
    # Wait 1 second before next check
    sleep 1
done

# Check if we found the success message
if [ "$SUCCESS" = false ]; then
    echo "❌ Server did not start within 900 seconds (15 minutes)"
    echo "This may indicate a download or initialization issue."
    echo "Recent logs:"
    kubectl logs $POD --tail=200
    exit 1
fi

# Verify pod is still running after finding the message
POD_PHASE=$(kubectl get pod $POD -o jsonpath='{.status.phase}')
if [ "$POD_PHASE" != "Running" ]; then
    echo "❌ Pod stopped running after startup (phase: $POD_PHASE)"
    exit 1
fi

echo "✅ Valheim server started successfully and is still running"

# Verify world directory exists
if kubectl exec $POD -- test -d /config/worlds 2>/dev/null; then
    echo "✅ Worlds directory exists"
    # List worlds if any
    WORLDS=$(kubectl exec $POD -- ls /config/worlds 2>/dev/null || echo "")
    if [ -n "$WORLDS" ]; then
        echo "   Found worlds:"
        echo "$WORLDS" | sed 's/^/     /'
    fi
else
    echo "⚠️  Worlds directory not found (may still be initializing)"
fi

# Verify backups directory exists
if kubectl exec $POD -- test -d /config/backups 2>/dev/null; then
    echo "✅ Backups directory exists"
else
    echo "⚠️  Backups directory not found (may still be initializing)"
fi

# Check PVC is bound
PVC_NAME="valheim-data"
PVC_STATUS=$(kubectl get pvc $PVC_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "$PVC_STATUS" == "Bound" ]; then
    echo "✅ PVC is bound: $PVC_NAME"
else
    echo "❌ PVC not bound: $PVC_STATUS"
    kubectl get pvc $PVC_NAME || true
    exit 1
fi

# Verify service
SVC_TYPE=$(kubectl get svc valheim -o jsonpath='{.spec.type}')
if [ "$SVC_TYPE" == "NodePort" ]; then
    GAME_PORT=$(kubectl get svc valheim -o jsonpath='{.spec.ports[?(@.name=="game")].nodePort}')
    QUERY_PORT=$(kubectl get svc valheim -o jsonpath='{.spec.ports[?(@.name=="query")].nodePort}')
    echo "✅ Service is NodePort"
    echo "   Game port: $GAME_PORT (UDP)"
    echo "   Query port: $QUERY_PORT (UDP)"
else
    echo "⚠️  Service type is $SVC_TYPE (expected NodePort for tests)"
fi

# Check container resources
REQUESTS_MEM=$(kubectl get pod $POD -o jsonpath='{.spec.containers[0].resources.requests.memory}')
LIMITS_MEM=$(kubectl get pod $POD -o jsonpath='{.spec.containers[0].resources.limits.memory}')
echo "ℹ️  Resources: requests=$REQUESTS_MEM, limits=$LIMITS_MEM"

# Show last few log lines for context
echo ""
echo "📝 Recent server logs:"
kubectl logs $POD --tail=10 | sed 's/^/   /'

echo ""
echo "✅ All validation checks passed!"
