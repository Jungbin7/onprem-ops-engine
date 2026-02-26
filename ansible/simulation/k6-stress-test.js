import http from 'k6/http';
import { sleep, check } from 'k6';

export const options = {
    stages: [
        { duration: '30s', target: 20 },  // 워밍업
        { duration: '2m', target: 100 },  // Black Friday 시뮬레이션 (HPA 트리거 목표)
        { duration: '30s', target: 0 },  // 쿨다운
    ],
    thresholds: {
        http_req_failed: ['rate<0.05'],   // 오류율 5% 미만
        http_req_duration: ['p(95)<2000'],  // 95%가 2초 이내
    },
};

const BASE = 'http://192.168.174.20:30080';

export default function () {
    // 상품 목록 조회 (GET)
    const r1 = http.get(`${BASE}/products`);
    check(r1, { 'products 200': (r) => r.status === 200 });
    sleep(0.5);

    // 주문 생성 (POST) — CPU 부하 주요 원인
    const payload = JSON.stringify({
        product_id: Math.ceil(Math.random() * 5),
        quantity: 1,
        customer_email: `loadtest${__VU}@k6.io`,
    });
    const r2 = http.post(`${BASE}/orders`, payload, {
        headers: { 'Content-Type': 'application/json' },
    });
    check(r2, { 'order 200/201': (r) => r.status === 200 || r.status === 201 });
    sleep(0.5);
}
