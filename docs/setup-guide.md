# 🚀 설치 & 실행 가이드

> Ansible Playbook 실행 방법과 버전 호환성 정보를 담은 통합 가이드입니다.

---

## ✅ 실행 전 체크리스트

- [ ] WSL2 설치 확인
- [ ] Ansible 설치 확인 (WSL 내부)
- [ ] Vagrant VMs 5대 실행 중
- [ ] SSH 키 권한 설정 (`chmod 600`)

```powershell
# WSL 확인
wsl --version
```

```bash
# Ansible 설치 (WSL 내부)
sudo apt update && sudo apt install -y ansible
ansible --version
```

---

## 🚀 Ansible 실행 방법

### 1. WSL 진입
```powershell
wsl
```

### 2. 프로젝트 디렉터리 이동
```bash
cd /mnt/c/project/onprem-ops-engine
```

### 3. Ansible 실행
```bash
# 전체 실행
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml

# 특정 노드만 실행
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml --limit brain
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml --limit memory

# Verbose 모드 (디버깅)
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml -vv
```

> 💡 SSH 키 권한 설정 및 WSL 키 복사는 `scripts/run-ansible.sh`가 자동 처리합니다.

---

## ⏱️ 예상 소요 시간

| Phase | 작업 | 노드 | 소요 시간 |
|-------|------|------|----------|
| Phase 0 | 공통 설정 (apt update 등) | 전체 | 5분 |
| Phase 1 | k3s Control Plane + Neo4j + Ollama | brain | 10분 |
| Phase 2 | k3s Worker 조인 | body, body2 | 3분 |
| Phase 3 | PostgreSQL + Prometheus + Grafana | memory | 12분 |
| Phase 4 | liboqs PQC 빌드 | shield | 2분 |

**총 예상 시간: 약 30~35분**

---

## 🔧 버전 호환성

### ✅ 검증된 버전 조합 (Ubuntu 22.04 기준)

| 컴포넌트 | 버전 | 상태 | 비고 |
|---------|------|------|------|
| Ubuntu | 22.04 LTS | ✅ | 2027년 4월까지 지원 |
| k3s | v1.29.2+k3s1 | ✅ | 공식 지원 확인 |
| Neo4j | 5.17.0 | ✅ | Ubuntu 22.04 공식 지원 |
| PostgreSQL | 16 | ✅ | pgdg repo에서 제공 |
| Prometheus | 2.50.1 | ✅ | 정적 바이너리 |
| Grafana | 10.3.3 (고정) | ✅ | 버전 고정 권장 |
| Ollama | 최신 | ⚠️ | install.sh 사용, llama2 모델 사용 |

### ⚠️ 잠재적 문제점 및 해결

#### Neo4j 버전 지정 오류
```yaml
# 문제: 특정 버전 지정 시 apt에서 못 찾을 수 있음
apt:
  name: neo4j=1:5.17.0   # ← 문제 가능성

# 해결: 최신 5.x 사용 (권장)
apt:
  name: neo4j
  state: present
```

#### Ollama 모델 이름 오류
```yaml
# 문제: llama3.2:1b 모델이 없을 수 있음
shell: ollama pull llama3.2:1b

# 해결: 검증된 llama2 사용
shell: ollama pull llama2
```

#### Grafana 버전 미고정
```yaml
# 문제: 최신 버전이 예기치 않은 변경사항 포함 가능
apt:
  name: grafana  # ← 버전 미지정

# 해결: 버전 고정
apt:
  name: grafana=10.3.3
```

---

## 🌐 서비스 접속 주소

| 서비스 | 주소 | 인증 |
|-------|------|------|
| Grafana | http://192.168.174.30:3000 | admin / admin |
| Prometheus | http://192.168.174.30:9090 | - |
| Neo4j Browser | http://192.168.174.10:7474 | neo4j / neo4j1234 |
| Ollama API | http://192.168.174.10:11434 | - |
| k3s API | https://192.168.174.10:6443 | kubeconfig |

---

## ✅ 설치 확인 명령어

### Brain Node
```bash
vagrant ssh brain

sudo kubectl get nodes         # k3s 노드 확인
sudo systemctl status neo4j    # Neo4j 상태
sudo systemctl status ollama   # Ollama 상태
ollama list                    # 모델 목록
```

### Memory Node
```bash
vagrant ssh memory

sudo systemctl status postgresql     # PostgreSQL 상태
curl http://localhost:9090/-/healthy # Prometheus 상태
sudo systemctl status grafana-server # Grafana 상태
```

---

## 📝 다음 단계

1. Grafana에 Prometheus 데이터소스 추가
2. Neo4j에 E-Commerce 트랜잭션 그래프 생성
3. `kubectl apply -f ansible/k8s-manifests/` 로 앱 배포
4. `ansible/simulation/` k6 스크립트로 Black Friday 시뮬레이션 실행
