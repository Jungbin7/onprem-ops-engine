# 📋 프로젝트 진행 현황

> **기준일**: 2026-02-25

---

## 범례

| 아이콘 | 의미 |
|--------|------|
| `📜 스크립트` | **쉘 스크립트로 직접 실행**한 항목 |
| `⚙️ Ansible` | **Ansible Playbook**이 자동으로 처리한 항목 |
| `📄 파일만` | 코드/파일은 **작성 완료**했지만 **아직 실행 안 함** |
| `🔴 미완료` | 구현/실행 모두 아직 안 된 항목 |

---

## 1. 인프라 프로비저닝

| # | 항목 | 방식 | 스크립트/파일 |
|---|------|------|--------------|
| 1 | VM 5대 생성 (brain/body/body2/memory/shield) | `📜 스크립트` | `vagrant up --provider=vmware_desktop` |
| 2 | WSL SSH 키 복사 + chmod 600 | `📜 스크립트` | `scripts/run-ansible.sh` (앞부분 키 준비 단계) |
| 3 | Ansible Playbook 전체 실행 | `📜 스크립트` | `scripts/run-ansible.sh` → `ansible-playbook ...` 자동 실행 |

---

## 2. Ansible이 자동 설치한 것들 (⚙️ Ansible)

> `scripts/run-ansible.sh` 실행 → `ansible/playbook.yml` 가 아래 항목들을 자동 처리

| # | 항목 | 노드 | 비고 |
|---|------|------|------|
| 4 | k3s Control Plane 설치 | brain | `--node-ip=192.168.174.10 --flannel-iface=eth1` |
| 5 | k3s Worker 조인 (body, body2) | body/body2 | brain API 준비 후 순차 조인 |
| 6 | kubectl 심볼릭 링크 생성 | brain | `/usr/local/bin/kubectl → k3s` |
| 7 | Neo4j 설치 + Java 21 | brain | 초기 비밀번호: `neo4j1234` |
| 8 | Ollama 설치 + llama2 모델 로드 | brain | `ollama pull llama2` |
| 9 | PostgreSQL 16 설치 | memory | pgdg 저장소 |
| 10 | Prometheus 설치 (바이너리) | memory | v2.50.1, 포트 9090 |
| 11 | Grafana 설치 (apt) | memory | 공식 GPT 저장소 추가 후 설치, 포트 3000 |
| 12 | liboqs(Kyber-512) 빌드 | shield | cmake + ninja-build, `ldconfig` 실행 |
| 13 | k6 설치 | body2 | 부하 테스트 도구 |

---

## 3. Kubernetes 앱 배포

> **✅ 2026-02-25 `kubectl get pods` 직접 확인 완료** — `scripts/deploy-app.sh` 로 실행됨

| # | 항목 | 방식 | 실제 상태 |
|---|------|------|----------|
| 14 | Redis StatefulSet 배포 | `📜 스크립트` | ✅ `redis-0` Running |
| 15 | FastAPI Deployment 배포 (replica 2) | `📜 스크립트` | ✅ `ecommerce-api` 2개 Running |
| 16 | Service (ClusterIP + NodePort :30080) | `📜 스크립트` | ✅ `ecommerce-api-nodeport` 확인 |
| 17 | HPA (CPU 70% / min2 / max6) | `📜 스크립트` | ✅ `7%/70%` 정상 모니터링 중 |
| 18 | PDB (ecommerce + redis, minAvailable:1) | `📜 스크립트` | ✅ 두 개 모두 적용됨 |
| 19 | 웹 대시보드 (nginx NodePort :30081) | `📜 스크립트` | ⚠️ 구버전 1개 Running, 신버전 CrashLoopBackOff → rollback 필요 |

---

## 4. 운영 중 직접 실행한 스크립트들

| # | 항목 | 방식 | 파일 | 현황 |
|---|------|------|------|------|
| 20 | PostgreSQL GRANT 권한 적용 | `📜 스크립트` | `scripts/fix-pg-perms.sh` | memory VM에 SSH → bash 실행 |
| 21 | 전체 인프라 상태 점검 | `📜 스크립트` | `scripts/check-infra.sh` | 5대 노드 서비스 상태 일괄 확인 |

