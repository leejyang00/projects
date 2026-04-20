#!/usr/bin/env bash
################################################################################
# test-routing.sh
#
# Tests all services through both Ingress ALB and Gateway API ALB.
# Validates host-based routing, content correctness, and response times.
#
# Usage:
#   ./test-routing.sh              # Test both Ingress and Gateway
#   ./test-routing.sh ingress      # Test Ingress only
#   ./test-routing.sh gateway      # Test Gateway only
################################################################################
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail()   { echo -e "  ${RED}✗${NC} $1"; FAILURES=$((FAILURES + 1)); }
info()   { echo -e "  ${YELLOW}►${NC} $1"; }
header() { echo -e "\n${CYAN}${BOLD}═══ $1 ═══${NC}"; }

FAILURES=0
MODE="${1:-all}"
TIMEOUT=10
AWS_REGION="ap-southeast-2"

################################################################################
# Helper: test a single HTTP request
#   test_request <description> <url> <host_header> <expected_code> <content_match>
################################################################################
test_request() {
  local desc="$1"
  local url="$2"
  local host="$3"
  local expected_code="$4"
  local content_match="${5:-}"

  local curl_args=(-s -m "$TIMEOUT" -w "\n%{http_code} %{time_total}")
  [[ -n "$host" ]] && curl_args+=(-H "Host: $host")

  local response
  response=$(curl "${curl_args[@]}" "$url" 2>/dev/null || echo -e "\n000 0")

  local body
  body=$(echo "$response" | sed '$d')
  local status_line
  status_line=$(echo "$response" | tail -1)
  local code
  code=$(echo "$status_line" | awk '{print $1}')
  local time
  time=$(echo "$status_line" | awk '{print $2}')

  if [[ "$code" == "$expected_code" ]]; then
    if [[ -n "$content_match" ]]; then
      if echo "$body" | grep -qi "$content_match"; then
        pass "$desc → ${code} (${time}s) ✓ content match"
      else
        fail "$desc → ${code} (${time}s) ✗ expected content '$content_match' not found"
      fi
    else
      pass "$desc → ${code} (${time}s)"
    fi
  else
    fail "$desc → ${code} (expected ${expected_code}, took ${time}s)"
  fi
}

################################################################################
# Helper: test load distribution across pods
################################################################################
test_load_distribution() {
  local url="$1"
  local host="$2"
  local hits=20

  info "Sending $hits requests to check load distribution..."

  local success=0
  local fail_count=0
  for i in $(seq 1 $hits); do
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" -m "$TIMEOUT" -H "Host: $host" "$url" 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
      success=$((success + 1))
    else
      fail_count=$((fail_count + 1))
    fi
  done

  if [[ "$fail_count" -eq 0 ]]; then
    pass "All $hits requests returned 200"
  else
    fail "$fail_count of $hits requests failed"
  fi
}

################################################################################
# Helper: check target group health via AWS CLI
################################################################################
check_target_health() {
  local alb_name="$1"
  local label="$2"

  local alb_arn
  alb_arn=$(aws elbv2 describe-load-balancers \
    --region "$AWS_REGION" \
    --query "LoadBalancers[?DNSName=='${alb_name}'].LoadBalancerArn | [0]" \
    --output text 2>/dev/null || echo "")

  if [[ -z "$alb_arn" || "$alb_arn" == "None" ]]; then
    fail "$label: ALB '$alb_name' not found"
    return
  fi

  local tg_arns
  tg_arns=$(aws elbv2 describe-target-groups \
    --region "$AWS_REGION" \
    --load-balancer-arn "$alb_arn" \
    --query 'TargetGroups[*].TargetGroupArn' \
    --output text 2>/dev/null || echo "")

  if [[ -z "$tg_arns" ]]; then
    fail "$label: No target groups found"
    return
  fi

  for tg_arn in $tg_arns; do
    local tg_name
    tg_name=$(aws elbv2 describe-target-groups \
      --region "$AWS_REGION" \
      --target-group-arns "$tg_arn" \
      --query 'TargetGroups[0].TargetGroupName' \
      --output text 2>/dev/null)

    local healthy
    healthy=$(aws elbv2 describe-target-health \
      --region "$AWS_REGION" \
      --target-group-arn "$tg_arn" \
      --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
      --output text 2>/dev/null || echo "0")

    local total
    total=$(aws elbv2 describe-target-health \
      --region "$AWS_REGION" \
      --target-group-arn "$tg_arn" \
      --query 'TargetHealthDescriptions | length(@)' \
      --output text 2>/dev/null || echo "0")

    if [[ "$healthy" -eq "$total" && "$total" -gt 0 ]]; then
      pass "Target group $tg_name: $healthy/$total healthy"
    else
      fail "Target group $tg_name: $healthy/$total healthy"
    fi
  done
}

