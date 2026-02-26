# ADR-005: GitOps CD 도구로 Flux CD 선택 (ArgoCD 대신)

## 상태 (Status)
**Accepted** — 2026-02-26

## 컨텍스트 (Context)

팀 프로젝트에서 이미 ArgoCD를 GitOps CD 도구로 사용하고 있다.
개인 프로젝트에서도 ArgoCD를 선택하면 기술 스택이 겹쳐 차별점이 없어진다.
Jenkins는 CI 전용 서버를 별도 운영해야 하는 구시대적 패턴이다.

**결정이 필요한 질문:**
- GitHub Actions(CI) + 무엇(CD)?
- ArgoCD / Flux CD / Jenkins / Tekton 중 선택

## 결정 (Decision)

**GitHub Actions (CI) + Flux CD (CD)** 조합을 선택한다.

## 고려한 대안 (Alternatives Considered)

| 도구 | 역할 | 장점 | 단점 |
|------|------|------|------|
| **ArgoCD** | CD | UI 직관적, 팀 경험 있음 | 팀 프로젝트와 동일 → 차별점 없음 |
| **Jenkins** | CI+CD | 레거시 기업에 방대한 플러그인 | 전용 서버 운영, XML 설정, SaaS 대비 구시대적 |
| **Tekton** | CI+CD | k8s 네이티브 CRD | YAML 복잡도 매우 높음, 커뮤니티 상대적 소규모 |
| **GitHub Actions** | CI | 저장소 내장, 무료 2000분/월 | CD는 secrets 보안 이슈 (push 방식) |
| **Flux CD** ✅ | CD | GitOps Pull, CNCF Graduated, ArgoCD 대비 경량 | UI 없음 (CLI 기반) |

## 근거 (Rationale)

### 1. ArgoCD를 안 쓰는 이유 (면접에서 직접 설명 가능)
```
팀 프로젝트: ArgoCD 사용 경험 있음
개인 프로젝트에도 ArgoCD = 동일 도구 반복
→ 면접관: "두 개 다 ArgoCD네요. 다른 건 못 쓰세요?"

Flux CD 선택:
→ 면접관: "ArgoCD와 Flux CD 차이를 실제로 써봤군요."
→ 같은 GitOps 패러다임, 다른 구현 → 기술 폭 증명
```

### 2. Jenkins를 안 쓰는 이유
```
Jenkins 아키텍처:
  코드 push → Jenkins Master → Agent 빌드 → kubectl deploy

Problems:
  1. Jenkins Master: 전용 VM 1개 필요 (리소스 낭비)
  2. XML/Groovy DSL: 학습 곡선 높음
  3. credentials 관리: Jenkins Credentials Store → 별도 운영
  4. "2015년형 CI/CD" 패턴 → 클라우드 네이티브 시대와 맞지 않음

GitHub Actions:
  YAML 기반, 저장소 내장, GitHub Secrets 연동, 무료 runner
→ 추가 인프라 0개로 CI 구현
```

### 3. Flux CD vs ArgoCD 기술적 차이

| 기준 | ArgoCD | Flux CD |
|------|--------|---------|
| UI | Web GUI 포함 | 없음 (CLI: flux CLI) |
| 설계 | 모놀리식 컨트롤러 | 마이크로 컨트롤러 분리 |
| Image 자동화 | 플러그인 | 내장 (Image Reflector/Automation) |
| Helm 지원 | HelmChart 리소스 | HelmRelease CRD |
| CNCF | Graduated (2022) | Graduated (2022) |
| Git sync | 실시간 폴링 | interval 기반 폴링 |

### 4. Pull 방식의 보안 우위
```
Push (GitHub Actions → kubectl apply):
  GH Actions가 kubeconfig 보유 → secrets 노출 위험
  
Pull (Flux CD):
  클러스터 내 Flux 컨트롤러가 Git 레포를 pull
  → kubeconfig 외부 노출 0
  → Zero-trust 원칙 준수
```

## 구현 계획

```bash
# flux/ 디렉토리 구조
flux/
├── clusters/
│   └── onprem/
│       └── kustomization.yaml    # 이 ADR에서 결정한 구조
├── apps/
│   └── ecommerce/
│       ├── helmrelease.yaml      # ecommerce-api 배포 정의
│       └── kustomization.yaml
└── sources/
    └── gitrepository.yaml        # Flux가 감시할 Git 레포 정의
```

## 결과 (Consequences)

- `flux bootstrap` 명령으로 초기 설치 (scripts/install-flux.sh 참조)
- UI 없음 → `flux get kustomizations` CLI로 상태 확인
- 면접 포인트: "ArgoCD와 Flux CD를 모두 알고, 프로젝트별 트레이드오프로 선택 근거 설명 가능"
