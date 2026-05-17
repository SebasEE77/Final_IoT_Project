CREATE TABLE sensor_events (
    id          SERIAL PRIMARY KEY,
    device_id   VARCHAR(100) NOT NULL,
    sensor_type VARCHAR(50)  NOT NULL,
    value       FLOAT        NOT NULL,
    timestamp   TIMESTAMP    NOT NULL,
    created_at  TIMESTAMP    DEFAULT NOW()
);