from neo4j import GraphDatabase
import requests
import json

class FaultAnalyzer:
    def __init__(self, uri, user, password, ollama_url):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
        self.ollama_url = ollama_url

    def find_failed_transactions(self):
        with self.driver.session() as session:
            result = session.run("""
                MATCH (o:Order)-[:HAS_PAYMENT]->(p:Payment)
                WHERE p.status = 'FAILED'
                RETURN o.id as order_id, p.id as payment_id
            """)
            return [record.data() for record in result]

    def analyze_with_ai(self, failures):
        context = f"Detected payment failures: {json.dumps(failures)}"
        prompt = f"""
        당신은 온프레미스 e커머스 운영 전문가입니다. 
        다음은 Neo4j 그래프 데이터베이스에서 탐색된 장애 데이터입니다:
        {context}
        
        이 데이터를 기반으로 운영팀을 위한 짧은 분석 리포트를 작성하세요. 
        장애의 심각성과 예상되는 비즈니스 임팩트를 포함해야 합니다.
        """
        
        response = requests.post(
            f"{self.ollama_url}/api/generate",
            json={"model": "llama2", "prompt": prompt, "stream": False}
        )
        return response.json().get("response")

if __name__ == "__main__":
    analyzer = FaultAnalyzer("bolt://192.168.174.10:7687", "neo4j", "neo4j", "http://192.168.174.10:11434")
    failures = analyzer.find_failed_transactions()
    if failures:
        report = analyzer.analyze_with_ai(failures)
        print("=== AI Analysis Report ===")
        print(report)
    else:
        print("No failures detected in the graph.")
