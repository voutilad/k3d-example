#!/usr/bin/env python3
from kafka import KafkaProducer

futures = []

def callback(value):
    print(f"Got result: {value}")

def produce_messages(producer, topic):
    for i in range(10):
        message = f"Message {i}".encode()
        f = producer.send(topic, value=message)
        f.add_callback(callback)
        futures.append(f)
    producer.flush(2)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        topic = sys.argv[1]
    else:
        topic = "twitch_chat"

    print(f"Using topic: {topic}")
    producer = KafkaProducer(
        bootstrap_servers="redpanda.redpanda.svc.cluster.local.:9093",
        security_protocol="SSL",
        linger_ms=50,
    )
    produce_messages(producer, topic)
    producer.close(3)
