# 🏗️ OnPrem Ops Engine — 아키텍처 & 프로젝트 현황

> **작성일**: 2026-02-25 | **진행률**: ~65%

---

## 🎯 프로젝트 목표

단일 서버 중심의 구조가 아닌, **멀티 노드 Kubernetes 클러스터** 환경에서
트래픽 급증 및 노드 장애 상황에서도 서비스가 지속 가능하도록 설계하고,
장애 발생 시 원인을 데이터 기반으로 분석할 수 있는 운영 플랫폼을 구축하는 것을 목표로 하였습니다.

특히 **온프레미스 환경에서도 클라우드 수준의 확장성과 복원력**을 구현하는 것을 핵심 목표로 설정하였습니다.

---

## 🖥️ 개발 환경

| 영역 | 기술 스택 |
|------|----------|
| 인프라 | VMware Desktop 기반 온프레미스 VM (Ubuntu 22.04) |
| 가상화 | Vagrant 2.4+, vmware_desktop Provider |
| 구성 관리 (IaC) | Ansible 2.16+ |
| 컨테이너 오케스트레이션 | k3s v1.29.2 (1 Control Plane + 2 Worker Node) |
| 데이터 계층 | PostgreSQL 16, Neo4j 5 |
| AI 분석 | Ollama + Llama2 (로컬 LLM 추론) |
| 부하 테스트 | k6 |
| 모니터링 | Prometheus v2.50.1, Grafana |
| 보안 | liboqs 기반 양자내성 암호화 (PQC) - CRYSTALS-Kyber |
| 네트워크 | VM 단위 역할 분리, 내부 전용 네트워크 (192.168.174.x) |

---

## 📐 아키텍처

총 **5대 VM**으로 멀티 노드 클러스터를 구성하였습니다.

```
[Windows 노트북]
│
│  Vagrant + VMware Desktop
│
├── brain   (192.168.174.10)  ← k3s Control Plane + Neo4j + Ollama
├── body    (192.168.174.20)  ← k3s Worker #1  (FastAPI Pod, Redis Pod 실행)
├── body2   (192.168.174.21)  ← k3s Worker #2  (FastAPI Pod 분산 실행)
├── memory  (192.168.174.30)  ← 독립 서버  (PostgreSQL 16, Prometheus, Grafana)
└── shield  (192.168.174.40)  ← 독립 서버  (liboqs, Kyber-512 PQC)

         ┌─────────────────────────────────────┐
         │          k3s 클러스터                 │
         │  brain-node  [Control Plane]         │
         │  body-node   [Worker #1]  ┐          │
         │  body2-node  [Worker #2]  ┘ HPA로    │
         │                             자동확장  │
         └─────────────────────────────────────┘
```

**핵심 개념**: memory·shield는 k3s와 **독립**. k3s는 brain·body·body2 3대만 관리.

---

## 🗂️ 프로젝트 파일 구조

```
c:\project\onprem-ops-engine\
│
├── 📄 Vagrantfile              # VM 5대 정의 (VMware Desktop Provider)
├── 📄 README.md                # 프로젝트 소개
│
├── 📁 ansible/                 # 인프라 자동화
│   ├── playbook.yml            # 전체 프로비저닝 플레이북
│   ├── inventory.yml           # 5대 VM IP 정의
│   ├── group_vars/             # 노드별 변수
│   ├── roles/                  # Ansible 롤 디렉터리
│   ├── pqc/                    # liboqs Kyber-512 빌드 스크립트
│   ├── simulation/             # k6 부하 테스트 스크립트
│   ├── graph-rag/              # Neo4j + Ollama 연동 스크립트
│   └── k8s-manifests/          # Kubernetes 리소스 정의
│       ├── ecommerce-app.yaml  # FastAPI Deployment
│       ├── redis.yaml          # Redis StatefulSet
│       ├── service.yaml        # ClusterIP + NodePort 30080
│       ├── ingress.yaml        # Traefik Ingress
│       ├── hpa.yaml            # HPA (CPU 70%, 최대 6 Pod)
│       ├── pdb.yaml            # PodDisruptionBudget (최소 1개)
│       └── dashboard.yaml      # nginx 웹 대시보드 NodePort 30081
│
├── 📁 frontend/                # 웹 대시보드 소스
│   ├── index.html              # 4탭 대시보드 HTML
│   ├── style.css               # 다크 테마 CSS
│   └── app.js                  # API 연동 JavaScript
│
├── 📁 docs/
│   ├── architecture.md         # 아키텍처 & 현황 (이 파일)
│   ├── setup-guide.md          # 설치/실행 가이드
│   └── troubleshooting.md      # 트러블슈팅 #1~#12
│
├── 📁 scripts/                 # 운영 스크립트
│   ├── check-infra.sh          # 5대 노드 상태 점검
│   ├── deploy-app.sh           # 앱 배포
│   ├── fix-pg-perms.sh         # PostgreSQL 권한 수정
│   ├── run-ansible.sh          # Ansible 실행 래퍼
│   └── tmp-check.sh            # 임시 점검 스크립트
│
└── 📁 logs/                    # 실행 로그
    ├── ansible.log
    ├── deploy.log
    ├── infra-status.log
    ├── k3s-reinstall.log
    ├── liboqs-build.log
    ├── postgres-setup.log
    └── vm-packages.log
```

