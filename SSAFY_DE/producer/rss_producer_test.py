
from kafka import KafkaProducer
import json
import time


# Kafka 브로커 주소
KAFKA_BROKER = "localhost:9092"
# Kafka 토픽 이름
TOPIC = "news"

# Kafka Producer 생성 (value는 JSON 직렬화)
producer = KafkaProducer(
    bootstrap_servers=KAFKA_BROKER,
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

# 예시 데이터 전송
sample = {"title": "예시 뉴스", "link": "http://example.com"}
producer.send(TOPIC, sample)
print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Sent: {sample['title']}")
