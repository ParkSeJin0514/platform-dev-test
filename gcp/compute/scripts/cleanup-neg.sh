#!/bin/bash
# ============================================================================
# NEG Cleanup Script
# ============================================================================
# GKE destroy 전에 Load Balancer 백엔드 서비스에서 NEG 제거 후 NEG 삭제
# 사용법: ./cleanup-neg.sh <project_id>
# ============================================================================

set -e

PROJECT_ID="${1:-kdt2-final-project-t1}"
BACKEND_SERVICE="petclinic-gke-backend"
ZONES=("asia-northeast3-a" "asia-northeast3-b" "asia-northeast3-c")

echo "============================================"
echo "NEG Cleanup Script"
echo "Project: ${PROJECT_ID}"
echo "Backend Service: ${BACKEND_SERVICE}"
echo "============================================"

# 1. 백엔드 서비스에서 NEG 제거
echo ""
echo "[1/2] Removing NEGs from backend service..."

# 현재 백엔드 서비스에 연결된 NEG 목록 확인
BACKENDS=$(gcloud compute backend-services describe ${BACKEND_SERVICE} \
  --global \
  --project=${PROJECT_ID} \
  --format="json" 2>/dev/null | jq -r '.backends[].group // empty' 2>/dev/null || echo "")

if [ -z "$BACKENDS" ]; then
  echo "No backends found in ${BACKEND_SERVICE} or backend service does not exist."
else
  echo "Found backends:"
  echo "$BACKENDS"

  # 각 백엔드(NEG) 제거
  for backend in $BACKENDS; do
    echo "Removing backend: ${backend}"
    gcloud compute backend-services remove-backend ${BACKEND_SERVICE} \
      --global \
      --network-endpoint-group="${backend}" \
      --project=${PROJECT_ID} \
      --quiet 2>/dev/null || echo "  - Already removed or not found"
  done
fi

# 2. petclinic 관련 NEG 삭제
echo ""
echo "[2/2] Deleting petclinic NEGs..."

for zone in "${ZONES[@]}"; do
  echo "Checking zone: ${zone}"

  # 해당 존의 petclinic 관련 NEG 목록
  NEGS=$(gcloud compute network-endpoint-groups list \
    --filter="name~petclinic AND zone:${zone}" \
    --format="value(name)" \
    --project=${PROJECT_ID} 2>/dev/null || echo "")

  if [ -z "$NEGS" ]; then
    echo "  - No petclinic NEGs found in ${zone}"
  else
    for neg in $NEGS; do
      echo "  - Deleting NEG: ${neg}"
      gcloud compute network-endpoint-groups delete ${neg} \
        --zone=${zone} \
        --project=${PROJECT_ID} \
        --quiet 2>/dev/null || echo "    Failed to delete ${neg} (may be in use)"
    done
  fi
done

echo ""
echo "============================================"
echo "NEG cleanup completed!"
echo "============================================"