---

## 5. 실행 필요 (📄 파일 존재, 아직 미실행)

### 22. web-dashboard CrashLoopBackOff 롤백
> **지금 당장 해야 함** — 신버전 Pod가 6시간째 죽고 있음

```bash
# brain에서
sudo k3s kubectl rollout undo deployment/web-dashboard
sudo k3s kubectl get pods  # Running 1개만 남으면 완료
```

### 23. E2E 흐름 전체 테스트
> FastAPI → PostgreSQL → Redis → Neo4j 전체 연결 확인

```bash
# 1. FastAPI 헬스체크
curl http://192.168.174.20:30080/health

# 2. 상품 목록 조회 (PostgreSQL 연결 확인)
curl http://192.168.174.20:30080/products

# 3. 주문 생성 (PostgreSQL 저장 + Neo4j 관계 기록 + Redis 카운터)
curl -X POST http://192.168.174.20:30080/orders \
  -H 'Content-Type: application/json' \
  -d '{"product_id": 1, "quantity": 1, "customer_email": "test@test.com"}'

# 4. 주문 내역 확인 (PostgreSQL JOIN 조회)
curl http://192.168.174.20:30080/orders/history

# 5. 메트릭 확인 (Redis 카운터)
curl http://192.168.174.20:30080/metrics/summary

# 6. AI 분석 (Ollama llama2 응답)
curl http://192.168.174.20:30080/analyze/failures
```

### 24. Neo4j 관계 확인
> 주문 후 Neo4j Browser에서 그래프 시각화 확인

```
브라우저 → http://192.168.174.10:7474
ID: neo4j / PW: neo4j1234

Cypher 쿼리:
MATCH (c:Customer)-[:PLACED]->(o:Order)-[:CONTAINS]->(p:Product)
RETURN c, o, p LIMIT 20
```

### 25. k6 HPA 부하 테스트
> cpu 70% 초과 → Pod 자동 2→4→6개 확장 확인

```bash
# body2에서 (k6 설치된 노드)
vagrant ssh body2

# k6로 부하 생성 (별도 터미널에서 HPA 모니터링)
k6 run --vus 50 --duration 3m /path/to/simulation/load-test.js

# brain에서 동시에 모니터링
watch -n 3 'sudo k3s kubectl get hpa && sudo k3s kubectl get pods'
```

### 26. 복원력 테스트 (Failover)
> Worker 노드 1개 강제 종료 → Pod 자동 이동 확인

```bash
# 1. 현재 Pod 위치 기억
sudo k3s kubectl get pods -o wide

# 2. body 노드 강제 종료 (Windows PowerShell에서)
vagrant halt body

# 3. brain에서 Pod 이동 관찰 (30초~2분 소요)
watch -n 5 'sudo k3s kubectl get pods -o wide'
# body-node에 있던 Pod가 body2-node로 이동하면 성공

# 4. 복구
vagrant up body
```

### 27. Grafana 대시보드 구성
> Prometheus 데이터 시각화

```
브라우저 → http://192.168.174.30:3000
ID: admin / PW: admin

순서:
1. Connections → Data Sources → Add → Prometheus
   URL: http://192.168.174.30:9090
2. Dashboards → New → Add Visualization
   추천 쿼리:
   - FastAPI 요청 수: rate(http_requests_total[1m])
   - Pod CPU: rate(container_cpu_usage_seconds_total[1m])
   - Pod 개수: kube_deployment_status_replicas{deployment="ecommerce-api"}
```

---

## 6. 마무리 🔴

| # | 항목 | 선행 조건 |
|---|------|----------|
| 28 | PQC 벤치마크 | shield에서 `sudo /opt/pqc_demo` 실행 후 수치 기록 |
| 29 | README 실측 수치 업데이트 | HPA 테스트 + 복원력 테스트 완료 후 실제 숫자 기입 |
| 30 | GitHub 최종 Push | 모든 테스트 완료 후 커밋 |

```bash
# PQC 데모 실행 (shield에서)
vagrant ssh 2571c4b  # shield ID
sudo /opt/pqc_demo

# GitHub Push
git add -A
git commit -m "feat: add complete onprem k8s ops platform"
git push origin main
```
