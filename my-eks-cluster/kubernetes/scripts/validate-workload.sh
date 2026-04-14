#!/usr/bin/env bash
################################################################################
# validate-workload.sh — Verify the nginx test deployment is fully healthy
#
# Usage: ./validate-workload.sh
#
# Checks:
#   1. Deployment rolled out successfully
#   2. All pods are Running and Ready
#   3. Service has endpoints (pods registered)
#   4. In-cluster DNS resolution works
#   5. Traffic flows through the Service to the pod
################################################################################
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No colour

pass() { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; }
info() { echo -e "${YELLOW}► $1${NC}"; }

FAILURES=0

# 1. Deployment rollout
info "Checking deployment rollout..."
if kubectl rollout status deployment/nginx --namespace=default --timeout=60s 2>/dev/null; then
  pass "Deployment nginx rolled out successfully"
else
  fail "Deployment nginx rollout failed or timed out"
  FAILURES=$((FAILURES + 1))
fi

# 2. Pod status
info "Checking pod status..."
NOT_READY=$(kubectl get pods -l app=nginx --namespace=default --no-headers 2>/dev/null | grep -v "Running" | wc -l || true)
TOTAL=$(kubectl get pods -l app=nginx --namespace=default --no-headers 2>/dev/null | wc -l || true)

if [[ "$TOTAL" -ge 2 && "$NOT_READY" -eq 0 ]]; then
  pass "All $TOTAL pods are Running"
else
  fail "$NOT_READY of $TOTAL pods are not Running"
  kubectl get pods -l app=nginx --namespace=default
  FAILURES=$((FAILURES + 1))
fi

# 3. Service endpoints
info "Checking service endpoints..."
ENDPOINTS=$(kubectl get endpoints nginx --namespace=default -o jsonpath='{.subsets[0].addresses}' 2>/dev/null)

if [[ -n "$ENDPOINTS" && "$ENDPOINTS" != "null" ]]; then
  ENDPOINT_COUNT=$(echo "$ENDPOINTS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  pass "Service has $ENDPOINT_COUNT endpoint(s)"
else
  fail "Service has no endpoints — selector may not match pod labels"
  FAILURES=$((FAILURES + 1))
fi

# 4. DNS resolution (from inside the cluster)
info "Checking in-cluster DNS resolution..."
DNS_RESULT=$(kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never \
  --timeout=30s -- nslookup nginx.default.svc.cluster.local 2>/dev/null || true)

if echo "$DNS_RESULT" | grep -q "Address"; then
  pass "CoreDNS resolves nginx.default.svc.cluster.local"
else
  fail "DNS resolution failed — CoreDNS may not be ready"
  FAILURES=$((FAILURES + 1))
fi

# 5. Traffic test (curl the service from inside the cluster)
#   --rm          : delete the pod automatically when it exits
#   -it           : -i keeps stdin open, -t allocates a tty (lets you see output in real time)
#   --restart=Never : one-shot pod, don't restart after it exits (default is Always)
#   --            : separates kubectl flags from the command run inside the container
#   wget -qO-     : -q quiet (no progress), -O- write response body to stdout instead of a file
info "Checking traffic through Service..."
HTTP_RESULT=$(kubectl run curl-test --image=busybox:1.36 --rm -it --restart=Never \
  --timeout=30s -- wget -qO- --timeout=5 http://nginx.default.svc.cluster.local 2>/dev/null || true)

if echo "$HTTP_RESULT" | grep -qi "nginx"; then
  pass "HTTP request through Service returned nginx response"
else
  fail "HTTP request through Service failed"
  FAILURES=$((FAILURES + 1))
fi

# Summary
echo ""
if [[ "$FAILURES" -eq 0 ]]; then
  pass "All checks passed — cluster networking is healthy"
else
  fail "$FAILURES check(s) failed"
  exit 1
fi
