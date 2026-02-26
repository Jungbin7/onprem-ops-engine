#!/bin/bash
# 전체 K8s 매니페스트를 클러스터에 배포하는 스크립트

set -e
KEY=~/.vagrant-keys/brain_key
BRAIN=192.168.174.10

echo "=========================================="
echo "  K8s 앱 스택 배포 시작"
echo "=========================================="

# 매니페스트 디렉토리 생성
ssh -i $KEY -o StrictHostKeyChecking=no vagrant@$BRAIN "sudo mkdir -p /tmp/k8s-manifests"

# 매니페스트 디렉토리 통째로 전송
MANIFEST_DIR="/mnt/c/project/onprem-ops-engine/ansible/k8s-manifests"
ssh -i $KEY -o StrictHostKeyChecking=no vagrant@$BRAIN "sudo mkdir -p /tmp/k8s-manifests"
scp -i $KEY -o StrictHostKeyChecking=no "$MANIFEST_DIR"/*.yaml vagrant@$BRAIN:/tmp/k8s-manifests/ && echo "  ✓ 전체 매니페스트 전송 완료"

echo ""
echo "=== Redis 먼저 배포 ==="
ssh -i $KEY -o StrictHostKeyChecking=no vagrant@$BRAIN "sudo k3s kubectl apply -f /tmp/k8s-manifests/redis.yaml"

echo ""
echo "=== FastAPI 앱 배포 ==="
ssh -i $KEY -o StrictHostKeyChecking=no vagrant@$BRAIN "sudo k3s kubectl apply -f /tmp/k8s-manifests/ecommerce-app.yaml"

echo ""
echo "=== Service 배포 ==="
ssh -i $KEY -o StrictHostKeyChecking=no vagrant@$BRAIN "sudo k3s kubectl apply -f /tmp/k8s-manifests/service.yaml"

echo ""
echo "=== HPA 배포 ==="
ssh -i $KEY -o StrictHostKeyChecking=no vagrant@$BRAIN "sudo k3s kubectl apply -f /tmp/k8s-manifests/hpa.yaml"

echo ""
echo "=== PDB 배포 ==="
ssh -i $KEY -o StrictHostKeyChecking=no vagrant@$BRAIN "sudo k3s kubectl apply -f /tmp/k8s-manifests/pdb.yaml"

echo ""
echo "=== 30초 대기 후 상태 확인 ==="
sleep 30
ssh -i $KEY -o StrictHostKeyChecking=no vagrant@$BRAIN "
echo '--- Pods ---'
sudo k3s kubectl get pods -o wide
echo ''
echo '--- Services ---'
sudo k3s kubectl get svc
echo ''
echo '--- HPA ---'
sudo k3s kubectl get hpa
echo ''
echo '--- PDB ---'
sudo k3s kubectl get pdb
"

echo ""
echo "=========================================="
echo "  배포 완료!"
echo "  접속: http://192.168.174.20:30080"
echo "  또는: http://192.168.174.21:30080"
echo "=========================================="
