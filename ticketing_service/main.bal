import ballerina/http;
import ballerina/sql;
import ballerina/os;
import ballerinax/postgresql as pg;
import ballerinax/kafka as kafka;

// Local types
type TicketRequest record { 
    string email; 
    int tripId; 
    string ticketType; // SINGLE | MULTI | PASS
};
type PaymentRequest record { int ticketId; };
type PaymentResultMsg record { int ticketId; boolean success; };

final string DB_USER = os:getEnv("DB_USER") ?: "postgres";
final string DB_PASS = os:getEnv("DB_PASS") ?: "postgres";
final string KAFKA_HOST = os:getEnv("KAFKA_HOST") ?: "kafka:9092";

pg:Client db = check new ({
    host: "ticketdb", port: 5432, database: "tickets",
    user: DB_USER, password: DB_PASS
});

listener http:Listener httpL = new (8082);
final kafka:Producer producer = checkpanic new ({
    bootstrapServers: [KAFKA_HOST]
});

// HTTP API
service / on httpL {

    // Create ticket (CREATED) and emit payment request {ticketId}
    resource function post tickets(@http:Payload TicketRequest req) returns json|error {
        int userId = check from record {int id;} r in db->queryRow(
            `SELECT id FROM users WHERE email=${req.email}`) select r.id;

        int ticketId = check from record {int id;} r in db->queryRow(
            `INSERT INTO tickets(user_id,trip_id,type)
             VALUES (${userId},${req.tripId},${req.ticketType})
             RETURNING id`) select r.id;

        PaymentRequest payReq = { ticketId: ticketId };
        check producer->send({
            topic: "ticket.requests",
            value: payReq.toJsonString().toBytes()
        });

        return { id: ticketId, status: "CREATED" };
    }

    // Validate only if already PAID
    resource function post validate(int id) returns json|error {
        _ = check db->execute(
            `UPDATE tickets SET status='VALIDATED' WHERE id=${id} AND status='PAID'`);
        return { message: "validated or ignored" };
    }
}

// Kafka listener for payments.processed
listener kafka:Listener payResultL = new ({
    bootstrapServers: [KAFKA_HOST],
    groupId: "ticketing-consumer",
    topics: ["payments.processed"]
});

service on payResultL {
    remote function onMessage(kafka:ConsumerRecord[] records) returns error? {
        foreach var r in records {
            string s = check string:fromBytes(<byte[]>r.value);
            json j = check json:fromString(s);
            PaymentResultMsg pr = check j.cloneWithType(PaymentResultMsg);

            if pr.success {
                _ = check db->execute(
                    `UPDATE tickets SET status='PAID' WHERE id=${pr.ticketId}`);
            }
        }
    }
}