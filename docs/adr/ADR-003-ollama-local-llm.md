# ADR-003: AI 추론 엔진으로 Ollama 로컬 LLM 선택

## 상태 (Status)
**Accepted** — 2026-02-20

## 컨텍스트 (Context)

주문 데이터와 그래프 관계를 LLM에 분석시켜야 한다.
결제·주문 데이터는 PII(개인식별정보)를 포함하므로 외부 API 전송이 데이터 보안 정책 위반이다.

## 결정 (Decision)

**Ollama (llama2 7B 모델)** 을 brain 노드(192.168.174.10)에서 로컬 실행한다.

## 고려한 대안 (Alternatives Considered)

| 솔루션 | 비용 | 데이터 보안 | 추론 품질 | 지연 |
|--------|------|-------------|-----------|------|
| **OpenAI API (GPT-4o)** | $$$  | ❌ 외부 전송 | ⭐⭐⭐⭐⭐ | ~2s |
| **AWS SageMaker** (팀 프로젝트) | $$  | △ AWS 내 | ⭐⭐⭐⭐ | ~1s |
| **Ollama llama2 (7B)** ✅ | $0 | ✅ 로컬 | ⭐⭐⭐ | ~3-5s |
| **Hugging Face Inference API** | $ | ❌ 외부 전송 | ⭐⭐⭐⭐ | ~3s |

## 근거 (Rationale)

### 1. 데이터 보안 (핵심 이유)
```
결제 데이터 → OpenAI API 전송
= 고객 결제 정보 외부 유출
= GDPR Art. 46, 한국 개인정보보호법 위반 가능

결제 데이터 → Ollama(localhost:11434)
= 네트워크 패킷이 내부 LAN을 벗어나지 않음
= Zero-trust 아키텍처와 일치
```

### 2. 팀 프로젝트와의 차별점
- 팀 프로젝트: AWS SageMaker → 매니지드 ML 서비스, 비용 발생
- 이 프로젝트: Ollama 자체 운영 → MLOps 운영 경험, 비용 $0

### 3. 이 프로젝트에서 LLM 역할
```python
# /analyze/failures 엔드포인트
# PostgreSQL에서 집계한 정형 데이터를 프롬프트로 변환
prompt = "이커머스 플랫폼 주문 현황:\n" + str(top_products) + \
         "\n\n재고 부족 위험이나 판매 패턴 이상을 간단히 설명해 주세요."

# Ollama API (로컬, 외부 전송 없음)
resp = httpx.post("http://192.168.174.10:11434/api/generate",
    json={"model": "llama2", "prompt": prompt, "stream": False})
```

### 4. 7B 파라미터 모델로 충분한 이유
- 이 작업: 구조화된 테이블 데이터 → 자연어 요약 (단순 생성 과제)
- GPT-4 수준의 복잡한 추론 불필요
- RAM: llama2 7B = ~4GB (brain 노드 4GB RAM에서 동작)

## 결과 (Consequences)

- brain 노드에 `ollama serve` 상시 실행 필요 (systemd 서비스 등록)
- 추론 지연: 3-5초 (비동기 처리로 UX 영향 없음)
- 면접 포인트: "온프레미스 AI 추론으로 데이터 보안과 비용 모두 해결" 설명 가능
