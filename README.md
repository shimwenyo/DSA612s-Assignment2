# Smart Public Transport Ticketing 

Services:
- Passenger (8081): register, list my tickets
- Ticketing (8082): create ticket, validate; Kafka producer+consumer
- Payment (no HTTP): consumes `ticket.requests`, emits `payments.processed`
- Transport (8083): routes, trips, schedule updates → Kafka
- Notification (8084): GET /feed to see Kafka messages captured

## Start
docker compose up -d --build  
docker cp ./sql/schema.sql ticketdb:/schema.sql  
docker exec -it ticketdb psql -U postgres -d tickets -f /schema.sql

## Test
1) POST /register (8081)
2) POST /routes, /trips (8083)
3) POST /tickets (8082) → becomes PAID via Kafka
4) POST /validate?id=... (8082)
5) GET  /feed (8084)
