package com.example;

import org.apache.kafka.clients.admin.*;
import org.apache.kafka.common.KafkaFuture;

import java.util.Arrays;
import java.util.Collection;
import java.util.Properties;
import java.util.concurrent.ExecutionException;

public class KafkaAdminExample {

    public static void main(String[] args) throws ExecutionException, InterruptedException {
        // Kafka broker addresses
        String bootstrapServers = "kafka-vm0-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092," +
                "kafka-vm1-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092," +
                "kafka-vm2-jv7iuxewgz5zw.eastus2.cloudapp.azure.com:9092";

        // Set up admin client properties
        Properties properties = new Properties();
        properties.setProperty(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);

        // Create an admin client
        try (AdminClient adminClient = AdminClient.create(properties)) {

            // List topics
            listTopics(adminClient);

            // Create a topic
            String topicName1 = "azure-storage-account-topic-1";
            String topicName2 = "test-topic-1";
            //createTopic(adminClient, topicName1);
            //createTopic(adminClient, topicName2);


            // Describe the topic
            //describeTopic(adminClient, topicName1);
            //describeTopic(adminClient, topicName2);

            listTopics(adminClient);

            // Delete the topic
            // deleteTopic(adminClient, topicName);
        }
    }

    public static void listTopics(AdminClient adminClient) throws ExecutionException, InterruptedException {
        System.out.println("Listing topics...");
        ListTopicsResult topics = adminClient.listTopics();
        Collection<TopicListing> listings = topics.listings().get();
        for (TopicListing listing : listings) {
            System.out.println("Topic name: " + listing.name());
        }
    }

    public static void createTopic(AdminClient adminClient, String topicName) throws ExecutionException, InterruptedException {
        System.out.println("Creating topic: " + topicName);
        NewTopic newTopic = new NewTopic(topicName, 1, (short) 1);
        CreateTopicsResult createTopicsResult = adminClient.createTopics(Arrays.asList(newTopic));
        createTopicsResult.all().get();
        System.out.println("Topic created: " + topicName);
    }

    public static void describeTopic(AdminClient adminClient, String topicName) throws ExecutionException, InterruptedException {
        System.out.println("Describing topic: " + topicName);
        DescribeTopicsResult describeTopicsResult = adminClient.describeTopics(Arrays.asList(topicName));
        KafkaFuture<TopicDescription> future = describeTopicsResult.values().get(topicName);
        TopicDescription description = future.get();
        System.out.println("Topic description: " + description);
    }

    public static void deleteTopic(AdminClient adminClient, String topicName) throws ExecutionException, InterruptedException {
        System.out.println("Deleting topic: " + topicName);
        DeleteTopicsResult deleteTopicsResult = adminClient.deleteTopics(Arrays.asList(topicName));
        deleteTopicsResult.all().get();
        System.out.println("Topic deleted: " + topicName);
    }
}
