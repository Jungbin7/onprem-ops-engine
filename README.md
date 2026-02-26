# E-Commerce Resilience Platform

> **AI-Driven Operations Platform with Post-Quantum Security**  
> Black Friday를 견디는 차세대 e커머스 인프라

## 🎯 프로젝트 개요

온프레미스 환경에서 구축한 AI 기반 e커머스 안정성 플랫폼입니다.
Graph RAG로 트랜잭션 체인을 분석하고, Digital Twin으로 트래픽 급증을 시뮬레이션하며,
Post-Quantum Cryptography로 결제 데이터를 보호합니다.

### 핵심 기능

- **Graph RAG**: Neo4j에 주문-결제-배송 트랜잭션을 모델링하고 Cypher 질의 결과를 LLM(Ollama/llama2) 프롬프트에 주입하여 장애 원인을 실시간 추론
- **Digital Twin**: k6로 Black Friday급 부하를 시뮬레이션하고 CPU/Memory 메트릭 변화에 따른 인프라 거동 검증
- **AI-Driven Auto-Scaling**: Prometheus 메트릭 기반 Kubernetes HPA 자동 임계치 조정 (CPU 70%, Memory 80%)
- **PQC Security**: liboqs 기반 CRYSTALS-Kyber-512(키 교환) 양자내성 암호화로 결제 데이터 보호

## 📊 아키텍처

```
brain   (192.168.174.10)  ← k3s Control Plane + Neo4j + Ollama
body    (192.168.174.20)  ← k3s Worker #1  (FastAPI, Redis)
body2   (192.168.174.21)  ← k3s Worker #2  (FastAPI 분산)
memory  (192.168.174.30)  ← PostgreSQL 16 + Prometheus + Grafana
shield  (192.168.174.40)  ← liboqs PQC 보안 게이트웨이
```

## 🚀 Quick Start

### Prerequisites
- VMware Workstation Pro 17.5+
- Vagrant 2.4.1+ with vmware_desktop plugin
- WSL2 + Ansible 2.16+
- 16GB+ RAM

### 1. VM 생성
```powershell
vagrant up --provider=vmware_desktop
```

### 2. Ansible 프로비저닝
```bash
# WSL에서 실행
wsl
cd /mnt/c/project/onprem-ops-engine
bash scripts/run-ansible.sh
```

### 3. 앱 배포
```bash
bash scripts/deploy-app.sh
```

## 🎬 Demo 시나리오

**Black Friday 트래픽 급증 자동 대응**
1. k6로 50 VU × 3분 부하 → CPU 급등
2. HPA가 ecommerce-api Pod 2→4→6개 자동 스케일아웃
3. Graph RAG(Neo4j + llama2)가 병목 지점 실시간 추론
4. Worker 노드 장애 시 PDB 보장 하에 Pod 자동 재스케줄

## 📈 실측 성능 지표 (2026-02-26 기준)

| 항목 | 결과 |
|------|------|
| E2E 헬스체크 (`GET /health`) | ✅ api, postgresql, redis 모두 connected |
| 주문 처리 및 PostgreSQL 저장 | ✅ total_orders_db: 1, revenue: 2,400,000원 |
| Redis 카운터 동기화 | ✅ redis_order_count: 1, redis_product_views: 8 |
| Neo4j 그래프 기록 | ✅ Customer→Order→Product 노드 자동 생성 |
| HPA 부하 테스트 (k6 60VU × 3분) | ✅ replica **2 → 6** 스케일아웃 확인 |
| HPA 스케일다운 (부하 종료 후) | ✅ replica 6 → 2, CPU 6%/70% 정상화 |
| 복원력 테스트 (body-node halt) | ✅ Pod 재스케줄, `/health` **200** 무중단 확인 |
| body-node 복구 | ✅ `vagrant up body` 후 3노드 Ready 재가입 |
| PQC Kyber-512 검증 | ✅ Shared secrets match — 키 교환 성공 |
| Ollama llama2 모델 로드 | ✅ 3.8GB 로드됨 (RAM 부족 시 응답 지연 가능) |

## 🏆 주요 성과

- **Zero Downtime**: PDB + HPA로 Black Friday 트래픽 대응
- **Neo4j 그래프 분석**: 주문 트랜잭션 체인 실시간 추론
- **양자내성 결제 보안**: Kyber-512 키 교환 검증 완료
- **4-레이어 관측성**: Prometheus → Grafana → HPA → Alerting

## 📚 Documentation

- [docs/architecture.md](docs/architecture.md) — 아키텍처 설계 & 프로젝트 현황
- [docs/setup-guide.md](docs/setup-guide.md) — 설치/실행 가이드 & 버전 호환성
- [docs/progress.md](docs/progress.md) — 단계별 진행 현황
- [docs/troubleshooting.md](docs/troubleshooting.md) — 트러블슈팅 #1~#12

## 🛠 주요 스크립트

| 스크립트 | 설명 |
|----------|------|
| `scripts/deploy-app.sh` | k8s 앱 전체 배포 |
| `scripts/e2e-test.sh` | E2E 흐름 전체 테스트 |
| `scripts/install-k6-body2.sh` | body2 노드에 k6 설치 |
| `scripts/run-k6-hpa-test.sh` | k6 HPA 부하 테스트 실행 |
| `scripts/resilience-test.sh` | 노드 장애 복원력 테스트 |
| `scripts/check-infra.sh` | 5대 노드 인프라 상태 점검 |

## 📄 License

MIT License
