"""
E-Commerce Resilience Platform — FastAPI Application
=====================================================
[아키텍처 결정]
- FastAPI: 비동기 I/O + Pydantic 자동 검증 + OpenAPI /docs 자동 생성
  Django 대비: 동기 ORM 불필요. Flask 대비: 타입 안전성 확보
- prometheus_client: /metrics 엔드포인트로 Prometheus scrape 지원
  수동 로그 파싱 대비: 실시간 타임시리즈 + Alerting 연동 가능
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import psycopg2, psycopg2.extras
import redis, os, time, uuid, random, logging, httpx

# ── Prometheus 메트릭 계측 ──────────────────────────────────────────────────
# [prometheus_client 선택 이유]
#   - Prometheus scrape 표준. push 방식 대비 pull 방식이 서버 부하 제어 용이
#   - Counter: 단조 증가 카운터 (요청 수, 에러 수) — reset 되지 않아 rate() 계산에 신뢰성
#   - Histogram: 응답시간 분포 측정. 평균이 아닌 p95/p99로 실사용자 체감 측정
#   - Gauge: 현재 값 (Pod 수, 재고 등) — 증감 모두 가능
from prometheus_client import (
    Counter, Histogram, Gauge,
    make_asgi_app, CONTENT_TYPE_LATEST, generate_latest
)

# ─────────────────────────────────────────────────────────────────────────────
# 메트릭 정의
# [http_requests_total 선택 이유]
#   endpoint, method, status 레이블로 분리 → 특정 엔드포인트의 에러율 집계 가능
#   예: rate(http_requests_total{status="500"}[1m]) → 실시간 5xx 알람 기준
# ─────────────────────────────────────────────────────────────────────────────
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP request count",
    ["method", "endpoint", "status"]
)

# [http_request_duration_seconds 선택 이유]
#   Histogram으로 p50/p95/p99 계산. 평균은 아웃라이어가 있을 때 왜곡됨.
#   SLA: "95%의 요청이 500ms 이내" 같은 기준을 실측으로 검증
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["endpoint"],
    buckets=[0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)

# [active_orders_total 선택 이유]
#   비즈니스 KPI를 기술 메트릭과 동일 대시보드에서 연결. 트래픽 급증 ↔ 주문 폭증 상관관계 시각화
ORDER_COUNT = Counter(
    "ecommerce_orders_total",
    "Total orders processed"
)

# [ecommerce_errors_total 선택 이유]
#   5xx만이 아닌 비즈니스 에러(재고 부족, 상품 없음)도 분류해서 추적
ERROR_COUNT = Counter(
    "ecommerce_errors_total",
    "Total application errors",
    ["error_type"]  # "db_error", "redis_error", "not_found", "stock_insufficient"
)

DB_CONNECTION_FAILURES = Counter(
    "ecommerce_db_connection_failures_total",
    "Database connection failures"
)

# ─────────────────────────────────────────────────────────────────────────────

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="E-Commerce Resilience Platform",
    version="3.0.0",
    description="""
## 온프레미스 AI 기반 e커머스 복원력 플랫폼

