#!/bin/bash

# Ensure that the script is executed with the necessary parameters
if [ "$#" -ne 11 ]; then
    echo "Usage: $0 <Zookeeper_Host> <Broker_ID> <Advertised_Listeners_Base> <Kafka_Version> <Kafka_Bootstrap_Servers> <Config_Storage_Account_Url> <Output_Storage_Account_Name> <Output_Storage_Account_Key> <Output_Container_Name> <Topics> <User>"
    exit 1
fi

# Set parameters
ZK_HOST=$1
ZK_PORT=2181
BROKER_ID=$2
ADVERTISED_LISTENERS_BASE=$3
KAFKA_VERSION=$4
BOOTSTRAP_SERVERS=$5
CONFIG_STORAGE_ACCOUNT_URL=$6
OUTPUT_STORAGE_ACCOUNT_NAME=$7
OUTPUT_STORAGE_ACCOUNT_KEY=$8
OUTPUT_CONTAINER_NAME=$9
TOPICS=${10}
USER=${11}
KAFKA_PORT=9092

# Update and install dependencies 
sudo apt-get update
sudo apt-get install -y openjdk-11-jdk wget zip jq curl

# Set JAVA_HOME environment variable
JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
export JAVA_HOME PATH=$JAVA_HOME/bin:$PATH

# Determine Kafka download URL based on the version
if [[ "$KAFKA_VERSION" == 3.[7-9].* || "$KAFKA_VERSION" == [4-9]* ]]; then
    KAFKA_URL="https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_2.13-${KAFKA_VERSION}.tgz"
else
    KAFKA_URL="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_2.13-${KAFKA_VERSION}.tgz"
fi

# Download and extract Kafka
wget ${KAFKA_URL} -O /tmp/kafka.tgz
sudo tar -xzf /tmp/kafka.tgz -C /usr/local/ 
sudo mv /usr/local/kafka_2.13-${KAFKA_VERSION} /usr/local/kafka

# Clean up existing ZooKeeper nodes if they exist
echo "Cleaning up ZooKeeper nodes..."
/usr/local/kafka/bin/zookeeper-shell.sh $ZK_HOST:$ZK_PORT delete /brokers/ids/$BROKER_ID

# Create Kafka configuration
ADVERTISED_LISTENERS="PLAINTEXT://${ADVERTISED_LISTENERS_BASE}:${KAFKA_PORT}"

sudo tee /usr/local/kafka/config/server.properties > /dev/null << EOF
broker.id=${BROKER_ID}
listeners=PLAINTEXT://0.0.0.0:${KAFKA_PORT}
advertised.listeners=${ADVERTISED_LISTENERS}
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.dirs=/var/lib/kafka/logs
num.partitions=1
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=${ZK_HOST}:${ZK_PORT}
zookeeper.connection.timeout.ms=18000
EOF

# Create Kafka systemd service
sudo tee /etc/systemd/system/kafka.service > /dev/null << EOF
[Unit]
Description=Apache Kafka
Documentation=http://kafka.apache.org/documentation.html
Requires=network.target
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/kafka/bin/kafka-server-start.sh /usr/local/kafka/config/server.properties
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Kafka service
sudo systemctl daemon-reload
sudo systemctl enable kafka
sudo systemctl start kafka

# Create azure-blob-sink-config.json with actual values
cat <<EOF | sudo tee /usr/local/kafka/config/azure-blob-sink-config.json > /dev/null
{
  "name": "azure-blob-sink-connector",
  "config": {
    "connector.class": "io.confluent.connect.azure.blob.AzureBlobStorageSinkConnector",
    "tasks.max": "1",
    "topics": "${TOPICS}",
    "flush.size": "3",
    "azblob.account.name": "${OUTPUT_STORAGE_ACCOUNT_NAME}",
    "azblob.account.key": "${OUTPUT_STORAGE_ACCOUNT_KEY}",
    "azblob.container.name": "${OUTPUT_CONTAINER_NAME}",
    "format.class": "io.confluent.connect.azure.blob.format.json.JsonFormat",
    "partitioner.class": "io.confluent.connect.storage.partitioner.DefaultPartitioner",
    "path.format": "'year'=YYYY/'month'=MM/'day'=dd/'hour'=HH",
    "locale": "en",
    "timezone": "UTC",
    "rotate.interval.ms": "600000",
    "schema.compatibility": "NONE",
    "confluent.topic.bootstrap.servers": "${BOOTSTRAP_SERVERS}",
    "confluent.topic.replication.factor": "1"
  }
}
EOF

