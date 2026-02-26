from neo4j import GraphDatabase
import random

class ECommerceGraph:
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))

    def close(self):
        self.driver.close()

    def populate(self):
        with self.driver.session() as session:
            # Create sample data
            session.run("MATCH (n) DETACH DELETE n")
            
            # Create Orders, Payments, Shipping
            for i in range(1, 11):
                order_id = f"ORD-{i:03}"
                pay_id = f"PAY-{i:03}"
                ship_id = f"SHIP-{i:03}"
                
                status = "SUCCESS" if random.random() > 0.1 else "FAILED"
                
                session.run("""
                    CREATE (o:Order {id: $order_id, amount: $amount})
                    CREATE (p:Payment {id: $pay_id, status: $status})
                    CREATE (s:Shipping {id: $ship_id, method: 'Express'})
                    CREATE (o)-[:HAS_PAYMENT]->(p)
                    CREATE (p)-[:TRIGGERS_SHIPPING]->(s)
                """, order_id=order_id, pay_id=pay_id, ship_id=ship_id, 
                     amount=random.randint(100, 1000), status=status)
            
            print("Neo4j populated with 10 transaction chains.")

if __name__ == "__main__":
    # Default credentials for demo
    graph = ECommerceGraph("bolt://192.168.174.10:7687", "neo4j", "neo4j")
    graph.populate()
    graph.close()
