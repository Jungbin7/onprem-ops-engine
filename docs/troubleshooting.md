# 트러블슈팅 기록

> 인프라 구축 과정에서 발생한 오류 및 해결 방법을 순서대로 기록합니다.

---

## #1. Windows에서 Ansible 직접 실행 불가

**증상**
```
ansible-playbook: command not found
```

**원인**
Ansible은 Windows 네이티브 환경을 지원하지 않음.

**해결**
WSL(Windows Subsystem for Linux)을 통해 실행하도록 `run-ansible.sh` 스크립트 작성:
```bash
wsl bash -c "cd /mnt/c/project/onprem-ops-engine && bash run-ansible.sh"
```

---

## #2. WSL에서 Vagrant SSH 키 권한 오류 (bad permissions)

**증상**
```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
WARNING: UNPROTECTED PRIVATE KEY FILE!
Permissions 0777 for '...private_key' are too open.
```

**원인**
Vagrant SSH 키가 Windows NTFS 드라이브(`/mnt/c/...`)에 위치하여,
WSL에서 `chmod 600`이 적용되지 않음 (NTFS에는 Linux 권한 개념 없음).

**해결**
`run-ansible.sh`에 SSH 키를 WSL 홈 디렉토리로 복사 후 권한 설정하는 로직 추가:
```bash
KEY_DIR=~/.vagrant-keys
for node in brain body body2 memory shield; do
  cp "$VAGRANT_DIR/$node/vmware_desktop/private_key" "$KEY_DIR/${node}_key"
  chmod 600 "$KEY_DIR/${node}_key"
done
```
`inventory.yml`의 키 경로도 `~/.vagrant-keys/`로 변경.

---

## #3. k3s Worker 노드 클러스터 조인 실패 (k3s-agent.service not found)

**증상**
```
Unit k3s-agent.service could not be found.
```

