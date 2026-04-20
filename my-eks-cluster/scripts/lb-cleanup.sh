#!/usr/bin/env bash
################################################################################
# lb-cleanup.sh
#
# Cleans up AWS resources created by the AWS Load Balancer Controller:
#   1. Deletes all Kubernetes Ingress resources (lets the controller remove AWS resources)
#   2. Waits for the controller to finish cleanup
#   3. Sweeps for orphaned AWS resources by tag (ALBs, target groups, security groups)
#
# Usage:
#   ./lb-cleanup.sh                          # uses defaults
#   ./lb-cleanup.sh --tag Project=eks-playground --namespace default
################################################################################
set -euo pipefail

# ---------- defaults ----------
TAG_KEY="Project"
TAG_VALUE="eks-playground"
NAMESPACE="default"
WAIT_SECONDS=60
DRY_RUN=false

# ---------- parse flags ----------
while [[ $# -gt 0 ]]; do
  case $1 in
    --tag)
      TAG_KEY="${2%%=*}"
      TAG_VALUE="${2#*=}"
      shift 2 ;;
    --namespace)
      NAMESPACE="$2"
      shift 2 ;;
    --wait)
      WAIT_SECONDS="$2"
      shift 2 ;;
    --dry-run)
      DRY_RUN=true
      shift ;;
    -h|--help)
      sed -n '2,/^##*$/p' "$0" | head -n -1
      exit 0 ;;
    *)
      echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# ---------- helpers ----------
info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }

run_or_dry() {
  if $DRY_RUN; then
    warn "DRY-RUN: $*"
  else
    eval "$@"
  fi
}

check_deps() {
  for cmd in aws kubectl jq; do
    if ! command -v "$cmd" &>/dev/null; then
      error "$cmd is required but not installed."
      exit 1
    fi
  done
}

# ---------- step 1: delete K8s Ingress resources ----------
delete_ingresses() {
  info "Fetching Ingress resources in namespace '$NAMESPACE' with ingressClassName=alb ..."

  local ingresses
  ingresses=$(kubectl get ingress -n "$NAMESPACE" -o json \
    | jq -r '.items[] | select(.spec.ingressClassName == "alb") | .metadata.name')

  if [[ -z "$ingresses" ]]; then
    info "No ALB Ingress resources found in namespace '$NAMESPACE'."
    return
  fi

  echo "$ingresses" | while read -r name; do
    info "Deleting Ingress: $name"
    run_or_dry "kubectl delete ingress '$name' -n '$NAMESPACE'"
  done

  ok "All ALB Ingress resources deleted from namespace '$NAMESPACE'."
}

# ---------- step 2: wait for LB controller to reconcile ----------
wait_for_controller() {
  info "Waiting ${WAIT_SECONDS}s for the AWS LB Controller to clean up AWS resources ..."
  sleep "$WAIT_SECONDS"
}

# ---------- step 3: find and delete orphaned ALBs ----------
cleanup_load_balancers() {
  info "Searching for ALBs tagged ${TAG_KEY}=${TAG_VALUE} ..."

  local alb_arns
  alb_arns=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerArn' --output json \
    | jq -r '.[]')

  if [[ -z "$alb_arns" ]]; then
    info "No load balancers found."
    return
  fi

  for arn in $alb_arns; do
    local tags
    tags=$(aws elbv2 describe-tags --resource-arns "$arn" --output json)
    local match
    match=$(echo "$tags" | jq -r \
      --arg key "$TAG_KEY" --arg val "$TAG_VALUE" \
      '.TagDescriptions[0].Tags[] | select(.Key == $key and .Value == $val) | .Key')

    if [[ -n "$match" ]]; then
      local name
      name=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "$arn" \
        --query 'LoadBalancers[0].LoadBalancerName' --output text)
      warn "Found orphaned ALB: $name ($arn)"

      # delete listeners first
      local listener_arns
      listener_arns=$(aws elbv2 describe-listeners --load-balancer-arn "$arn" \
        --query 'Listeners[].ListenerArn' --output text)
      for l_arn in $listener_arns; do
        info "  Deleting listener: $l_arn"
        run_or_dry "aws elbv2 delete-listener --listener-arn '$l_arn'"
      done

      info "  Deleting ALB: $name"
      run_or_dry "aws elbv2 delete-load-balancer --load-balancer-arn '$arn'"
    fi
  done
}

