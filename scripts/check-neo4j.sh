#!/bin/bash
BRAIN_KEY=~/.vagrant-keys/brain_key

echo "=== Neo4j 전체 노드 속성 확인 ==="
ssh -i $BRAIN_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.10 \
  'curl -s -u neo4j:neo4j1234 \
   -H "Content-Type: application/json" \
   -X POST http://localhost:7474/db/neo4j/tx/commit \
   -d "{\"statements\":[{\"statement\":\"MATCH (n) RETURN n LIMIT 10\"}]}" \
   | python3 -c "
import sys, json
d = json.load(sys.stdin)
for item in d.get(\"results\",[{}])[0].get(\"data\",[]):
    print(item[\"row\"])
"'

echo ""
echo "=== Neo4j 관계 확인 ==="
ssh -i $BRAIN_KEY -o StrictHostKeyChecking=no vagrant@192.168.174.10 \
  'curl -s -u neo4j:neo4j1234 \
   -H "Content-Type: application/json" \
   -X POST http://localhost:7474/db/neo4j/tx/commit \
   -d "{\"statements\":[{\"statement\":\"MATCH (a)-[r]->(b) RETURN type(r), labels(a)[0], labels(b)[0] LIMIT 10\"}]}" \
   | python3 -c "
import sys, json
d = json.load(sys.stdin)
for item in d.get(\"results\",[{}])[0].get(\"data\",[]):
    print(item[\"row\"])
"'
