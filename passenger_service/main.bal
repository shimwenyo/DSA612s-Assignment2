import ballerina/http;
import ballerina/sql;
import ballerina/os;
import ballerinax/postgresql as pg;

final string DB_USER = os:getEnv("DB_USER") ?: "postgres";
final string DB_PASS = os:getEnv("DB_PASS") ?: "postgres";

pg:Client db = check new ({
    host: "ticketdb", port: 5432, database: "tickets",
    user: DB_USER, password: DB_PASS
});

type RegisterReq record {string email; string password; string name;};

service / on new http:Listener(8081) {

    resource function post register(@http:Payload RegisterReq body)
            returns http:Ok|http:Conflict|error {
        sql:ParameterizedQuery q = `INSERT INTO users(email,password,name)
                                    VALUES (${body.email},${body.password},${body.name})`;
        var res = db->execute(q);
        if res is error {
            return <http:Conflict> {body: {message: "email exists or invalid"}};
        }
        return {body: {message: "registered"}};
    }

    resource function get tickets(string email) returns json|error {
        stream<record{}, error> s = db->query(`
            SELECT t.id, t.type, t.status, tr.id AS "tripId", tr.departure, r.code AS route
            FROM tickets t
            JOIN users u ON t.user_id=u.id
            JOIN trips tr ON tr.id=t.trip_id
            JOIN routes r ON r.id=tr.route_id
            WHERE u.email=${email}
            ORDER BY t.id DESC`);
        return s.toJson();
    }
}
