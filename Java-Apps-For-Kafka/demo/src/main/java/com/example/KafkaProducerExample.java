package com.example;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;

public class KafkaProducerExample {
    public static void main(String[] args) {
        // Kafka broker addresses
        String bootstrapServers = "kafka-vm0-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092," +
                "kafka-vm1-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092," +
                "kafka-vm2-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092";

        // Set up producer properties
        Properties properties = new Properties();
        properties.setProperty(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        properties.setProperty(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        properties.setProperty(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());

        // Create the producer
        KafkaProducer<String, String> producer = new KafkaProducer<>(properties);

        // Produce 10 messages
        for (int i = 0; i < 10; i++) {
            ProducerRecord<String, String> record = new ProducerRecord<>("test-topic-1", "key_" + i, "Dummy data " + i);
            producer.send(record, (metadata, exception) -> {
                if (exception == null) {
                    System.out.println("Sent message with key " + record.key() + " to partition " + metadata.partition() + " with offset " + metadata.offset());
                } else {
                    exception.printStackTrace();
                }
            });
        }

        // Close the producer
        producer.close();
    }
}
