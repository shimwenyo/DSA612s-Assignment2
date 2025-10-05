public type User record {
    string email;
    string name;
};

public type TicketRequest record {
    string email;
    int tripId;
    string ticketType; // SINGLE | MULTI | PASS
};

// Minimal payment request used on Kafka
public type PaymentRequest record {
    int ticketId;
};

public type PaymentResult record {
    int ticketId;
    boolean success;
};

public type ScheduleUpdate record {
    string routeCode;
    string message;
};

public type PaymentResultMsg record {
    int ticketId;
    boolean success;
};

public type ScheduleNotice record {
    string routeCode;
    string message;
};