# Download and install the Azure Blob Storage Sink Connector
CONNECTOR_URL="https://carlostransitfiles.blob.core.windows.net/sharefiles/confluentinc-kafka-connect-azure-blob-storage-1.6.22.zip"
wget -O /tmp/azure-blob-sink-connector.zip ${CONNECTOR_URL}
if [ $? -ne 0 ]; then
    echo "Failed to download and extract Azure Blob Storage Sink Connector. Exiting."
    exit 1
fi

sudo mkdir -p /usr/local/kafka/plugins && sudo unzip /tmp/azure-blob-sink-connector.zip -d /usr/local/kafka/plugins

# Set the plugin path in the Kafka Connect configuration
sudo tee /usr/local/kafka/config/connect-distributed.properties > /dev/null << EOF
bootstrap.servers=${BOOTSTRAP_SERVERS}
group.id=connect-cluster
key.converter=org.apache.kafka.connect.storage.StringConverter
value.converter=org.apache.kafka.connect.storage.StringConverter
config.storage.topic=connect-configs
offset.storage.topic=connect-offsets
status.storage.topic=connect-statuses
config.storage.replication.factor=1
offset.storage.replication.factor=1
status.storage.replication.factor=1
rest.port=8083
plugin.path=/usr/local/kafka/plugins
EOF

# Create a systemd service for Kafka Connect
sudo tee /etc/systemd/system/kafka-connect.service > /dev/null << EOF
[Unit]
Description=Apache Kafka Connect
After=network.target

[Service]
User=${USER}
ExecStart=/usr/local/kafka/bin/connect-distributed.sh /usr/local/kafka/config/connect-distributed.properties
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Create log4j.properties file for detailed logging
sudo tee /usr/local/kafka/config/log4j.properties > /dev/null << EOF
# Root logger option
log4j.rootLogger=DEBUG, stdout, kafkaAppender

# Direct log messages to stdout
log4j.appender.stdout=org.apache.log4j.ConsoleAppender
log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
log4j.appender.stdout.layout.ConversionPattern=%d [%t] %-5p %c - %m%n

# Kafka log appender
log4j.appender.kafkaAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.kafkaAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.kafkaAppender.File=/var/log/kafka/connect.log
log4j.appender.kafkaAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.kafkaAppender.layout.ConversionPattern=%d [%t] %-5p %c - %m%n

# Set the logger level for the Azure Blob Storage Sink Connector
log4j.logger.io.confluent.connect.azure.blob.AzureBlobStorageSinkConnector=DEBUG
log4j.logger.io.confluent.connect.azure.blob.AzureBlobStorageSinkTask=DEBUG
EOF

# Reload systemd and start Kafka Connect service
sudo systemctl daemon-reload
sudo systemctl enable kafka-connect
sudo systemctl start kafka-connect

# Wait a few seconds for the Kafka Connect service to start
sleep 15

# Create the Azure Blob Storage Sink Connector
curl -X POST -H "Content-Type: application/json" --data @/usr/local/kafka/config/azure-blob-sink-config.json http://localhost:8083/connectors
if [ $? -ne 0 ]; then
    echo "Failed to create Azure Blob Storage Sink Connector. Exiting."
    exit 1
fi

# Clean up temporary files
sudo rm -f /tmp/kafka.tgz /tmp/azure-blob-sink-connector.zip

echo "Setup completed successfully."
