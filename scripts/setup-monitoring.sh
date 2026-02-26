#!/bin/bash
# =============================================================================
# setup-monitoring.sh — Prometheus + Grafana 자동 설정 스크립트
# =============================================================================
# [목적]
#   1. memory 노드(192.168.174.30)의 Prometheus에 FastAPI 스크레이프 타겟 추가
#   2. Grafana API로 Prometheus 데이터소스 자동 설정
#   3. 대시보드 JSON 자동 import
#
# [Prometheus Pull 방식 선택 이유]
#   - Pull: Prometheus가 타겟을 주기적으로 스크레이프 → 서버가 부하 제어 주도권 가짐
#   - Push(Pushgateway) 방식 대비: 배치 잡이 아닌 상시 서비스에는 Pull이 적합
#   - 타겟 장애 시 Prometheus가 자동으로 "down" 감지
#
# 사용법: wsl bash /mnt/c/project/onprem-ops-engine/scripts/setup-monitoring.sh
# =============================================================================
set -euo pipefail

# ── 변수 설정 ─────────────────────────────────────────────────────────────────
MEMORY_IP="192.168.174.30"
BRAIN_IP="192.168.174.10"
BODY_IP="192.168.174.20"
BODY2_IP="192.168.174.21"
SHIELD_IP="192.168.174.40"

GRAFANA_URL="http://${MEMORY_IP}:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
PROMETHEUS_URL="http://${MEMORY_IP}:9090"

KEY_MEMORY=".vagrant/machines/memory/vmware_desktop/private_key"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

echo "=========================================="
echo "   Monitoring Setup — onprem-ops-engine"
echo "=========================================="

# ── Step 1: Prometheus 타겟 설정 업데이트 ──────────────────────────────────
echo ""
echo "[1/4] Prometheus 스크레이프 타겟 업데이트..."

# [scrape_interval: 15s 선택 이유]
#   - 1초: Prometheus 메모리 과다 사용. 60초: 이벤트 반응 너무 느림
#   - 15초: Kubernetes API server 기본값. HPA 반응 주기(30s)의 절반 → 충분한 해상도

ssh -i "${KEY_MEMORY}" ${SSH_OPTS} vagrant@${MEMORY_IP} "sudo tee /etc/prometheus/prometheus.yml > /dev/null" << 'PROMEOF'
# =============================================================================
# Prometheus Configuration
# [global scrape_interval: 15s 이유]
#   HPA stabilization window(30s)의 절반 해상도. 메트릭 손실 없이 이벤트 포착 가능
# =============================================================================
global:
  scrape_interval:     15s   # 기본 스크레이프 주기
  evaluation_interval: 15s   # 알람 룰 평가 주기
  scrape_timeout:      10s   # 타임아웃 (15s 이하로 설정해야 함)

scrape_configs:
  # ── Self-monitoring ──────────────────────────────────────────────────────
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # ── FastAPI E-Commerce API ────────────────────────────────────────────────
  # [NodePort 30080 이유] k3s ServiceType=NodePort로 외부 노출된 포트
  # body, body2, brain 모두 타겟으로 등록 → 어느 노드에서 scrape해도 동일 메트릭
  - job_name: 'ecommerce-api'
    metrics_path: '/metrics'
    scrape_interval: 15s
    static_configs:
      - targets:
          - '192.168.174.10:30080'   # brain (NodePort)
          - '192.168.174.20:30080'   # body  (NodePort)
          - '192.168.174.21:30080'   # body2 (NodePort)
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance

  # ── Node Exporter (서버 시스템 메트릭) ──────────────────────────────────
  # [Node Exporter 선택 이유]
  #   - CPU, Memory, Disk, Network 메트릭을 표준화된 형식으로 노출
  #   - HPA CPU 임계치(70%) 대비 실제 사용률을 Grafana에서 시각화
  - job_name: 'node-exporter'
    static_configs:
      - targets:
          - '192.168.174.10:9100'   # brain
          - '192.168.174.20:9100'   # body
          - '192.168.174.21:9100'   # body2
          - '192.168.174.30:9100'   # memory
    labels:
      group: 'k3s-cluster'

  # ── Kubernetes API / k3s 메트릭 ─────────────────────────────────────────
  - job_name: 'k3s-metrics'
    static_configs:
      - targets: ['192.168.174.10:10249']   # kube-proxy metrics
PROMEOF

echo "   ✅ prometheus.yml 업데이트 완료"

# Prometheus reload (SIGHUP으로 무중단 설정 리로드)
ssh -i "${KEY_MEMORY}" ${SSH_OPTS} vagrant@${MEMORY_IP} \
    "sudo systemctl reload prometheus 2>/dev/null || sudo killall -HUP prometheus 2>/dev/null || true"
