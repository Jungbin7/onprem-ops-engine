#!/bin/bash
# 병렬 curl로 HPA 스케일링 트리거 시도 (k6 미설치 대안)
echo "=== 병렬 curl 부하 테스트 (30초) ==="
echo "HPA 트리거 목표: CPU 70% (100m request 기준 = 70m 필요)"

# 50개 병렬 curl 요청 30초간
END=$((SECONDS + 30))
while [ $SECONDS -lt $END ]; do
  for i in $(seq 1 50); do
    curl -s -X POST http://192.168.174.20:30080/orders \
      -H "Content-Type: application/json" \
      -d "{\"product_id\":$((RANDOM % 5 + 1)), \"quantity\":1, \"customer_email\":\"load${i}@test.com\"}" \
      -o /dev/null &
  done
  wait
done

echo "=== 부하 완료, HPA 상태 체크 ==="
