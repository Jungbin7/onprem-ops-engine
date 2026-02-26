#!/bin/bash
# =============================================================================
# install-flux.sh — Flux CD 클러스터 설치 스크립트
# =============================================================================
# [Flux CD 선택 이유 → ADR-005.md 참조]
#
# 전제조건:
#   - k3s 클러스터 동작 중 (brain 노드가 마스터)
#   - KUBECONFIG가 brain 노드의 ~/.kube/config를 가리킴
#   - GitHub 레포가 공개(public)이거나 GITHUB_TOKEN 환경변수 설정됨
#
# 사용법:
#   export GITHUB_USER=Jungbin7
#   export GITHUB_REPO=onprem-ops-engine
#   wsl bash /mnt/c/project/onprem-ops-engine/scripts/install-flux.sh
# =============================================================================
set -euo pipefail

BRAIN_IP="192.168.174.10"
GITHUB_USER="${GITHUB_USER:-Jungbin7}"
GITHUB_REPO="${GITHUB_REPO:-onprem-ops-engine}"
KEY_BRAIN=".vagrant/machines/brain/vmware_desktop/private_key"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

echo "============================================"
echo "   Flux CD 설치 — onprem-ops-engine"
echo "============================================"
echo ""

# ── Step 1: flux CLI 설치 ────────────────────────────────────────────────────
echo "[1/4] flux CLI 설치..."
# [공식 install 스크립트 사용 이유]
#   - flux 버전 자동 감지 (최신 stable)
#   - /usr/local/bin에 자동 배치
ssh -i "${KEY_BRAIN}" ${SSH_OPTS} vagrant@${BRAIN_IP} "
    curl -s https://fluxcd.io/install.sh | sudo bash
    echo 'flux CLI 버전:'
    flux version --client
"
echo "   ✅ flux CLI 설치 완료"

# ── Step 2: pre-flight 체크 ──────────────────────────────────────────────────
echo ""
echo "[2/4] 클러스터 사전 검증 (flux check --pre)..."
# [flux check 이유]
#   - Kubernetes 버전, 권한, 네트워크 등 필수 조건 사전 확인
#   - 설치 실패 원인 조기 발견
ssh -i "${KEY_BRAIN}" ${SSH_OPTS} vagrant@${BRAIN_IP} "
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    sudo flux check --pre
"
echo "   ✅ pre-flight 체크 통과"

# ── Step 3: flux-system 네임스페이스에 컨트롤러 설치 ──────────────────────
echo ""
echo "[3/4] Flux CD 컨트롤러 설치..."
# [flux install 이유]
#   - Source, Kustomize, Helm, Notification 컨트롤러를 flux-system NS에 설치
#   - bootstrap과 달리 Git 연동 없이 컨트롤러만 설치 (레포 연결은 별도)
ssh -i "${KEY_BRAIN}" ${SSH_OPTS} vagrant@${BRAIN_IP} "
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    sudo flux install \
        --namespace=flux-system \
        --components=source-controller,kustomize-controller,helm-controller,notification-controller \
        --log-level=info
    
    echo 'Flux 컨트롤러 상태:'
    sudo kubectl get pods -n flux-system
"
echo "   ✅ Flux 컨트롤러 설치 완료"

# ── Step 4: GitRepository + Kustomization 적용 ─────────────────────────────
echo ""
echo "[4/4] GitRepository 및 Kustomization 리소스 적용..."

# flux 디렉토리를 brain 노드에 복사
scp -i "${KEY_BRAIN}" ${SSH_OPTS} -r \
    "$(dirname "$0")/../flux" \
    vagrant@${BRAIN_IP}:/tmp/flux-manifests/

ssh -i "${KEY_BRAIN}" ${SSH_OPTS} vagrant@${BRAIN_IP} "
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    
    # GitRepository 소스 등록
    sudo kubectl apply -f /tmp/flux-manifests/flux/sources/gitrepository.yaml
    
    # Kustomization 등록 (클러스터 레벨 → 앱 레벨)
    sudo kubectl apply -f /tmp/flux-manifests/flux/clusters/onprem/kustomization.yaml
    sudo kubectl apply -f /tmp/flux-manifests/flux/apps/ecommerce/kustomization.yaml
    
    echo ''
    echo 'Flux 동기화 상태:'
    sudo flux get sources git
    sudo flux get kustomizations
"

echo ""
echo "============================================"
echo "   ✅ Flux CD 설치 완료!"
echo "============================================"
echo ""
echo "   📡 Git 감시 레포: https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
echo "   🔄 동기화 주기: 1m (GitRepository), 5m (Kustomization)"
echo ""
echo "   상태 확인 명령어:"
echo "   ssh vagrant@${BRAIN_IP} 'sudo flux get all -A'"
echo ""
echo "   [ADR-005] GitOps Pull 방식:"
echo "   클러스터가 Git을 pull하므로 kubeconfig 외부 노출 없음"
