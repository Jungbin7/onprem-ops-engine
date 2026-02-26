# E-Commerce Resilience Platform — 이력서 서술 문서

## 프로젝트 한 줄 요약 (Resume Headline)

> **온프레미스 AI 기반 e커머스 복원력 플랫폼 — 4노드 k3s 클러스터 자체 운영, GitOps(Flux CD) + Prometheus/Grafana 모니터링, Graph RAG + 로컬 LLM(Ollama), PQC(Kyber-512) 보안 레이어 구현**

---

## 면접 설명 스크립트 (STAR 방식)

### Situation (상황)
"팀 프로젝트에서 AWS EKS, ArgoCD, SageMaker를 사용했는데, 매니지드 서비스에 너무 의존하면 실제 인프라 운영 역량이 드러나지 않는다고 판단했습니다. 온프레미스 환경에서 직접 운영하는 플랫폼을 개인 프로젝트로 구성했습니다."

### Task (목표)
"팀 프로젝트와 완전히 차별화된 기술 스택으로 e커머스 백엔드를 구성하고, 모든 기술 결정에 'Why'를 문서화하는 것이 목표였습니다."

### Action (행동) — 기술별 근거
| 결정 | 선택 | 왜 팀 프로젝트와 다른가 |
|------|------|------------------------|
| CD | Flux CD | 팀은 ArgoCD → 같은 GitOps 패러다임, 다른 구현 비교 경험 |
| 모니터링 | 자체 운영 Grafana | 팀은 AWS Managed Grafana → 직접 설치·설정·provisioning |
| AI | Ollama (로컬 llama2) | 팀은 SageMaker → 결제 데이터 외부 미전송, 비용 $0 |
| 보안 | PQC Kyber-512 | 팀에 없음 → NIST FIPS 203 표준, 양자 내성 암호화 선도 경험 |
| 그래프 | Neo4j + Graph RAG | 팀에 없음 → 벡터 RAG 대비 정확한 인과 관계 분석 |
| k8s | k3s (자체 설치) | 팀은 EKS (매니지드) → kubeadm, etcd, node 관리 직접 경험 |

### Result (결과)
"GitHub Actions CI가 push마다 Ansible Lint, kubeconform, Trivy 보안 스캔을 자동 실행합니다. Flux CD가 Git main 브랜치를 감시해 5분마다 클러스터와 동기화합니다. Prometheus는 15초마다 FastAPI /metrics를 scrape하고, Grafana 대시보드 8개 패널로 실시간 모니터링합니다. k6 부하 테스트로 HPA가 Pod 2개 → 6개로 스케일아웃되는 것을 검증했습니다."

---

## 핵심 수치 (Quantified Achievements)

| 지표 | 수치 |
|------|------|
| 클러스터 노드 수 | 4개 (brain, body, body2, memory) |
| Prometheus scrape 주기 | 15초 |
| Grafana 대시보드 패널 | 8개 |
| HPA 스케일 범위 | 2 → 6 Pod |
| CI Job 수 | 5개 (ansible-lint, kubeconform, docker-build, k6-validate, trivy) |
| Flux CD 동기화 주기 | 5분 |
| 앱 startup 시간 | <60초 (HEALTHCHECK start-period 기준) |
| Docker 이미지 경량화 | 멀티스테이지 빌드 (~70% 크기 절감) |

---

## 예상 면접 질문 & 답변

### Q1. "ArgoCD 말고 왜 Flux CD를 썼나요?"
> "팀 프로젝트에서 ArgoCD를 이미 사용했고, 동일한 도구를 반복하면 기술 폭이 좁아 보인다고 판단했습니다. Flux CD와 ArgoCD는 동일한 GitOps Pull 방식이지만, Flux는 마이크로 컨트롤러 아키텍처로 분리되어 있고 CLI 중심입니다. 두 도구의 트레이드오프를 실제로 비교해봤다는 점에서 ADR-005에 상세히 문서화했습니다."

### Q2. "Prometheus Pull 방식과 Push 방식의 차이가 뭔가요?"
> "Pull 방식(이 프로젝트)에서는 Prometheus가 애플리케이션의 /metrics 엔드포인트를 15초마다 스크레이프합니다. Push 방식(Pushgateway)은 앱이 직접 Prometheus로 데이터를 밀어 넣습니다. Pull이 서버 부하 제어 주도권을 Prometheus가 가지므로, 타겟 장애 시 자동으로 'down' 상태를 감지할 수 있습니다. 응용 배치 작업에는 Push가 적합하나, 이 프로젝트처럼 상시 동작하는 서비스에는 Pull이 표준입니다."

### Q3. "PQC를 왜 넣었나요? 실제로 필요한가요?"
> "양자 컴퓨터가 2030년대 상용화되면 현재 RSA/ECC 기반 TLS는 Shor's Algorithm으로 해독됩니다. 'Harvest Now, Decrypt Later' 공격은 지금 암호화된 트래픽을 저장해두었다가 나중에 해독하는 방식이라, 결제 데이터처럼 10년 이상 보안이 필요한 데이터는 지금부터 대비해야 합니다. NIST가 2024년 FIPS 203(Kyber = ML-KEM)을 공식 표준으로 확정했고, 이를 API 키 교환 레이어에 시뮬레이션으로 구현했습니다."

### Q4. "Graph RAG와 벡터 RAG의 차이가 뭔가요?"
> "벡터 RAG는 텍스트를 임베딩 벡터로 변환해 유사도 검색을 합니다. '주문 → 결제 → 배송' 같은 인과 순서는 벡터 유사도로 표현하기 어렵고 환각이 발생할 수 있습니다. Graph RAG는 Neo4j에서 Cypher 쿼리로 정확한 관계 데이터를 추출해 LLM 프롬프트에 직접 주입합니다. 실제 DB 데이터를 기반으로 추론하므로 환각이 없고 결과 신뢰성이 높습니다."

### Q5. "k3s가 쿠버네티스와 완전히 같나요?"
> "k3s는 업스트림 쿠버네티스를 기반으로 하지만, CRI로 containerd를 사용하고 일부 알파 기능이 제거되었습니다. 핵심 API(Deployment, Service, HPA, NetworkPolicy 등)는 100% 호환됩니다. CNCF Graduated 프로젝트이며, Rancher/SUSE가 엣지 프로덕션에 사용합니다. 이 프로젝트에서 사용한 HPA, Ingress, Namespace 등 모든 기능은 EKS와 동일하게 동작했습니다."

---

## GitHub README 뱃지 라인 (복사 사용)

```markdown
![k3s](https://img.shields.io/badge/k3s-v1.29-orange?logo=kubernetes)
![Flux CD](https://img.shields.io/badge/Flux_CD-GitOps-blue?logo=flux)
![Prometheus](https://img.shields.io/badge/Prometheus-monitored-red?logo=prometheus)
![Grafana](https://img.shields.io/badge/Grafana-8_panels-orange?logo=grafana)
![GitHub Actions](https://img.shields.io/badge/CI-GitHub_Actions-black?logo=github-actions)
![Neo4j](https://img.shields.io/badge/Graph_RAG-Neo4j-green?logo=neo4j)
![PQC](https://img.shields.io/badge/PQC-Kyber--512_FIPS203-purple)
```
