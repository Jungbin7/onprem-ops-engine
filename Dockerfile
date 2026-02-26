# =============================================================================
# E-Commerce Resilience Platform — Dockerfile
# =============================================================================
# [멀티스테이지 빌드 선택 이유]
#   - builder 스테이지에서 컴파일/pip install 수행
#   - runtime 스테이지에 필요한 파일만 복사
#   - 결과: 이미지 크기 ~70% 절감, 빌드 도구가 runtime에 없어 보안 attack surface 최소화
#
# [python:3.11-slim 선택 이유]
#   - Alpine 대비 glibc 포함 → psycopg2, httpx 등 C 확장 호환성 보장
#   - slim: dev 패키지 미포함으로 최소 사이즈 유지
# =============================================================================

# ── Stage 1: Builder ─────────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# 의존성 파일만 먼저 복사 → Docker layer cache 활용 (코드 변경 시 재설치 방지)
COPY app/requirements.txt .

# --no-cache-dir: 캐시 저장 파일 제거 → 이미지 크기 절감
# --user: /root/.local에 설치 → site-packages 오염 방지
RUN pip install --no-cache-dir --user -r requirements.txt

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

# [non-root 유저 선택 이유]
#   - root로 실행 시 컨테이너 탈출 취약점이 호스트 root 권한으로 직결
#   - 프로덕션 보안 기본 원칙: least privilege
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --no-create-home appuser

WORKDIR /app

# builder 스테이지의 pip 설치 결과물만 복사
COPY --from=builder /root/.local /home/appuser/.local

# 애플리케이션 코드 복사
COPY app/ .

# 파일 소유권 변경
RUN chown -R appuser:appgroup /app

USER appuser

# PATH에 --user 설치 경로 추가
ENV PATH="/home/appuser/.local/bin:${PATH}" \
    PYTHONPATH="/home/appuser/.local/lib/python3.11/site-packages" \
    PYTHONUNBUFFERED=1

# [포트 8000 선택 이유]
#   - FastAPI/uvicorn 기본 포트. 앱 내부에서 변경 없이 k8s Service와 일치
EXPOSE 8000

# [HEALTHCHECK 추가 이유]
#   - Docker 자체적으로 컨테이너 헬스 상태 관리 (k8s livenessProbe와 이중 보호)
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["python", "main.py"]
