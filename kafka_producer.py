from kafka import KafkaProducer
import json
import time

# Kafka broker addresses
bootstrap_servers = [
    'kafka-vm0-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092',
    'kafka-vm1-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092',
    'kafka-vm2-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092'
]

# Initialize the Kafka producer
producer = KafkaProducer(
    bootstrap_servers=bootstrap_servers,
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

# Topic name
topic_name = 'azure-storage-account-topic-1'

# Function to send dummy data
def send_dummy_data():
    for i in range(10):
        data = {'key': i, 'value': f'Dummy data {i}'}
        producer.send(topic_name, value=data)
        print(f"Sent: {data}")
        time.sleep(1)  # Wait for a second before sending the next message

# Send dummy data
send_dummy_data()

# Close the producer
producer.close()
