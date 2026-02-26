#!/bin/bash
# ============================================================
# Ansible Playbook 실행 스크립트
# 사전 처리: Vagrant SSH 키를 WSL 홈으로 복사하고 권한 설정
# ============================================================

set -e

PROJECT_DIR=/mnt/c/project/onprem-ops-engine
VAGRANT_DIR="$PROJECT_DIR/.vagrant/machines"
KEY_DIR=~/.vagrant-keys
NODES=(brain body body2 memory shield)

echo "=========================================="
echo "   SSH 키 준비 (WSL 권한 설정)"
echo "=========================================="

mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

for node in "${NODES[@]}"; do
  SRC_KEY="$VAGRANT_DIR/$node/vmware_desktop/private_key"
  DEST_KEY="$KEY_DIR/${node}_key"
  if [ -f "$SRC_KEY" ]; then
    cp "$SRC_KEY" "$DEST_KEY"
    chmod 600 "$DEST_KEY"
    echo "  ✓ $node 키 준비 완료: $DEST_KEY"
  else
    echo "  ✗ 경고: $node 키를 찾을 수 없음: $SRC_KEY"
  fi
done

echo ""
echo "=========================================="
echo "   Ansible Playbook 실행 시작..."
echo "=========================================="

cd "$PROJECT_DIR"

# 로그 초기화
> ansible.log

ansible-playbook -i ansible/inventory.yml ansible/playbook.yml -v 2>&1 | tee -a ansible.log

EXIT_CODE=${PIPESTATUS[0]}

echo "=========================================="
if [ $EXIT_CODE -eq 0 ]; then
  echo "   실행 완료! (성공)"
else
  echo "   실행 완료! (일부 오류 발생, 로그 확인 필요)"
fi
echo "=========================================="
echo "로그 파일: $PROJECT_DIR/ansible.log"
