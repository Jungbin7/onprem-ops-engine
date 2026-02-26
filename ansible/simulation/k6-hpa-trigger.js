import http from 'k6/http';
import { sleep, check } from 'k6';

export const options = {
    stages: [
        { duration: '30s', target: 30 },   // 워밍업
        { duration: '2m', target: 60 },   // HPA 트리거 목표 (brain IP 경유)
        { duration: '30s', target: 0 },    // 쿨다운
    ],
    thresholds: {
        http_req_failed: ['rate<0.20'],    // 오류율 20% 미만 (완화)
        http_req_duration: ['p(95)<5000'],   // 95%가 5초 이내 (완화)
    },
};

// brain NodePort (kube-proxy가 body/body2로 분산)
const BASE = 'http://192.168.174.10:30080';

export default function () {
    const r1 = http.get(`${BASE}/products`, { timeout: '10s' });
    check(r1, { 'products 200': (r) => r.status === 200 });
    sleep(0.3);

    const payload = JSON.stringify({
        product_id: Math.ceil(Math.random() * 5),
        quantity: 1,
        customer_email: `loadtest${__VU}@k6.io`,
    });
    const r2 = http.post(`${BASE}/orders`, payload, {
        headers: { 'Content-Type': 'application/json' },
        timeout: '10s',
    });
    check(r2, { 'order 200/201': (r) => r.status === 200 || r.status === 201 });
    sleep(0.3);
}
