#!/bin/bash
# ============================================================
# k6 수동 설치 스크립트 (body2 노드 대상)
# 실행: wsl에서 bash scripts/install-k6-body2.sh
# ============================================================

BODY2_KEY=~/.vagrant-keys/body2_key
BODY2_IP=192.168.174.21

echo "=== k6 설치 시작 (body2: $BODY2_IP) ==="

ssh -i $BODY2_KEY -o StrictHostKeyChecking=no vagrant@$BODY2_IP << 'EOF'
  echo "[1/4] GPG 키 등록..."
  sudo gpg --no-default-keyring \
    --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
    --keyserver hkp://keyserver.ubuntu.com:80 \
    --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69

  echo "[2/4] apt 소스 추가..."
  echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
    | sudo tee /etc/apt/sources.list.d/k6.list

  echo "[3/4] apt 업데이트 & 설치..."
  sudo apt-get update -qq && sudo apt-get install -y k6

  echo "[4/4] 설치 확인..."
  k6 version && echo "✅ k6 설치 성공"
EOF

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ k6 설치 완료!"
  echo "   다음 단계: bash scripts/run-k6-hpa-test.sh"
else
  echo ""
  echo "❌ k6 설치 실패 — 수동 확인 필요"
  echo "   vagrant ssh body2"
  echo "   sudo apt-get update && sudo apt-get install -y k6"
fi
