#!/bin/bash
# ============================================================
# 복원력(Resilience) 테스트 스크립트
# - body 노드를 강제 종료 → Pod가 body2로 재스케줄 되는지 확인
# - 재확인 후 body 노드 복구
# 실행: wsl에서 bash scripts/resilience-test.sh
# ============================================================

BRAIN_KEY=~/.vagrant-keys/brain_key
BRAIN_IP=192.168.174.10

check_pods() {
  local label=$1
  echo "[$label] Pod 상태:"
  ssh -i $BRAIN_KEY -o StrictHostKeyChecking=no vagrant@$BRAIN_IP \
    "sudo k3s kubectl get pods -o wide | grep -E 'NAME|ecommerce|web-dashboard'"
  echo ""
  echo "[$label] HPA 상태:"
  ssh -i $BRAIN_KEY -o StrictHostKeyChecking=no vagrant@$BRAIN_IP \
    "sudo k3s kubectl get hpa ecommerce-api-hpa"
  echo ""
  echo "[$label] 노드 상태:"
  ssh -i $BRAIN_KEY -o StrictHostKeyChecking=no vagrant@$BRAIN_IP \
    "sudo k3s kubectl get nodes"
  echo "============================================"
}

echo "=== 복원력 테스트 시작 ==="
echo ""

# 1단계: 현재 상태 확인
echo "[STEP 1] body 노드 중단 전 상태 확인"
check_pods "BEFORE"

# 2단계: body 노드 강제 종료
echo "[STEP 2] body 노드(192.168.174.20) 종료 중..."
echo "   → Windows PowerShell에서: vagrant halt body"
echo ""
echo "   vagrant halt body가 완료될 때까지 대기 중... (30초)"
sleep 30

# 3단계: 재스케줄 확인 (1~2분 소요)
echo "[STEP 3] Pod 재스케줄 확인 (60초 대기 후)"
sleep 60
check_pods "1분후"

echo "[STEP 4] Pod 재스케줄 확인 (추가 60초 대기)"
sleep 60
check_pods "2분후"

# E2E 검증
echo "[STEP 5] 서비스 응답 확인 (NodePort: 192.168.174.10:30080)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.174.10:30080/health)
if [ "$HTTP_STATUS" = "200" ]; then
  echo "✅ /health 응답 정상 ($HTTP_STATUS) — 서비스 무중단 확인!"
else
  echo "❌ /health 응답 실패 ($HTTP_STATUS)"
fi

echo ""
echo "=== 복원력 테스트 완료 ==="
echo ""
echo "[STEP 6] body 노드 복구 필요:"
echo "   Windows PowerShell에서: vagrant up body"
echo "   복구 후 노드 재가입 확인:"
echo "   vagrant ssh brain -- sudo k3s kubectl get nodes"