# ---------- step 4: find and delete orphaned target groups ----------
cleanup_target_groups() {
  info "Searching for target groups tagged ${TAG_KEY}=${TAG_VALUE} ..."

  local tg_arns
  tg_arns=$(aws elbv2 describe-target-groups --query 'TargetGroups[].TargetGroupArn' --output json \
    | jq -r '.[]')

  if [[ -z "$tg_arns" ]]; then
    info "No target groups found."
    return
  fi

  for arn in $tg_arns; do
    local tags
    tags=$(aws elbv2 describe-tags --resource-arns "$arn" --output json)
    local match
    match=$(echo "$tags" | jq -r \
      --arg key "$TAG_KEY" --arg val "$TAG_VALUE" \
      '.TagDescriptions[0].Tags[] | select(.Key == $key and .Value == $val) | .Key')

    if [[ -n "$match" ]]; then
      local name
      name=$(echo "$tags" | jq -r '.TagDescriptions[0].Tags[] | select(.Key == "ingress.k8s.aws/resource") | .Value // "unknown"')
      warn "Found orphaned target group: $arn (resource: $name)"
      info "  Deleting target group ..."
      run_or_dry "aws elbv2 delete-target-group --target-group-arn '$arn'"
    fi
  done
}

# ---------- step 5: find and delete orphaned security groups ----------
cleanup_security_groups() {
  info "Searching for security groups tagged ${TAG_KEY}=${TAG_VALUE} ..."

  local sg_ids
  sg_ids=$(aws ec2 describe-security-groups \
    --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
    --query 'SecurityGroups[].GroupId' --output text)

  if [[ -z "$sg_ids" ]]; then
    info "No tagged security groups found."
    return
  fi

  for sg_id in $sg_ids; do
    local sg_name
    sg_name=$(aws ec2 describe-security-groups --group-ids "$sg_id" \
      --query 'SecurityGroups[0].GroupName' --output text)
    warn "Found orphaned security group: $sg_name ($sg_id)"

    # revoke all ingress/egress rules first so we can delete
    local ingress_rules
    ingress_rules=$(aws ec2 describe-security-groups --group-ids "$sg_id" \
      --query 'SecurityGroups[0].IpPermissions' --output json)
    if [[ "$ingress_rules" != "[]" ]]; then
      info "  Revoking ingress rules ..."
      run_or_dry "aws ec2 revoke-security-group-ingress --group-id '$sg_id' --ip-permissions '$ingress_rules'"
    fi

    local egress_rules
    egress_rules=$(aws ec2 describe-security-groups --group-ids "$sg_id" \
      --query 'SecurityGroups[0].IpPermissionsEgress' --output json)
    if [[ "$egress_rules" != "[]" ]]; then
      info "  Revoking egress rules ..."
      run_or_dry "aws ec2 revoke-security-group-egress --group-id '$sg_id' --ip-permissions '$egress_rules'"
    fi

    info "  Deleting security group: $sg_name"
    run_or_dry "aws ec2 delete-security-group --group-id '$sg_id'"
  done
}

# ---------- main ----------
main() {
  echo ""
  echo "============================================"
  echo "  AWS Load Balancer Controller — Cleanup"
  echo "============================================"
  echo "  Tag filter : ${TAG_KEY}=${TAG_VALUE}"
  echo "  Namespace  : ${NAMESPACE}"
  echo "  Dry run    : ${DRY_RUN}"
  echo "============================================"
  echo ""

  check_deps

  delete_ingresses
  wait_for_controller
  cleanup_load_balancers
  cleanup_target_groups
  cleanup_security_groups

  echo ""
  ok "Cleanup complete."
}

main
