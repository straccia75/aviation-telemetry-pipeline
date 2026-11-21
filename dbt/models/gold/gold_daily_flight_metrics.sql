-- One row per aircraft per day.
SELECT
    flight_id,
    ingestion_date,
    COUNT(*)           AS ping_count,
    MAX(velocity)      AS max_velocity,
    MAX(baro_altitude) AS max_altitude
FROM {{ ref('silver_telemetria') }}
GROUP BY flight_id, ingestion_date
