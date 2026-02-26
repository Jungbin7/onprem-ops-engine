# ADR-004: API 보안 레이어로 PQC Kyber-512 (CRYSTALS-Kyber) 선택

## 상태 (Status)
**Accepted** — 2026-02-20

## 컨텍스트 (Context)

양자 컴퓨터는 2030년대 상용화가 예측되며, RSA/ECC 기반 TLS는 Shor's Algorithm으로 해독 가능하다.
"Harvest Now, Decrypt Later" 공격: 현재 암호화된 트래픽을 저장 후 양자 컴퓨터로 나중에 복호화.
결제 데이터는 10년 이상 보안이 필요한 장기 민감 데이터이므로 PQC 대비가 필요하다.

## 결정 (Decision)

**CRYSTALS-Kyber-512 (ML-KEM, NIST PQC 표준 FIPS 203)** 을 API 키 캡슐화 레이어에 적용한다.

## 고려한 대안 (Alternatives Considered)

| 알고리즘 | 표준화 | 키 크기 | 성능 | 비고 |
|----------|--------|---------|------|------|
| **RSA-4096** | PKCS#1 | 512 bytes (공개키) | 느림 | 양자 취약 |
| **ECDH P-256** | RFC 6090 | 64 bytes | 빠름 | 양자 취약 (Shor) |
| **Kyber-512** ✅ | NIST FIPS 203 | 800 bytes | RSA보다 빠름 | 양자 내성 |
| **NTRU** | IEEE 1363.1 | 가변 | 빠름 | 미국 표준 아님 |
| **McEliece** | - | 수백KB | 느림 | 키 크기 비실용적 |

## 근거 (Rationale)

### 1. NIST 표준 준수
```
2022: NIST PQC 표준화 최종 후보 발표
2024: FIPS 203 (Kyber = ML-KEM) 공식 표준 확정
→ 표준화된 알고리즘 = 라이브러리 지원 보장, 규정 준수
```

### 2. Kyber-512 선택 근거 (vs Kyber-768, Kyber-1024)
```
Kyber-512: NIST 레벨 1 (AES-128 동등 보안) → 이 프로젝트 충분
Kyber-768: NIST 레벨 3 (AES-192)            → 금융·정부 기관 권장
Kyber-1024: NIST 레벨 5 (AES-256)           → 최고 기밀 수준
```

### 3. 팀 프로젝트와 차별화
- 팀 프로젝트: AWS WAF + KMS (현재 표준 보안)
- 이 프로젝트: PQC 레이어 추가 → "Post-Quantum 대비 아키텍처" 차별점

### 4. 구현 범위 (현실적 제약 인정)
```python
# scripts/pqc-handshake-demo.py
# liboqs-python 사용 (Open Quantum Safe 프로젝트)
import oqs

# 키 생성 (서버)
server_kem = oqs.KeyEncapsulation("Kyber512")
public_key = server_kem.generate_keypair()

# 캡슐화 (클라이언트) → 공유 비밀 생성
client_kem = oqs.KeyEncapsulation("Kyber512")
ciphertext, shared_secret_client = client_kem.encap_secret(public_key)

# 복호화 (서버) → 동일한 공유 비밀 획득
shared_secret_server = server_kem.decap_secret(ciphertext)
assert shared_secret_client == shared_secret_server
```

## 범위 제한 (Scope Limitation)

전체 TLS 스택을 PQC로 교체하지는 않는다:
- 이유: OpenSSL TLS 1.3 + Kyber 하이브리드 모드는 아직 표준 브라우저 미지원
- 실제 구현: API 키 교환 레이어에서 Kyber-512로 세션 키 캡슐화 시연
- 이 접근은 Google Chrome의 X25519Kyber768 하이브리드 방식과 동일한 철학

## 결과 (Consequences)

- `liboqs` Python 바인딩 추가 (requirements에 미포함, 별도 시연 스크립트)
- 면접 포인트: "NIST FIPS 203 표준 이해, Harvest Now Decrypt Later 위협 모델 설명"
- 현실적 차별점: PQC를 **알고** **시뮬레이션까지 구현**한 엔지니어 포지셔닝
