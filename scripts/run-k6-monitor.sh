#!/bin/bash
BODY2_KEY=~/.vagrant-keys/body2_key
BRAIN_KEY=~/.vagrant-keys/brain_key

echo "=== k6 nohup 실행 ==="
ssh -i $BODY2_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.21 \
  "nohup k6 run /tmp/k6-stress-test.js --no-color > /tmp/k6-result.txt 2>&1 &"
echo "k6 시작됨 (3분 시나리오: 30s/20vu → 2m/100vu → 30s/0vu)"

echo ""
echo "=== HPA 모니터링 (30초 * 7회 = 3.5분) ==="
for i in 1 2 3 4 5 6 7; do
  sleep 30
  echo "--- [${i}번째 / $(( i * 30 ))초 후] ---"
  ssh -i $BRAIN_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.10 \
    "sudo k3s kubectl get hpa ecommerce-api-hpa --no-headers && sudo k3s kubectl get pods --no-headers | grep ecommerce | wc -l | xargs echo 'ecommerce pods:'"
done

echo ""
echo "=== k6 결과 확인 ==="
sleep 15
ssh -i $BODY2_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.21 "cat /tmp/k6-result.txt"

echo ""
echo "=== 최종 주문 수 확인 ==="
curl -s http://192.168.174.20:30080/metrics/summary
