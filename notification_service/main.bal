import ballerina/http;
import ballerina/os;
import ballerinax/kafka as kafka;

final string KAFKA_HOST = os:getEnv("KAFKA_HOST") ?: "kafka:9092";

// In-memory capture of topic messages
final map<string[]> inbox = {};

service / on new http:Listener(8084) {
    resource function get feed() returns json { return inbox; }
}

listener kafka:Listener notifL = new ({
    bootstrapServers: [KAFKA_HOST],
    groupId: "notif-consumer",
    topics: ["payments.processed", "schedule.updates"]
});

service on notifL {
    remote function onMessage(kafka:ConsumerRecord[] rs) returns error? {
        foreach var r in rs {
            string topic = r.topic;
            string msg = check string:fromBytes(<byte[]>r.value);
            string[] arr = inbox.hasKey(topic) ? inbox[topic] : [];
            arr.push(msg);
            inbox[topic] = arr;
        }
    }
}

