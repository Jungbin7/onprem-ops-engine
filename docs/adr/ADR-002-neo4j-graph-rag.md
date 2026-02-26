# ADR-002: 주문-결제-배송 인과 분석에 Neo4j + Graph RAG 선택

## 상태 (Status)
**Accepted** — 2026-02-20

## 컨텍스트 (Context)

e커머스 플랫폼에서 "왜 이 고객의 주문이 지연됐는가?" 같은 인과 관계 질의가 필요하다.
PostgreSQL로만 구현 시 Customer → Order → Payment → Shipment 4-depth JOIN이 필요하다.

## 결정 (Decision)

**Neo4j Community Edition + Graph RAG 패턴** 으로 인과 관계 분석을 구현한다.

## 고려한 대안 (Alternatives Considered)

| 방법 | 장점 | 단점 |
|------|------|------|
| **PostgreSQL JOIN** | 기존 인프라 활용 | 관계 깊이 증가 시 쿼리 비용 지수적 증가 |
| **벡터 RAG (pgvector)** | 의미 기반 검색 | 관계 추론 부정확, 환각(hallucination) 가능 |
| **Neo4j + Graph RAG** ✅ | O(1) 그래프 탐색, Cypher 직관적 | 추가 DB 운영 비용 |

## 근거 (Rationale)

### 1. 관계형 DB의 다중 JOIN 문제
```sql
-- PostgreSQL: 주문 실패 원인 추적 (4-depth)
SELECT *
FROM customers c
JOIN orders o ON c.id = o.customer_id
JOIN payments p ON o.id = p.order_id
JOIN shipments s ON o.id = s.order_id
WHERE c.id = 123 AND s.status = 'delayed';
-- 인덱스 있어도 데이터 증가 시 성능 저하
```

```cypher
-- Neo4j: 동일 질의 (Cypher)
MATCH (c:Customer {id: 123})-[:PLACED]->(o:Order)-[:CONTAINS]->(p:Product)
WHERE o.status = 'delayed'
RETURN c, o, p
-- 그래프 탐색: O(1) ~O(관계 수), 데이터 크기에 비례하지 않음
```

### 2. Graph RAG vs 벡터 RAG

```
벡터 RAG:
  User Query → 임베딩 → 유사도 검색 → 관련 문서 → LLM
  문제: "주문 → 결제 → 배송" 인과 순서를 임베딩이 표현 못함

Graph RAG (이 프로젝트):
  User Query → Cypher 쿼리 → 정확한 관계 데이터 → LLM 프롬프트 주입
  장점: 환각 없음. 실제 DB 데이터 기반 → 결과 신뢰성 보장
```

### 3. Ollama 로컬 LLM과의 조합
- 결제 데이터를 OpenAI API로 전송 = GDPR/데이터 보안 위반
- Neo4j에서 추출한 구조화 데이터 + Ollama llama2(로컬) = 외부 전송 0

## 구현 (Implementation)

```python
# app/main.py — record_neo4j_relation()
cypher = (
    f"MERGE (c:Customer {{id: '{customer_id}'}}) "
    f"MERGE (p:Product {{id: {product_id}}}) "
    f"MERGE (o:Order {{id: '{order_id}'}}) "
    f"MERGE (c)-[:PLACED]->(o) "
    f"MERGE (o)-[:CONTAINS]->(p)"
)
# BackgroundTask로 실행 → 주문 응답 지연 없음
```

## 결과 (Consequences)

- Neo4j Community Edition을 brain 노드(192.168.174.10)에 추가 운영
- `/analyze/failures` 엔드포인트: PostgreSQL 집계 + Neo4j 그래프 + Ollama 추론 파이프라인
- 면접 질문 대비: "벡터 RAG와 Graph RAG의 차이를 실제 구현해봤다"는 구체적 경험 보유
