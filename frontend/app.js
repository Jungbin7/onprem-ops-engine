// ── 설정 ─────────────────────────────────────────────────────
let API_BASE = 'http://192.168.174.20:30080';
let selectedProduct = null;

function updateApiHost() {
    API_BASE = document.getElementById('api-host-input').value.trim();
    showToast('API 주소 변경됨: ' + API_BASE);
    loadDashboard();
}

function openSwagger() {
    window.open(API_BASE + '/docs', '_blank');
}

// ── 탭 전환 ──────────────────────────────────────────────────
function showTab(name) {
    const names = ['dashboard', 'products', 'history', 'infra'];
    document.querySelectorAll('.tab').forEach((t, i) => t.classList.toggle('active', names[i] === name));
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    document.getElementById('page-' + name).classList.add('active');
    if (name === 'products') loadProducts();
    if (name === 'history') loadHistory();
    if (name === 'dashboard') loadDashboard();
}

// ── Toast ─────────────────────────────────────────────────────
function showToast(msg) {
    const t = document.getElementById('toast');
    t.innerHTML = msg;
    t.classList.add('show');
    setTimeout(() => t.classList.remove('show'), 3500);
}

// ── 숫자 포맷 ─────────────────────────────────────────────────
function fmt(n) { return Number(n || 0).toLocaleString('ko-KR') + '원'; }

// ── 공통 fetch ────────────────────────────────────────────────
async function api(path, opts = {}) {
    const r = await fetch(API_BASE + path, {
        signal: AbortSignal.timeout(6000), ...opts
    });
    return r.json();
}