---

## 🔧 구현 내용

### 1. 멀티 노드 Kubernetes 아키텍처

**1 Control Plane + 2 Worker** 구조로 k3s 클러스터를 구성하였습니다.
Control Plane과 워크로드 노드를 분리하고, 노드 장애 시 자동 복구 메커니즘을 검증할 수 있도록 설계하였습니다.

### 2. IaC 기반 인프라 자동화

Vagrant로 5대 VM을 코드로 정의하고, Ansible Playbook으로 다음 항목을 자동화:
- k3s 설치 및 클러스터 조인 (Control Plane 준비 완료 후 Worker 순차 조인)
- Neo4j 5 설치 (Java 21 포함)
- PostgreSQL 16 설치
- Prometheus / Grafana 배포 (바이너리 직접 설치 방식)
- Ollama 설치 및 Llama2 모델 로드
- k6 부하 테스트 환경 구성

모든 프로비저닝은 **재실행 가능(멱등성)** 하도록 작성, 환경 재구성 **약 30분 이내** 달성.

### 3. 부하 시뮬레이션 및 자동 확장 검증

k6로 **Black Friday 수준의 트래픽 급증 상황** 시뮬레이션:
- 정상 트래픽 → **3x 급증 → 5x Black Friday 피크** 시나리오
- Prometheus 메트릭 기반 Kubernetes **HPA** 구성 (CPU 70% 임계치)
- 부하 증가 → Replica 증가 → 부하 감소 시 축소 과정 검증

### 4. 노드 장애 복원력 테스트

Worker 노드 강제 종료로 **Pod 재스케줄링** 확인:
- **PodDisruptionBudget (PDB)**: minAvailable: 1 설정으로 최소 가용성 보장

### 5. Graph 기반 장애 원인 분석 (Graph RAG)

Neo4j에 **주문–결제–배송 트랜잭션 관계**를 모델링하고,
Cypher 쿼리 결과를 Ollama(Llama2)에 전달하여 **장애 원인 분석 리포트 자동 생성**.

### 6. 양자내성 암호화 (PQC)

liboqs로 **CRYSTALS-Kyber** 기반 키 교환 및 암·복호화 테스트. Kyber-512 검증 완료.

---

## 🔧 k3s 주요 설정값

| 항목 | 값 |
|------|-----|
| k3s 버전 | v1.29.2+k3s1 |
| 컨테이너 런타임 | containerd 1.7.11 |
| 스토리지 | local-path-provisioner (기본) |
| 네트워크 | Flannel (기본) |
| Pod CIDR | 10.42.0.0/16 |
| brain IP | 192.168.174.10 |
| body/body2 IP | 192.168.174.20/21 |

### 현재 배포된 k8s 리소스

```
Namespace: default
│
├── Deployment: ecommerce-api  (replica: 2, HPA 대상)
│   └── Pod: FastAPI + uvicorn (python:3.11-slim)
│       ├── initContainer: pip install deps
│       └── 환경변수: PG_HOST, NEO4J_HOST, OLLAMA_HOST, REDIS_HOST
│
├── StatefulSet: redis  (PVC: local-path)
│
├── Service: ecommerce-api-service     (ClusterIP :80→8000)
├── Service: ecommerce-api-nodeport    (NodePort :30080)
├── Service: web-dashboard-service     (NodePort :30081)
│
├── Deployment: web-dashboard (nginx:alpine)
│   └── ConfigMap: dashboard-html (index.html, style.css, app.js)
│
├── HPA: ecommerce-api-hpa  (CPU 70% → 최대 6 Pod)
└── PDB: ecommerce-api-pdb  (minAvailable: 1)
     PDB: redis-pdb         (minAvailable: 1)
```

---

## ✅ 완료된 작업 (~65%)