echo "   ✅ Prometheus 설정 리로드 완료"

# ── Step 2: Node Exporter 설치 확인 ────────────────────────────────────────
echo ""
echo "[2/4] Node Exporter 상태 확인..."

for IP in "${BRAIN_IP}" "${BODY_IP}" "${BODY2_IP}"; do
    # brain/body/body2는 동일한 SSH 키 사용
    KEY_NODE=".vagrant/machines/brain/vmware_desktop/private_key"
    if [ "${IP}" = "${BODY_IP}" ]; then
        KEY_NODE=".vagrant/machines/body/vmware_desktop/private_key"
    elif [ "${IP}" = "${BODY2_IP}" ]; then
        KEY_NODE=".vagrant/machines/body2/vmware_desktop/private_key"
    fi

    STATUS=$(ssh -i "${KEY_NODE}" ${SSH_OPTS} vagrant@${IP} \
        "curl -s http://localhost:9100/metrics | grep -c 'node_cpu' || echo 0" 2>/dev/null || echo "0")
    if [ "${STATUS}" -gt 0 ] 2>/dev/null; then
        echo "   ✅ node-exporter @ ${IP}:9100 동작 중"
    else
        echo "   ⚠️  node-exporter @ ${IP}:9100 미동작 → 설치 필요"
        echo "      설치: ssh vagrant@${IP} 'wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz && tar xvf node_exporter*.tar.gz && sudo mv node_exporter-*/node_exporter /usr/local/bin/ && sudo nohup node_exporter &'"
    fi
done

# ── Step 3: Grafana 데이터소스 자동 설정 ───────────────────────────────────
echo ""
echo "[3/4] Grafana Prometheus 데이터소스 등록..."

sleep 3  # Prometheus reload 대기

# Grafana API로 데이터소스 생성
# [Grafana API 사용 이유]
#   - UI 수동 클릭 대비 재현 가능 자동화. IaC 원칙 준수
DATASOURCE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${GRAFANA_URL}/api/datasources" \
    -H "Content-Type: application/json" \
    -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://localhost:9090",
        "access": "proxy",
        "isDefault": true,
        "jsonData": {
            "timeInterval": "15s",
            "httpMethod": "POST"
        }
    }')

if [ "${DATASOURCE_RESPONSE}" = "200" ] || [ "${DATASOURCE_RESPONSE}" = "409" ]; then
    echo "   ✅ Grafana 데이터소스 설정 완료 (${DATASOURCE_RESPONSE})"
else
    echo "   ❌ 데이터소스 설정 실패 (HTTP ${DATASOURCE_RESPONSE})"
    echo "      Grafana가 ${GRAFANA_URL} 에서 응답하는지 확인하세요"
fi

# ── Step 4: Grafana 대시보드 Import ────────────────────────────────────────
echo ""
echo "[4/4] Grafana 대시보드 Import..."

DASHBOARD_JSON_PATH="${PROJECT_DIR}/grafana/dashboards/ecommerce-overview.json"

if [ ! -f "${DASHBOARD_JSON_PATH}" ]; then
    echo "   ❌ 대시보드 JSON 파일이 없습니다: ${DASHBOARD_JSON_PATH}"
    exit 1
fi

# JSON을 Grafana import API 형식으로 래핑
IMPORT_PAYLOAD=$(python3 -c "
import json, sys
dashboard = json.load(open('${DASHBOARD_JSON_PATH}'))
payload = {
    'dashboard': dashboard,
    'overwrite': True,
    'folderId': 0
}
print(json.dumps(payload))
")

IMPORT_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${GRAFANA_URL}/api/dashboards/import" \
    -H "Content-Type: application/json" \
    -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    -d "${IMPORT_PAYLOAD}")

if [ "${IMPORT_RESPONSE}" = "200" ]; then
    echo "   ✅ 대시보드 Import 완료"
else
    echo "   ⚠️  대시보드 Import 응답: HTTP ${IMPORT_RESPONSE}"
fi

# ── 결과 요약 ─────────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo "   ✅ 모니터링 설정 완료!"
echo "=========================================="
echo ""
echo "   📊 Grafana:     ${GRAFANA_URL}"
echo "   📈 Prometheus:  ${PROMETHEUS_URL}"
echo ""
echo "   로그인: admin / admin"
echo "   대시보드: 'E-Commerce Resilience Platform'"
echo ""
echo "   타겟 상태 확인:"
echo "   ${PROMETHEUS_URL}/api/v1/targets"
