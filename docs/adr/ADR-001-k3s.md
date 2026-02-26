# ADR-001: 온프레미스 쿠버네티스 배포판으로 k3s 선택

## 상태 (Status)
**Accepted** — 2026-02-20

## 컨텍스트 (Context)

4노드 온프레미스 클러스터(VMware Workstation VM, RAM 총 16GB)에서 쿠버네티스를 운영해야 한다.
면접에서 "왜 k3s인가?"라는 질문을 받을 것을 가정하고 의사결정 근거를 문서화한다.

## 결정 (Decision)

**k3s (Rancher Labs, CNCF Sandbox → Graduated)** 를 선택한다.

## 고려한 대안 (Alternatives Considered)

| 배포판 | 장점 | 단점 |
|--------|------|------|
| **kubeadm** | 표준 업스트림 | 초기 설정 복잡, etcd 별도 운영, RAM 2GB+/노드 |
| **minikube** | 개발 편의성 | 단일 노드, 프로덕션 시뮬레이션 불가 |
| **kind** | CI 최적화 | 컨테이너 기반, 네트워크 제한 |
| **MicroK8s** | snap 간편 설치 | snap 의존성, ARM 환경 이슈 |
| **k3s** ✅ | 경량(512MB), 단일 바이너리, etcd 선택적 | 일부 알파 기능 미포함 |

## 근거 (Rationale)

### 1. 리소스 제약 대응
```
kubeadm 최소 요구사항: 마스터 2 CPU + 2GB RAM
k3s 최소 요구사항:     마스터 1 CPU + 512MB RAM
→ 동일 하드웨어에서 워크로드에 더 많은 리소스 할당 가능
```

### 2. etcd 내장 vs 외부 etcd
- k3s 기본값: SQLite (단일 노드) 또는 내장 etcd (HA)
- 이 프로젝트: 4노드 중 1개를 마스터(brain)로 운영 → SQLite 충분
- etcd 별도 운영 불필요 → 운영 복잡도 감소

### 3. 엔터프라이즈 사례
- Rancher, SUSE가 K3s를 엣지/IoT 프로덕션에 사용
- CNCF Incubating → Graduated (2023)

### 4. Helm, Traefik 내장
- k3s 기본 내장: Traefik Ingress, Helm Controller
- 별도 설치 불필요 → 초기 세팅 시간 단축

## 트레이드오프 (Trade-offs)

**수용한 제약:**
- 쿠버네티스 알파 기능 일부 미지원 (이 프로젝트에서 필요 없음)
- "프로덕션은 EKS/GKE를 쓴다"는 점을 인지하고 의도적으로 온프레미스 선택

**팀 프로젝트와의 차이:**
- 팀 프로젝트: AWS EKS (매니지드) → 운영 부담 없음, 비용 발생
- 이 프로젝트: k3s 자체 운영 → 운영 경험 획득, 비용 0

## 결과 (Consequences)

- Vagrantfile로 4노드 자동 프로비저닝 구현 (`vagrant up` 단일 명령)
- Ansible playbook으로 k3s 설치/설정 자동화
- HPA, 네트워크 정책 등 k8s 표준 기능 동일하게 사용 가능