**원인**
Ansible이 SSH 키 권한 오류(#2)로 인해 Worker 노드에 실제로 접속하지 못하고 태스크를 건너뜀. 결과적으로 k3s agent 설치 스크립트가 Worker 노드에서 실행되지 않음.

**해결**
- `run-ansible.sh`의 SSH 키 권한 문제(#2) 해결
- Playbook에 k3s 서버 준비 대기(wait_for) 태스크 추가:
  ```yaml
  - name: "[K3S-WORKER] Wait for brain to be ready"
    wait_for:
      host: 192.168.174.10
      port: 6443
      timeout: 120
  ```
- `k3s-agent` 서비스 시작 및 enable 태스크 명시적 추가

---

## #4. Brain 노드 kubectl 명령어 없음

**증상**
```
sudo: kubectl: command not found
```

**원인**
k3s는 표준 `kubectl` 바이너리를 별도 설치하지 않으며,
`k3s kubectl` 서브커맨드로 제공함. PATH에 `kubectl` 심볼릭 링크가 없음.

**해결**
Playbook에 심볼릭 링크 생성 태스크 추가:
```yaml
- name: "[K3S-SERVER] Create kubectl symlink"
  file:
    src: /usr/local/bin/k3s
    dest: /usr/local/bin/kubectl
    state: link
    force: yes
```

---

## #5. Neo4j 서비스 시작 실패 (Java 미설치)

**증상**
```
● neo4j.service - Neo4j Graph Database
   Active: failed
```
```
journalctl: Error: No such file or directory: java
```

**원인**
Neo4j 5는 **Java 21**이 필요하나, Playbook에 Java 설치 태스크가 누락됨.

**해결**
Playbook에 Neo4j 설치 전 Java 21 설치 태스크 추가:
```yaml
- name: "[NEO4J] Install Java 21"
  apt:
    name: openjdk-21-jdk-headless
    state: present
```

---

## #6. Neo4j 서비스 시작 실패 (초기 비밀번호 미설정)

**증상**
Java 설치 후에도 Neo4j systemd 서비스가 `failed` 상태.

**원인**
Neo4j 5에서는 최초 실행 전 `neo4j-admin dbms set-initial-password`로
초기 비밀번호(8자 이상)를 설정해야 함. 미설정 시 서비스 시작 실패.

**해결**
```bash
sudo neo4j-admin dbms set-initial-password neo4j1234
sudo systemctl restart neo4j
```
Playbook에도 해당 태스크를 추가(멱등적으로 `creates` 조건 사용):
```yaml
- name: "[NEO4J] Set initial password"
  shell: "neo4j-admin dbms set-initial-password neo4j1234"
  args:
    creates: /var/lib/neo4j/data/dbms/auth
```

---

## #7. Memory 노드 Grafana/Prometheus 미설치

**증상**
Ansible 전체 실행 후 Memory 노드에 Grafana, Prometheus가 설치되지 않음.
`memory-node : ok=3` — 태스크 3개만 실행됨.

**원인**
SSH 키 권한 문제(#2)가 Memory 노드 접속에도 동일하게 영향.
일부 태스크는 Phase 0(common)만 실행되고 Phase 3(memory)가 건너뛰어짐.

**해결**
SSH 키 문제(#2) 해결 후, Memory 노드만 대상으로 재실행:
```bash
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml --limit memory
```
결과: `ok=16 changed=...` — 모든 태스크 정상 실행 확인.

---

## #8. Grafana apt 패키지 없음

**증상**
```
E: Unable to locate package grafana
```

**원인**
Grafana는 Ubuntu 기본 저장소에 없음. 공식 Grafana APT 저장소를 별도 추가해야 함.

**해결**
Playbook에 Grafana GPG 키 및 저장소 추가 태스크 포함:
```yaml
- name: "[GRAFANA] Add GPG key"
  shell: "curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg"

- name: "[GRAFANA] Add repository"
  apt_repository:
    repo: "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main"
```

---

## #9. k3s 모든 노드 NotReady — CNI 네트워크 인터페이스 불일치

**증상**
```
NAME         STATUS     ROLES                AGE    INTERNAL-IP
brain-node   NotReady   control-plane        10d    192.168.174.128  ← DHCP IP
body-node    NotReady   <none>               10h    192.168.174.130
body2-node   NotReady   <none>               10h    192.168.174.129
```
`kube-system` 파드들이 모두 `Pending` 상태.

**원인**
k3s 설치 시 `--node-ip`와 `--flannel-iface`를 지정하지 않아,
Flannel CNI가 NAT 인터페이스(`eth0`, DHCP)를 사용함.
VMware Vagrant는 `eth0`(NAT)와 `eth1`(사설 네트워크) 두 개의 인터페이스를 제공하며,
클러스터 통신은 `eth1`(192.168.174.x)을 사용해야 함.

**진단 방법**
```bash
# Brain 노드에서 실제 IP 확인
ip addr show | grep "inet " | grep -v 127
# k3s 서비스 ExecStart 옵션 확인
cat /etc/systemd/system/k3s.service | grep ExecStart
```

**해결**
k3s 서버 및 에이전트 재설치 시 인터페이스 명시적 지정:
```bash
# Brain (Control Plane)
curl -sfL https://get.k3s.io | \
  K3S_TOKEN=ecommerce-cluster-2026 \
  sh -s - server \
  --node-ip=192.168.174.10 \
  --flannel-iface=eth1 \
  --advertise-address=192.168.174.10

# Body/Body2 (Workers)
curl -sfL https://get.k3s.io | \
  K3S_URL=https://192.168.174.10:6443 \
  K3S_TOKEN=ecommerce-cluster-2026 \
  sh -s - agent \
  --node-ip=192.168.174.20 \   # Body2는 .21
  --flannel-iface=eth1
```
Playbook에도 동일 옵션 추가 반영 완료.

---

## #10. Neo4j `set-initial-password`가 이미 실행된 DB에 적용 안 됨

**증상**
```
Changed password for user 'neo4j'. IMPORTANT: this change will only
take effect if performed before the database is started for the first time.
```
→ 명령은 성공했지만 서비스는 여전히 `failed`.

**원인**
Neo4j 5에서 `neo4j-admin dbms set-initial-password`는
**데이터베이스가 한 번도 시작된 적 없을 때만** 적용됨.
이미 DB 파일이 생성된 상태에서는 무시됨.

**해결**
DB 파일을 완전히 삭제 후 비밀번호 설정:
```bash
sudo systemctl stop neo4j
sudo rm -rf /var/lib/neo4j/data
sudo mkdir -p /var/lib/neo4j/data
sudo chown -R neo4j:neo4j /var/lib/neo4j
sudo neo4j-admin dbms set-initial-password neo4j1234
sudo systemctl start neo4j
```
Playbook의 `creates: /var/lib/neo4j/data/dbms/auth` 조건으로
이미 설정된 경우 건너뜀 처리.

---

## #11. PowerShell에서 복잡한 WSL 명령어 파싱 오류

**증상**
```
위치 줄:1 문자:262
InvalidEndOfLine [], ParentContainsErrorRecordException
```
또는
```
/bin/bash: -c: line 1: unexpected EOF while looking for matching `''
```

**원인**
PowerShell은 WSL에 전달하는 명령어에서 `$`, `"`, `'` 등 특수문자를 자체적으로 해석.
특히 `for ... do` 루프, `\$s`, 중첩 따옴표가 포함된 복잡한 명령어는
PowerShell이 중간에 파싱하여 bash로 전달되는 내용이 달라짐.

**해결**
복잡한 로직은 별도 `.sh` 스크립트 파일로 작성 후 WSL에서 실행:
```bash
# 스크립트 파일 작성 후
wsl bash -c "bash /mnt/c/project/onprem-ops-engine/check-infra.sh > /tmp/result.log 2>&1"
```
→ `check-infra.sh` 스크립트로 5대 노드 전체 상태를 한번에 확인.

---

## #12. liboqs Shield 노드 미설치 및 shared library 경로 문제

**증상**
```
liboqs: 미설치
pqc_demo: 미빌드
```
컴파일 후 실행 시:
```
error while loading shared libraries: liboqs.so.9: cannot open shared object file
```

**원인**
1. Ansible `ignore_errors: yes`로 인해 ninja-build 없이 silently 실패
2. `ldconfig`를 실행하지 않아 `/usr/local/lib/liboqs.so`가 캐시에 등록 안 됨

**해결**
```bash
# 의존성 재설치
sudo apt-get install -y cmake ninja-build gcc git libssl-dev

# liboqs 클론 및 빌드
cd /opt/liboqs
sudo cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -GNinja
sudo cmake --build build --parallel
sudo cmake --install build

# 공유 라이브러리 경로 등록 (핵심)
sudo ldconfig

# pqc_demo 컴파일 및 실행
sudo gcc -o /opt/pqc_demo /opt/pqc_demo.c -loqs -lssl -lcrypto -I/usr/local/include/oqs
sudo /opt/pqc_demo
```

**결과**
```
[PQC-DEMO] Starting Kyber-512 Key Exchange Simulation...
[PQC-DEMO] Keypair generated successfully.
[PQC-DEMO] Secret encapsulated in ciphertext.
[PQC-DEMO] Secret decapsulated successfully.
[PQC-DEMO] Verification SUCCESS: Shared secrets match! ✅
```
Playbook에 `ldconfig` 태스크 추가 및 `ninja-build` 의존성 명시 반영 완료.
