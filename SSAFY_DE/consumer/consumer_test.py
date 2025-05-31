from kafka import KafkaConsumer
import json

# Kafka consumer properties
kafka_props = {
    'bootstrap_servers': 'localhost:9092',
    'group_id': 'consumer_group',
    'auto_offset_reset': 'earliest',  # 처음부터 읽기
    'enable_auto_commit': True,
    'value_deserializer': lambda x: json.loads(x.decode('utf-8'))
}

# Kafka Consumer 생성
consumer = KafkaConsumer("news", **kafka_props)

# 메시지 수신
for msg in consumer:
    print(f"[Consumed] {msg.value}")
