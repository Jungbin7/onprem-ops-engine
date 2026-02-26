#!/bin/bash
BODY2_KEY=~/.vagrant-keys/body2_key
BRAIN_KEY=~/.vagrant-keys/brain_key

echo "=== k6 스크립트 body2 전송 ==="
scp -i $BODY2_KEY -o StrictHostKeyChecking=no \
  /mnt/c/project/onprem-ops-engine/ansible/simulation/k6-stress-test.js \
  vagrant@192.168.174.21:/tmp/k6-stress-test.js

echo "=== k6 nohup 실행 (body2에서 백그라운드) ==="
ssh -i $BODY2_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.21 \
  "nohup k6 run /tmp/k6-stress-test.js --no-color > /tmp/k6-result.txt 2>&1 &"
echo "k6 실행 시작됨"

echo ""
echo "=== 3분간 HPA 모니터링 (30초 간격) ==="
for i in 1 2 3 4 5 6; do
  sleep 30
  echo "--- ${i}번째 체크 (${i}*30초 후) ---"
  ssh -i $BRAIN_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.10 \
    "sudo k3s kubectl get hpa ecommerce-api-hpa --no-headers && sudo k3s kubectl get pods --no-headers | grep ecommerce | wc -l | xargs -I{} echo 'ecommerce pods: {}'"
done

echo ""
echo "=== k6 최종 결과 수집 ==="
sleep 10
ssh -i $BODY2_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.21 "cat /tmp/k6-result.txt 2>/dev/null || echo 'k6 아직 실행중'"

echo ""
echo "=== orders 최종 수 확인 ==="
curl -s http://192.168.174.20:30080/metrics/summary