| # | 작업 | 상태 |
|---|------|------|
| 1 | Vagrant 5대 VM 구성 | ✅ 완료 |
| 2 | k3s 클러스터 3대 구성 (brain+body+body2) | ✅ 완료 |
| 3 | Neo4j 설치 (brain) | ✅ 완료 |
| 4 | Ollama + llama2 설치 (brain) | ✅ 완료 |
| 5 | PostgreSQL 16 + pgvector 0.8.1 (memory) | ✅ 완료 |
| 6 | Prometheus + Grafana 설치 (memory) | ✅ 완료 |
| 7 | liboqs Kyber-512 설치 검증 (shield) | ✅ 완료 |
| 8 | FastAPI Deployment 배포 (k8s) | ✅ 완료 |
| 9 | Redis StatefulSet 배포 (k8s) | ✅ 완료 |
| 10 | 웹 대시보드 배포 (nginx NodePort 30081) | ✅ 완료 |
| 11 | HPA + PDB 설정 | ✅ 완료 |
| 12 | 트러블슈팅 문서 (#1~#12) | ✅ 완료 |

---

## 🔴 남은 작업

### 즉시 해야 할 것

| # | 작업 | 파일/명령 |
|---|------|-----------|
| 1 | **PostgreSQL 권한 수정** — `permission denied for table products` | `scripts/fix-pg-perms.sh` 실행 |
| 2 | **FastAPI readinessProbe** — initContainer pip install로 60초+ 소요 | 파드 재시작 후 2분 대기 |
| 3 | **Ingress 설정 확인** — Traefik 비활성화 여부 | `ansible/k8s-manifests/ingress.yaml` |

### 검증/실험 필요

| # | 실험 | 목표 | 방법 |
|---|------|------|------|
| A | **HPA 부하 테스트** | CPU 70% 초과 → Pod 자동 추가 | `ansible/simulation/` k6 스크립트 |
| B | **복원력 테스트** | body 노드 종료 → Pod 자동 이동 | `vagrant halt body` → kubectl 관찰 |
| C | **Neo4j 관계 확인** | 주문 시 Customer→Order→Product 생성 | Neo4j Browser (192.168.174.10:7474) |
| D | **Ollama AI 분석** | `/analyze/failures` → AI 리포트 | curl + llama2 응답 확인 |
| E | **Prometheus 메트릭** | FastAPI 요청률, CPU/메모리 시각화 | Grafana 대시보드 구성 |
| F | **PQC 데모 실행** | Kyber-512 암호화 성능 측정 | shield 노드 liboqs 벤치마크 |

### 개발 완성도

| # | 작업 | 설명 |
|---|------|------|
| G | **Grafana 대시보드 JSON** | FastAPI QPS, Pod 수, 에러율 패널 |
| H | **k6 시나리오 완성** | VU 점진 증가 → HPA 반응 시간 측정 |
| I | **README 최종 업데이트** | 실측 수치 기록 |
| J | **GitHub Push** | 완성된 코드 최종 커밋 |

---

## 🌐 접속 주소

| 서비스 | 주소 | 인증 |
|-------|------|------|
| **웹 대시보드** | http://192.168.174.20:**30081** | 없음 |
| **FastAPI Swagger** | http://192.168.174.20:**30080**/docs | 없음 |
| **Grafana** | http://192.168.174.30:**3000** | admin/admin |
| **Prometheus** | http://192.168.174.30:**9090** | 없음 |
| **Neo4j Browser** | http://192.168.174.10:**7474** | neo4j/neo4j1234 |

---

## 🐛 알려진 이슈

| 이슈 | 원인 | 해결법 |
|------|------|--------|
| `/products` permission denied | PostgreSQL GRANT 미적용 | `scripts/fix-pg-perms.sh` 실행 |
| initContainer 긴 기동 시간 | pip install 네트워크 의존 | readinessProbe initialDelaySeconds: 60 |
| memory 노드 SSH 키 경로 | brain 키와 별도 관리 | `.vagrant/machines/memory/vmware_desktop/private_key` |

---

## 🔑 SSH 접속

```bash
# Windows WSL에서
KEY_BRAIN=.vagrant/machines/brain/vmware_desktop/private_key
KEY_MEMORY=.vagrant/machines/memory/vmware_desktop/private_key

# brain 접속 (k3s 명령어)
wsl ssh -i $KEY_BRAIN -o StrictHostKeyChecking=no vagrant@192.168.174.10

# memory 접속 (PostgreSQL, Prometheus, Grafana)
wsl bash -c "KEY=/mnt/c/project/onprem-ops-engine/.vagrant/machines/memory/vmware_desktop/private_key && chmod 600 \$KEY && ssh -i \$KEY -o StrictHostKeyChecking=no vagrant@192.168.174.30"

# kubectl 명령어 (brain에서)
sudo k3s kubectl get pods -o wide
sudo k3s kubectl get svc
sudo k3s kubectl logs -l app=ecommerce-api --tail=20
```

---

## 📦 E2E 데이터 흐름

```
브라우저 → http://192.168.174.20:30081 (nginx)
  └─ JavaScript fetch → FastAPI (NodePort 30080)
       ├─ GET  /products     → [PostgreSQL] products 테이블
       ├─ POST /orders       → [PostgreSQL] orders + payments 저장
       │                     → [Redis] order_count 증가
       │                     → [Neo4j] Customer→Order→Product 관계 기록
       ├─ GET  /orders/history → [PostgreSQL] JOIN 조회
       ├─ GET  /metrics/summary → [PostgreSQL + Redis] 집계
       └─ GET  /analyze/failures → [PostgreSQL] TOP 5 + [Ollama llama2] AI 분석
```
