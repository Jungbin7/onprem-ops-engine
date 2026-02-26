#!/bin/bash
# 전체 인프라 상태 확인 스크립트

KEY_DIR=~/.vagrant-keys

echo "=========================================="
echo "   전체 인프라 상태 점검"
echo "=========================================="

echo ""
echo "=== [BRAIN] k3s 클러스터 노드 상태 ==="
ssh -i ${KEY_DIR}/brain_key -o StrictHostKeyChecking=no -o ConnectTimeout=10 vagrant@192.168.174.10 \
  "sudo k3s kubectl get nodes -o wide" 2>/dev/null || echo "BRAIN 연결 실패"

echo ""
echo "=== [BRAIN] K8s 파드 상태 ==="
ssh -i ${KEY_DIR}/brain_key -o StrictHostKeyChecking=no vagrant@192.168.174.10 \
  "sudo k3s kubectl get pods -A 2>/dev/null" 2>/dev/null

echo ""
echo "=== [BRAIN] 서비스 상태 (k3s / neo4j / ollama) ==="
ssh -i ${KEY_DIR}/brain_key -o StrictHostKeyChecking=no vagrant@192.168.174.10 \
  "for s in k3s neo4j ollama; do printf \"%-10s: %s\n\" \"\$s\" \"\$(sudo systemctl is-active \$s)\"; done" 2>/dev/null

echo ""
echo "=== [BODY] k3s-agent 상태 ==="
ssh -i ${KEY_DIR}/body_key -o StrictHostKeyChecking=no -o ConnectTimeout=10 vagrant@192.168.174.20 \
  "for s in k3s-agent k6; do printf \"%-10s: %s\n\" \"\$s\" \"\$(sudo systemctl is-active \$s 2>/dev/null || echo not-installed)\"; done" 2>/dev/null || echo "BODY 연결 실패"

echo ""
echo "=== [BODY2] k3s-agent 상태 ==="
ssh -i ${KEY_DIR}/body2_key -o StrictHostKeyChecking=no -o ConnectTimeout=10 vagrant@192.168.174.21 \
  "for s in k3s-agent; do printf \"%-10s: %s\n\" \"\$s\" \"\$(sudo systemctl is-active \$s 2>/dev/null || echo not-installed)\"; done" 2>/dev/null || echo "BODY2 연결 실패"

echo ""
echo "=== [MEMORY] 모니터링 서비스 상태 ==="
ssh -i ${KEY_DIR}/memory_key -o StrictHostKeyChecking=no -o ConnectTimeout=10 vagrant@192.168.174.30 \
  "for s in prometheus grafana-server; do printf \"%-15s: %s\n\" \"\$s\" \"\$(sudo systemctl is-active \$s 2>/dev/null)\"; done && curl -s http://localhost:9090/-/ready 2>/dev/null && echo '(Prometheus OK)' && curl -s http://localhost:3000/api/health 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(\"Grafana:\",d.get(\"database\",\"?\"))' 2>/dev/null" 2>/dev/null || echo "MEMORY 연결 실패"

echo ""
echo "=== [SHIELD] PQC 서비스 상태 ==="
ssh -i ${KEY_DIR}/shield_key -o StrictHostKeyChecking=no -o ConnectTimeout=10 vagrant@192.168.174.40 \
  "sudo ldconfig 2>/dev/null; ls /usr/local/lib/liboqs.so 2>/dev/null && echo 'liboqs: 설치됨' || echo 'liboqs: 미설치'; ls /opt/pqc_demo 2>/dev/null && echo 'pqc_demo: 빌드됨' || echo 'pqc_demo: 미빌드'; sudo /opt/pqc_demo 2>/dev/null | grep -i 'success\|SUCCESS' | head -2" 2>/dev/null || echo "SHIELD 연결 실패"

echo ""
echo "=========================================="
echo "   점검 완료"
echo "=========================================="
