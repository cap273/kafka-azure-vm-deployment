from kafka import KafkaConsumer
import json

# Kafka broker addresses
bootstrap_servers = [
    'kafka-vm0-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092',
    'kafka-vm1-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092',
    'kafka-vm2-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092'
]

# Initialize the Kafka consumer
consumer = KafkaConsumer(
    'azure-storage-account-topic-1',
    bootstrap_servers=bootstrap_servers,
    auto_offset_reset='earliest',
    enable_auto_commit=True,
    group_id='my-group',
    value_deserializer=lambda x: json.loads(x.decode('utf-8'))
)

# Read and print messages
for message in consumer:
    print(f"Received: {message.value}")

# Note: The consumer will run indefinitely. Use Ctrl+C to stop it.
