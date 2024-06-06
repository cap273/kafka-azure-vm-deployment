package com.example;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.time.Duration;
import java.util.Arrays;
import java.util.Properties;

public class KafkaConsumerExample {
    public static void main(String[] args) {
        // Kafka broker addresses
        String bootstrapServers = "kafka-vm0-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092," +
                "kafka-vm1-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092," +
                "kafka-vm2-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092";

        // Set up consumer properties
        Properties properties = new Properties();
        properties.setProperty(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        properties.setProperty(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        properties.setProperty(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        properties.setProperty(ConsumerConfig.GROUP_ID_CONFIG, "my-group");
        properties.setProperty(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");

        // Create the consumer using try-with-resources to ensure it is closed properly
        try (KafkaConsumer<String, String> consumer = new KafkaConsumer<>(properties)) {
            // Subscribe to the topic
            consumer.subscribe(Arrays.asList("test-topic-1"));

            // Poll for new data
            while (true) {
                ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
                for (ConsumerRecord<String, String> record : records) {
                    System.out.println("Received message with key " + record.key() + " and value " + record.value() + " from partition " + record.partition() + " with offset " + record.offset());
                }
            }
        }
    }
}
