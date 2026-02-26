#!/bin/bash
echo "=== 1. HEALTH CHECK ==="
curl -s http://192.168.174.20:30080/health

echo ""
echo "=== 2. PRODUCTS (PostgreSQL) ==="
curl -s http://192.168.174.20:30080/products

echo ""
echo "=== 3. CREATE ORDER ==="
curl -s -X POST http://192.168.174.20:30080/orders \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "quantity": 2, "customer_email": "test@ops.com"}'

echo ""
echo "=== 4. ORDER HISTORY ==="
curl -s http://192.168.174.20:30080/orders/history

echo ""
echo "=== 5. METRICS SUMMARY (Redis + PG) ==="
curl -s http://192.168.174.20:30080/metrics/summary

echo ""
echo "=== 6. DASHBOARD POD STATUS ==="
ssh -i ~/.vagrant-keys/brain_key -o StrictHostKeyChecking=no vagrant@192.168.174.10 \
  "sudo k3s kubectl get pods -o wide"
