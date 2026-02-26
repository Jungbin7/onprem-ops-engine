#!/bin/bash
BODY2_KEY=~/.vagrant-keys/body2_key
BRAIN_KEY=~/.vagrant-keys/brain_key

echo "=== k6 부하 테스트 파일 body2로 전송 ==="
scp -i $BODY2_KEY -o StrictHostKeyChecking=no \
  /mnt/c/project/onprem-ops-engine/ansible/simulation/k6-stress-test.js \
  vagrant@192.168.174.21:/tmp/k6-stress-test.js && echo "전송 완료"

echo ""
echo "=== k6 실행 (3분 부하 테스트) ==="
ssh -i $BODY2_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.21 \
  "k6 run /tmp/k6-stress-test.js --no-color 2>&1" &

K6_PID=$!

echo ""
echo "=== HPA 모니터링 (15초 간격) ==="
for i in 1 2 3 4 5 6 7 8 9 10; do
  echo "--- [${i}분 체크] ---"
  ssh -i $BRAIN_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.10 \
    "sudo k3s kubectl get hpa ecommerce-api-hpa && sudo k3s kubectl get pods | grep ecommerce"
  sleep 30
done

wait $K6_PID
echo ""
echo "=== k6 테스트 완료 ==="