################################################################################
# Kubernetes health checks
################################################################################
test_k8s_health() {
  header "Kubernetes Health"

  # Pods
  for app in website echo nginx; do
    local ready
    ready=$(kubectl get pods -l app="$app" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    local total
    total=$(kubectl get pods -l app="$app" --no-headers 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$ready" -gt 0 && "$ready" -eq "$total" ]]; then
      pass "Pods app=$app: $ready/$total Running"
    else
      fail "Pods app=$app: $ready/$total Running"
    fi
  done

  # Services have endpoints
  for svc in website echo nginx; do
    local endpoints
    endpoints=$(kubectl get endpoints "$svc" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
    if [[ -n "$endpoints" && "$endpoints" != "null" ]]; then
      pass "Service $svc has endpoints"
    else
      fail "Service $svc has no endpoints"
    fi
  done
}

################################################################################
# Test Ingress ALB
################################################################################
test_ingress() {
  header "Ingress ALB"

  local alb_dns
  alb_dns=$(kubectl get ingress website -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

  if [[ -z "$alb_dns" ]]; then
    info "No Ingress ALB found — skipping (Ingresses may have been deleted)"
    return
  fi

  echo -e "  ALB: ${BOLD}$alb_dns${NC}"

  # Target group health
  info "Checking target group health..."
  check_target_health "$alb_dns" "Ingress"

  # Host-based routing
  info "Testing host-based routing..."
  test_request "www.eks-playground.com /" \
    "http://$alb_dns/" "www.eks-playground.com" "200" "EKS Playground"

  test_request "echo.eks-playground.com /" \
    "http://$alb_dns/" "echo.eks-playground.com" "200"

  test_request "nginx.eks-playground.com /" \
    "http://$alb_dns/" "nginx.eks-playground.com" "200"

  # Unknown host should 404
  test_request "unknown host → 404" \
    "http://$alb_dns/" "unknown.example.com" "404"

  # Load distribution
  test_load_distribution "http://$alb_dns/" "www.eks-playground.com"
}

################################################################################
# Test Gateway API ALB
################################################################################
test_gateway() {
  header "Gateway API ALB"

  # Check GatewayClass
  if kubectl get gatewayclass alb-gatewayclass &>/dev/null; then
    pass "GatewayClass exists"
  else
    fail "GatewayClass not found"
    return
  fi

  # Check Gateway status
  local gw_accepted
  gw_accepted=$(kubectl get gateway my-alb-gateway \
    -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "")
  local gw_programmed
  gw_programmed=$(kubectl get gateway my-alb-gateway \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "")

  if [[ "$gw_accepted" == "True" ]]; then
    pass "Gateway accepted"
  else
    fail "Gateway not accepted"
  fi

  if [[ "$gw_programmed" == "True" ]]; then
    pass "Gateway programmed (ALB provisioned)"
  else
    fail "Gateway not programmed"
  fi

  local alb_dns
  alb_dns=$(kubectl get gateway my-alb-gateway \
    -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")

  if [[ -z "$alb_dns" ]]; then
    fail "Gateway has no address — cannot test traffic"
    return
  fi

  echo -e "  ALB: ${BOLD}$alb_dns${NC}"

  # Check HTTPRoutes
  info "Checking HTTPRoute status..."
  for route in $(kubectl get httproutes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    local accepted
    accepted=$(kubectl get httproute "$route" \
      -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "")
    if [[ "$accepted" == "True" ]]; then
      pass "HTTPRoute '$route' accepted"
    else
      fail "HTTPRoute '$route' not accepted"
    fi
  done

  # Target group health
  info "Checking target group health..."
  local alb_name
  alb_name=$(echo "$alb_dns" | cut -d'.' -f1 | sed 's/-.*//' | head -c 32)
  # Get ALB name from ARN since DNS parsing is fragile
  local alb_arn
  alb_arn=$(kubectl get gateway my-alb-gateway \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].message}' 2>/dev/null || echo "")

  if [[ -n "$alb_arn" && "$alb_arn" == arn:* ]]; then
    local tg_arns
    tg_arns=$(aws elbv2 describe-target-groups \
      --region "$AWS_REGION" \
      --load-balancer-arn "$alb_arn" \
      --query 'TargetGroups[*].TargetGroupArn' \
      --output text 2>/dev/null || echo "")

    for tg_arn in $tg_arns; do
      local tg_name
      tg_name=$(aws elbv2 describe-target-groups \
        --region "$AWS_REGION" \
        --target-group-arns "$tg_arn" \
        --query 'TargetGroups[0].TargetGroupName' \
        --output text 2>/dev/null)

      local healthy
      healthy=$(aws elbv2 describe-target-health \
        --region "$AWS_REGION" \
        --target-group-arn "$tg_arn" \
        --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
        --output text 2>/dev/null || echo "0")

      local total
      total=$(aws elbv2 describe-target-health \
        --region "$AWS_REGION" \
        --target-group-arn "$tg_arn" \
        --query 'TargetHealthDescriptions | length(@)' \
        --output text 2>/dev/null || echo "0")

      if [[ "$healthy" -eq "$total" && "$total" -gt 0 ]]; then
        pass "Target group $tg_name: $healthy/$total healthy"
      else
        fail "Target group $tg_name: $healthy/$total healthy"
      fi
    done
  else
    info "Could not extract ALB ARN — skipping target health check"
  fi

  # Host-based routing
  info "Testing host-based routing..."
  test_request "www.eks-playground.com /" \
    "http://$alb_dns/" "www.eks-playground.com" "200" "EKS Playground"

  test_request "echo.eks-playground.com /" \
    "http://$alb_dns/" "echo.eks-playground.com" "200"

  test_request "nginx.eks-playground.com /" \
    "http://$alb_dns/" "nginx.eks-playground.com" "200"

  # Unknown host should 404
  test_request "unknown host → 404" \
    "http://$alb_dns/" "unknown.example.com" "404"

  # Load distribution
  test_load_distribution "http://$alb_dns/" "www.eks-playground.com"
}

################################################################################
# Side-by-side comparison
################################################################################
test_comparison() {
  local ingress_dns
  ingress_dns=$(kubectl get ingress website -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  local gateway_dns
  gateway_dns=$(kubectl get gateway my-alb-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")

  if [[ -n "$ingress_dns" && -n "$gateway_dns" ]]; then
    header "Side-by-Side Comparison"

    echo -e "  Ingress ALB: $ingress_dns"
    echo -e "  Gateway ALB: $gateway_dns"
    echo ""

    for host in www.eks-playground.com echo.eks-playground.com nginx.eks-playground.com; do
      local ingress_code
      ingress_code=$(curl -s -o /dev/null -w "%{http_code}" -m "$TIMEOUT" -H "Host: $host" "http://$ingress_dns/" 2>/dev/null || echo "000")
      local ingress_time
      ingress_time=$(curl -s -o /dev/null -w "%{time_total}" -m "$TIMEOUT" -H "Host: $host" "http://$ingress_dns/" 2>/dev/null || echo "0")

      local gateway_code
      gateway_code=$(curl -s -o /dev/null -w "%{http_code}" -m "$TIMEOUT" -H "Host: $host" "http://$gateway_dns/" 2>/dev/null || echo "000")
      local gateway_time
      gateway_time=$(curl -s -o /dev/null -w "%{time_total}" -m "$TIMEOUT" -H "Host: $host" "http://$gateway_dns/" 2>/dev/null || echo "0")

      echo -e "  ${BOLD}$host${NC}"
      echo -e "    Ingress: ${ingress_code} (${ingress_time}s) | Gateway: ${gateway_code} (${gateway_time}s)"
    done
  fi
}

################################################################################
# Main
################################################################################
echo -e "${BOLD}EKS Playground — Routing Test${NC}"
echo "Mode: $MODE"
echo "Timeout: ${TIMEOUT}s"

test_k8s_health

case "$MODE" in
  ingress)
    test_ingress
    ;;
  gateway)
    test_gateway
    ;;
  all)
    test_ingress
    test_gateway
    test_comparison
    ;;
  *)
    echo "Usage: $0 [ingress|gateway|all]"
    exit 1
    ;;
esac

# Summary
header "Summary"
if [[ "$FAILURES" -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}All checks passed${NC}"
else
  echo -e "  ${RED}${BOLD}$FAILURES check(s) failed${NC}"
  exit 1
fi