import ballerina/http;
import ballerina/sql;
import ballerina/os;
import ballerinax/postgresql as pg;
import ballerinax/kafka as kafka;

final string DB_USER = os:getEnv("DB_USER") ?: "postgres";
final string DB_PASS = os:getEnv("DB_PASS") ?: "postgres";
final string KAFKA_HOST = os:getEnv("KAFKA_HOST") ?: "kafka:9092";

pg:Client db = check new ({
    host: "ticketdb", port: 5432, database: "tickets",
    user: DB_USER, password: DB_PASS
});

final kafka:Producer producer = checkpanic new ({
    bootstrapServers: [KAFKA_HOST]
});

service / on new http:Listener(8083) {
    resource function post routes(@http:Payload record {string code; string name;} r) returns json|error {
        _ = check db->execute(`INSERT INTO routes(code,name) VALUES (${r.code},${r.name})`);
        return {message: "route added"};
    }
    resource function post trips(@http:Payload record {string routeCode; string departure; string vehicle;} t) returns json|error {
        int routeId = check from record {int id;} r in db->queryRow(`SELECT id FROM routes WHERE code=${t.routeCode}`) select r.id;
        _ = check db->execute(`INSERT INTO trips(route_id,departure,vehicle) VALUES (${routeId},${t.departure},${t.vehicle})`);
        return {message: "trip added"};
    }
    resource function post serviceUpdate(@http:Payload record {string routeCode; string message;} su) returns json|error {
        json j = {routeCode: su.routeCode, message: su.message};
        check producer->send({topic: "schedule.updates", value: j.toJsonString().toBytes()});
        return {status: "published"};
    }
}

