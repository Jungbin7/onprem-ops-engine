#!/bin/bash
BRAIN_KEY=~/.vagrant-keys/brain_key

echo "=== Ollama llama2 직접 테스트 ==="
ssh -i $BRAIN_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.10 \
  'curl -s -X POST http://localhost:11434/api/generate \
   -H "Content-Type: application/json" \
   -d "{\"model\":\"llama2\",\"prompt\":\"In 2 sentences, list two causes of API failures.\",\"stream\":false}" \
   | python3 -c "import sys,json; d=json.load(sys.stdin); print(\"RESPONSE:\", d.get(\"response\",\"NONE\")[:300])"'

echo ""
echo "=== Neo4j Cypher 쿼리 (주문 관계 확인) ==="
ssh -i $BRAIN_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.10 \
  'curl -s -u neo4j:neo4j1234 \
   -H "Content-Type: application/json" \
   -X POST http://localhost:7474/db/neo4j/tx/commit \
   -d "{\"statements\":[{\"statement\":\"MATCH (c:Customer)-[:PLACED]->(o:Order) RETURN c.email, o.order_id LIMIT 10\"}]}" \
   | python3 -c "import sys,json; d=json.load(sys.stdin); [print(r) for r in d.get(\"results\",[{}])[0].get(\"data\",[])] or print(\"결과:\",d)"'

echo ""
echo "=== Neo4j 전체 노드 수 ==="
ssh -i $BRAIN_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.10 \
  'curl -s -u neo4j:neo4j1234 \
   -H "Content-Type: application/json" \
   -X POST http://localhost:7474/db/neo4j/tx/commit \
   -d "{\"statements\":[{\"statement\":\"MATCH (n) RETURN labels(n)[0] as label, count(n) as cnt ORDER BY cnt DESC\"}]}" \
   | python3 -c "import sys,json; d=json.load(sys.stdin); [print(r[\"row\"]) for r in d.get(\"results\",[{}])[0].get(\"data\",[])]"'
