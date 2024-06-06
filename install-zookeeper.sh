#!/bin/bash

# Update and install dependencies
sudo apt-get update
sudo apt-get install -y openjdk-11-jdk wget

# Set JAVA_HOME environment variable
if [ -d "$HOME" ]; then
  echo "export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))" >> ~/.bashrc
  echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> ~/.bashrc
  source ~/.bashrc
else
  echo "Home directory not found. Skipping .bashrc modifications."
fi

# Download and extract ZooKeeper
ZOOKEEPER_VERSION="3.8.4"
ZOOKEEPER_URL="https://dlcdn.apache.org/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz"

wget ${ZOOKEEPER_URL}
if [ $? -ne 0 ]; then
    echo "Failed to download ZooKeeper. Exiting."
    exit 1
fi

tar -xzf apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz
sudo mv apache-zookeeper-${ZOOKEEPER_VERSION}-bin /usr/local/zookeeper

# Create ZooKeeper configuration file
sudo mkdir -p /var/lib/zookeeper
sudo bash -c 'cat << EOF > /usr/local/zookeeper/conf/zoo.cfg
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
initLimit=5
syncLimit=2
EOF'

# Create ZooKeeper systemd service
sudo bash -c 'cat << EOF > /etc/systemd/system/zookeeper.service
[Unit]
Description=Apache ZooKeeper
Documentation=http://zookeeper.apache.org
Requires=network.target
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/zookeeper/bin/zkServer.sh start-foreground
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF'

# Enable and start ZooKeeper service
sudo systemctl daemon-reload
sudo systemctl enable zookeeper
sudo systemctl start zookeeper