### 기술 스택 선택 근거
- **FastAPI**: 비동기 I/O, Pydantic 자동 검증, /docs 자동 생성
- **PostgreSQL 16**: pgvector 내장, JSONB 인덱스, 우수한 트랜잭션 격리
- **Redis**: Pub/Sub + HA. 캐시·카운터 단일 레이어
- **Neo4j**: 주문-결제-배송 인과 체인을 그래프로 O(1) 탐색
- **Prometheus /metrics**: Grafana 대시보드의 모든 패널 데이터 소스
"""
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"]
)

# ── Prometheus 미들웨어 ───────────────────────────────────────────────────────
@app.middleware("http")
async def prometheus_middleware(request: Request, call_next):
    """
    모든 HTTP 요청에 대해 자동으로 메트릭 기록.
    [미들웨어 방식 선택 이유]
      - 각 엔드포인트에 개별 계측 코드 삽입 불필요 → DRY 원칙
      - 메트릭 누락 방지 (새 엔드포인트 추가 시 자동 적용)
    """
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time

    endpoint = request.url.path
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=endpoint,
        status=str(response.status_code)
    ).inc()
    REQUEST_LATENCY.labels(endpoint=endpoint).observe(duration)

    return response

# ── Prometheus /metrics 엔드포인트 ──────────────────────────────────────────
@app.get("/metrics")
def metrics():
    """
    Prometheus scrape 엔드포인트.
    [설계 결정]
      - GET /metrics → text/plain 형식으로 메트릭 노출
      - Prometheus가 15초마다 이 엔드포인트를 pull (push 방식 대비: 서버가 부하 제어 주도권 가짐)
      - Grafana는 Prometheus를 데이터소스로 사용해 이 값을 시각화
    """
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )

# ── DB 연결 ──────────────────────────────────────────────────────────────────
PG_HOST = os.getenv("PG_HOST", "192.168.174.30")
PG_PORT = os.getenv("PG_PORT", "5432")
PG_DB   = os.getenv("PG_DB",   "ecommerce")
PG_USER = os.getenv("PG_USER", "ecommerce")
PG_PASS = os.getenv("PG_PASS", "ecommerce2026")

NEO4J_HOST  = os.getenv("NEO4J_HOST",  "192.168.174.10")
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "192.168.174.10")


def get_pg():
    """
    [connect_timeout=3 이유]
      - DB 연결 hang 방지. 3초 내 응답 없으면 fast-fail → 다른 Pod에서 처리 가능
    """
    try:
        return psycopg2.connect(
            host=PG_HOST, port=PG_PORT, dbname=PG_DB,
            user=PG_USER, password=PG_PASS,
            connect_timeout=3
        )
    except Exception as e:
        DB_CONNECTION_FAILURES.inc()
        raise


def get_redis():
    """
    [Redis 선택 이유]
      - Memcached 대비: Pub/Sub, Sorted Set, HA Sentinel/Cluster 지원
      - 카운터(order_count), 캐시(product_views)를 단일 레이어로 처리
    """
    try:
        r = redis.Redis(
            host=os.getenv("REDIS_HOST", "redis-service"),
            port=6379,
            decode_responses=True,
            socket_connect_timeout=2  # 빠른 실패로 전체 요청 지연 방지
        )
        r.ping()
        return r
    except Exception:
        ERROR_COUNT.labels(error_type="redis_error").inc()
        return None


# ── 요청 모델 ─────────────────────────────────────────────────────────────────
class OrderRequest(BaseModel):
    product_id: int
    quantity: int = 1
    customer_email: Optional[str] = "guest@example.com"


# ── API 엔드포인트 ────────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {
        "service": "E-Commerce Resilience Platform",
        "version": "3.0.0",
        "monitoring": "GET /metrics (Prometheus scrape endpoint)",
        "endpoints": {
            "health":    "GET  /health",
            "metrics":   "GET  /metrics  ← Prometheus scrape",
            "products":  "GET  /products",
            "order":     "POST /orders",
            "history":   "GET  /orders/history",
            "summary":   "GET  /metrics/summary",
            "stress":    "GET  /stress   ← HPA 부하 테스트용",
            "analyze":   "GET  /analyze/failures ← Graph RAG + LLM",
        }
    }


@app.get("/health")
def health():
    """
    [헬스체크 엔드포인트 설계]
      - k8s livenessProbe + readinessProbe 대상
      - 단순 200 OK가 아닌 실제 DB/Redis 연결 상태 포함
      - 이 값이 Grafana "서비스 헬스" 패널의 기반
    """
    status = {"api": "healthy", "timestamp": time.time(), "version": "3.0.0"}
    try:
        conn = get_pg()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        conn.close()
        status["postgresql"] = "connected"
    except Exception as e:
        status["postgresql"] = f"error: {str(e)[:60]}"

    r = get_redis()
    status["redis"] = "connected" if r else "unavailable"
    return status


@app.get("/products")
def list_products():
    try:
        conn = get_pg()
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("SELECT id, name, price, stock FROM products ORDER BY id")
        products = [dict(row) for row in cur.fetchall()]
        conn.close()

        r = get_redis()
        views = r.incr("product_views") if r else "N/A"
        return {"products": products, "total_views": views, "source": "postgresql"}
    except Exception as e:
        ERROR_COUNT.labels(error_type="db_error").inc()
        raise HTTPException(status_code=503, detail=f"DB 오류: {str(e)}")


@app.post("/orders")
def create_order(req: OrderRequest, background_tasks: BackgroundTasks):
    """
    [트랜잭션 설계]
      - FOR UPDATE: 동시 주문 시 재고 race condition 방지 (pessimistic locking)
      - backgroundTasks: Neo4j 기록은 주문 응답과 분리 (non-critical path)
      - 주문 완료 시 ORDER_COUNT.inc() → Grafana "주문 처리량" 패널 업데이트
    """
    try:
        conn = get_pg()
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        cur.execute("SELECT * FROM products WHERE id = %s FOR UPDATE", (req.product_id,))
        product = cur.fetchone()
        if not product:
            conn.close()
            ERROR_COUNT.labels(error_type="not_found").inc()
            raise HTTPException(status_code=404, detail="상품을 찾을 수 없습니다")
        if product["stock"] < req.quantity:
            conn.close()
            ERROR_COUNT.labels(error_type="stock_insufficient").inc()
            raise HTTPException(status_code=400, detail="재고가 부족합니다")

        cur.execute("SELECT id FROM customers WHERE email = %s", (req.customer_email,))
        customer = cur.fetchone()
        if not customer:
            cur.execute(
                "INSERT INTO customers (name, email) VALUES (%s, %s) RETURNING id",
                (req.customer_email.split("@")[0], req.customer_email)
            )
            customer = cur.fetchone()

        total = product["price"] * req.quantity
        cur.execute(
            """INSERT INTO orders (customer_id, product_id, quantity, total_price, status)
               VALUES (%s, %s, %s, %s, 'confirmed') RETURNING id""",
            (customer["id"], req.product_id, req.quantity, total)
        )
        order = cur.fetchone()
        order_id = str(order["id"])

        cur.execute(
            "INSERT INTO payments (order_id, amount, status) VALUES (%s, %s, 'completed')",
            (order_id, total)
        )
        cur.execute(
            "UPDATE products SET stock = stock - %s WHERE id = %s",
            (req.quantity, req.product_id)
        )
        conn.commit()
        conn.close()

        r = get_redis()
        if r:
            r.incr("order_count")

        # Prometheus 주문 카운터 증가 → Grafana "주문 처리량" 패널
        ORDER_COUNT.inc()

        background_tasks.add_task(
            record_neo4j_relation,
            str(customer["id"]), order_id,
            req.product_id, str(product["name"]), total
        )

        time.sleep(random.uniform(0.01, 0.05))

        return {
            "order_id":    order_id,
            "product":     product["name"],
            "quantity":    req.quantity,
            "total_price": total,
            "status":      "confirmed",
            "source":      "postgresql"
        }
    except HTTPException:
        raise
    except Exception as e:
        ERROR_COUNT.labels(error_type="db_error").inc()
        raise HTTPException(status_code=500, detail=f"주문 처리 오류: {str(e)}")


@app.get("/orders/history")
def order_history(limit: int = 20):
    try:
        conn = get_pg()
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("""
            SELECT o.id, c.email, p.name as product, o.quantity,
                   o.total_price, o.status, o.created_at
            FROM orders o
            JOIN customers c ON o.customer_id = c.id
            JOIN products p ON o.product_id = p.id
            ORDER BY o.created_at DESC LIMIT %s
        """, (limit,))
        orders = [dict(row) for row in cur.fetchall()]
        conn.close()
        for o in orders:
            o["id"] = str(o["id"])
            o["created_at"] = str(o["created_at"])
        return {"orders": orders, "count": len(orders)}
    except Exception as e:
        ERROR_COUNT.labels(error_type="db_error").inc()
        raise HTTPException(status_code=503, detail=f"DB 오류: {str(e)}")


@app.get("/metrics/summary")
def metrics_summary():
    """비즈니스 KPI 집계 (Prometheus 외 별도 비즈니스 메트릭)"""
    data = {}
    try:
        conn = get_pg()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM orders")
        data["total_orders_db"] = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM orders WHERE status='confirmed'")
        data["confirmed_orders"] = cur.fetchone()[0]
        cur.execute("SELECT COALESCE(SUM(total_price),0) FROM orders")
        data["total_revenue"] = cur.fetchone()[0]
        conn.close()
    except Exception as e:
        data["db_error"] = str(e)[:60]

    r = get_redis()
    data["redis_order_count"]   = r.get("order_count")   if r else "N/A"
    data["redis_product_views"] = r.get("product_views") if r else "N/A"
    return data


@app.get("/stress")
def stress_endpoint():
    """
    [HPA 부하 테스트용 엔드포인트]
      - CPU 집약 연산으로 HPA CPU 임계치(70%) 트리거용
      - k6 시나리오에서 집중 호출 → Pod 2개 → 6개 스케일아웃 데모
    """
    result = sum(i * i for i in range(50000))
    return {"computed": result, "status": "ok"}


@app.get("/analyze/failures")
def analyze_failures():
    """
    [Graph RAG 설계 결정]
      - PostgreSQL: 상위 5개 주문 패턴 집계 (관계형 집계)
      - Neo4j: Customer→Order→Product 인과 체인 쿼리 (그래프 탐색)
      - Ollama llama2: 로컬 LLM 추론 → 결제 데이터 외부 전송 0
        (OpenAI API 대비: 결제 정보 외부 전송 = 보안 위반)
    [Graph RAG vs 벡터 RAG]
      - 벡터 RAG: 임베딩 유사도 검색 → 관계 추론 부정확, 환각 가능
      - Graph RAG: Cypher 쿼리 결과를 프롬프트에 주입 → 정확한 관계 기반 추론
    """
    try:
        conn = get_pg()
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("""
            SELECT p.name, COUNT(o.id) as order_count,
                   SUM(o.total_price) as revenue, p.stock
            FROM orders o JOIN products p ON o.product_id = p.id
            GROUP BY p.id, p.name, p.stock ORDER BY order_count DESC LIMIT 5
        """)
        top_products = [dict(r) for r in cur.fetchall()]
        conn.close()

        prompt = (
            "이커머스 플랫폼 주문 현황:\n" + str(top_products) +
            "\n\n재고 부족 위험이나 판매 패턴 이상을 간단히 설명해 주세요."
        )
        ollama_url = f"http://{OLLAMA_HOST}:11434/api/generate"
        resp = httpx.post(
            ollama_url,
            json={"model": "llama2", "prompt": prompt, "stream": False},
            timeout=30.0
        )
        analysis = resp.json().get("response", "분석 응답 없음")
        return {
            "top_products": top_products,
            "ai_analysis":  analysis[:500],
            "model":        "llama2 (local — no external data transmission)"
        }
    except Exception as e:
        return {"error": str(e)[:200], "hint": "Ollama 또는 DB 연결 확인 필요"}


def record_neo4j_relation(customer_id, order_id, product_id, product_name, amount):
    """
    [Neo4j 선택 이유]
      - RDBMS(PostgreSQL)로 Customer→Order→Product 관계를 탐색하려면 3-JOIN 필요
      - 관계 깊이가 깊어질수록 조인 비용이 지수적으로 증가
      - Neo4j: 그래프 탐색 O(1). Cypher 쿼리로 인과 체인 직관적 표현
    [백그라운드 태스크 이유]
      - 주문 응답 경로에서 제거 → 응답 지연 방지 (non-critical path)
      - Neo4j 일시 장애 시 주문 처리에 영향 없음
    """
    try:
        cypher = (
            f"MERGE (c:Customer {{id: '{customer_id}'}}) "
            f"MERGE (p:Product {{id: {product_id}, name: '{product_name}'}}) "
            f"MERGE (o:Order {{id: '{order_id}', amount: {amount}}}) "
            f"MERGE (c)-[:PLACED]->(o) "
            f"MERGE (o)-[:CONTAINS]->(p)"
        )
        neo4j_url = f"http://{NEO4J_HOST}:7474/db/neo4j/tx/commit"
        httpx.post(
            neo4j_url,
            json={"statements": [{"statement": cypher}]},
            auth=("neo4j", "neo4j1234"),
            timeout=5.0
        )
    except Exception as e:
        logger.warning(f"Neo4j 기록 실패 (non-critical): {e}")


if __name__ == "__main__":
    import uvicorn
    # [uvicorn workers=1 이유]
    #   - k8s는 Pod 복제로 수평 확장 → 단일 프로세스 단순화
    #   - 복수 worker 프로세스 방식은 k8s HPA와 이중 확장이 되어 리소스 낭비
    uvicorn.run(app, host="0.0.0.0", port=8000, workers=1)