// ── 대시보드 로드 ──────────────────────────────────────────────
async function loadDashboard() {
    const dot = document.getElementById('status-dot');
    const txt = document.getElementById('api-status-text');

    // Health check
    try {
        const h = await api('/health');
        dot.className = 'status-dot online';
        txt.textContent = 'API 정상 (' + (h.postgresql === 'connected' ? 'PG ✓' : 'PG ✗') + ')';

        // PG badge on infra tab
        const pgBadge = document.getElementById('pg-badge');
        if (h.postgresql === 'connected') {
            pgBadge.textContent = 'connected'; pgBadge.className = 'badge badge-green';
        } else {
            pgBadge.textContent = h.postgresql || '?'; pgBadge.className = 'badge badge-red';
        }
        document.getElementById('body-api').textContent = 'Running';
        document.getElementById('body-api').className = 'badge badge-green';

        document.getElementById('m-pg').textContent = h.postgresql === 'connected' ? '✅ Connected' : '❌ ' + h.postgresql;
        document.getElementById('m-redis-status').textContent = 'Redis: ' + (h.redis || '?');
    } catch (e) {
        dot.className = 'status-dot offline';
        txt.textContent = 'API 연결 실패';
        document.getElementById('m-pg').textContent = '❌ offline';
        return;
    }

    // Metrics
    try {
        const m = await api('/metrics/summary');
        document.getElementById('m-orders').textContent = m.total_orders_db ?? '—';
        document.getElementById('m-revenue').textContent = m.total_revenue ? fmt(m.total_revenue) : '—';
        document.getElementById('m-views').textContent = m.redis_product_views ?? '—';
    } catch (e) { }

    // Recent orders
    try {
        const o = await api('/orders/history?limit=5');
        const tbody = document.getElementById('dashboard-orders');
        tbody.innerHTML = '';
        if (!o.orders?.length) {
            tbody.innerHTML = '<tr><td colspan="6" class="empty-cell">아직 주문이 없습니다. <b>상품/주문 탭</b>에서 첫 주문을 해보세요!</td></tr>';
            return;
        }
        o.orders.forEach(ord => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
        <td style="font-family:'JetBrains Mono';font-size:.72rem;color:var(--muted)">${ord.id.substring(0, 8)}…</td>
        <td>${ord.email}</td>
        <td>${ord.product}</td>
        <td style="font-family:'JetBrains Mono'">${fmt(ord.total_price)}</td>
        <td><span class="badge badge-green">${ord.status}</span></td>
        <td style="color:var(--muted);font-size:.8rem">${(ord.created_at || '').substring(0, 16)}</td>`;
            tbody.appendChild(tr);
        });
    } catch (e) { }
}

// ── 상품 로드 ──────────────────────────────────────────────────
async function loadProducts() {
    const grid = document.getElementById('product-grid');
    grid.innerHTML = '<div class="empty-cell"><span class="spinner"></span> 로딩 중...</div>';
    try {
        const d = await api('/products');
        grid.innerHTML = '';
        d.products.forEach(p => {
            const maxStock = 300;
            const pct = Math.min(100, Math.round(p.stock / maxStock * 100));
            const low = p.stock < 30;
            const card = document.createElement('div');
            card.className = 'product-card';
            card.id = 'prod-' + p.id;
            card.innerHTML = `
        <div class="product-name">${p.name}</div>
        <div class="product-price">${fmt(p.price)}</div>
        <div class="product-stock">재고: <b>${p.stock}</b>개 ${low ? '<span class="badge badge-red">부족</span>' : ''}</div>
        <div class="stock-bar"><div class="stock-fill" style="width:${pct}%;background:${low ? 'var(--red)' : 'var(--green)'}"></div></div>`;
            card.onclick = () => selectProduct(p);
            grid.appendChild(card);
        });
    } catch (e) {
        grid.innerHTML = '<div class="empty-cell" style="color:var(--red)">API 연결 실패: ' + e.message + '<br><small>' + API_BASE + '/products</small></div>';
    }
}

function selectProduct(p) {
    selectedProduct = p;
    document.querySelectorAll('.product-card').forEach(c => c.classList.remove('selected'));
    document.getElementById('prod-' + p.id)?.classList.add('selected');
    document.getElementById('sel-product').value = p.name + ' · ' + fmt(p.price);
}

// ── 주문 ───────────────────────────────────────────────────────
async function placeOrder() {
    if (!selectedProduct) { showToast('⚠️ 상품을 먼저 선택하세요'); return; }
    const qty = parseInt(document.getElementById('order-qty').value) || 1;
    const email = document.getElementById('order-email').value || 'guest@demo.com';
    const resultEl = document.getElementById('order-result');
    resultEl.style.display = 'block';
    resultEl.innerHTML = '<span class="spinner"></span> 주문 처리 중 (PostgreSQL 저장)...';

    try {
        const r = await fetch(API_BASE + '/orders', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ product_id: selectedProduct.id, quantity: qty, customer_email: email }),
            signal: AbortSignal.timeout(10000)
        });
        const d = await r.json();
        if (r.ok) {
            resultEl.innerHTML = `
        <div style="display:flex;gap:1.5rem;flex-wrap:wrap">
          <span>🎉 <b>주문 완료!</b></span>
          <span>주문 ID: <code style="font-family:'JetBrains Mono';font-size:.78rem">${d.order_id?.substring(0, 8)}…</code></span>
          <span>상품: <b>${d.product}</b></span>
          <span>금액: <b style="color:var(--accent)">${fmt(d.total_price)}</b></span>
          <span class="badge badge-green">${d.status}</span>
          <span class="badge badge-blue">${d.source}</span>
        </div>`;
            showToast('✅ 주문 완료! PostgreSQL 저장 + Neo4j 관계 기록');
            loadProducts();
            setTimeout(loadDashboard, 1000);
        } else {
            resultEl.innerHTML = '❌ <span style="color:var(--red)">' + (d.detail || JSON.stringify(d)) + '</span>';
        }
    } catch (e) {
        resultEl.innerHTML = '❌ <span style="color:var(--red)">' + e.message + '</span>';
    }
}

// ── 주문 내역 ──────────────────────────────────────────────────
async function loadHistory() {
    const tbody = document.getElementById('history-tbody');
    tbody.innerHTML = '<tr><td colspan="7" class="empty-cell"><span class="spinner"></span> 로딩 중...</td></tr>';
    try {
        const d = await api('/orders/history?limit=50');
        tbody.innerHTML = '';
        if (!d.orders?.length) {
            tbody.innerHTML = '<tr><td colspan="7" class="empty-cell">주문 내역이 없습니다.</td></tr>';
            return;
        }
        d.orders.forEach(o => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
        <td style="font-family:'JetBrains Mono';font-size:.72rem;color:var(--muted)">${o.id.substring(0, 8)}…</td>
        <td>${o.email}</td>
        <td>${o.product}</td>
        <td>${o.quantity}</td>
        <td style="font-family:'JetBrains Mono'">${fmt(o.total_price)}</td>
        <td><span class="badge badge-green">${o.status}</span></td>
        <td style="color:var(--muted);font-size:.78rem">${(o.created_at || '').substring(0, 16)}</td>`;
            tbody.appendChild(tr);
        });
    } catch (e) {
        tbody.innerHTML = '<tr><td colspan="7" class="empty-cell" style="color:var(--red)">API 연결 실패: ' + e.message + '</td></tr>';
    }
}

// ── 초기화 ─────────────────────────────────────────────────────
loadDashboard();
setInterval(loadDashboard, 30000); // 30초 자동 갱신
