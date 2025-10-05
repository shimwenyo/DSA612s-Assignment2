import ballerina/os;
import ballerinax/kafka as kafka;

// Local type
type PaymentRequest record { int ticketId; };

final string KAFKA_HOST = os:getEnv("KAFKA_HOST") ?: "kafka:9092";

// Producer
final kafka:Producer producer = checkpanic new ({
    bootstrapServers: [KAFKA_HOST]
});

// Kafka listener for ticket.requests
listener kafka:Listener paymentListener = new ({
    bootstrapServers: [KAFKA_HOST],
    groupId: "payment-consumer",
    topics: ["ticket.requests"]
});

service on paymentListener {

    remote function onMessage(kafka:ConsumerRecord[] records) returns error? {
        foreach var r in records {
            string payload = check string:fromBytes(<byte[]>r.value);
            json j = check json:fromString(payload);

            PaymentRequest pr = check j.cloneWithType(PaymentRequest);

            json res = { "ticketId": pr.ticketId, "success": true };
            check producer->send({
                topic: "payments.processed",
                value: res.toJsonString().toBytes()
            });
        }
    }
}
