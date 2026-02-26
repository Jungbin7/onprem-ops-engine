#!/bin/bash
sudo -u postgres psql ecommerce << 'EOSQL'
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ecommerce;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ecommerce;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ecommerce;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ecommerce;
EOSQL
echo "=== 권한 확인 ==="
PGPASSWORD=ecommerce2026 psql -U ecommerce -h localhost -d ecommerce -c "SELECT id, name, price, stock FROM products LIMIT 3;"
