-- Aircraft above 300 m/s or 13,000 m.
-- Readings up to 330 m/s and 13,300 m are treated as possible sensor noise.
WITH flight_max AS (
    SELECT
        flight_id,
        MAX(velocity)      AS max_velocity,
        MAX(baro_altitude) AS max_altitude
    FROM {{ ref('silver_telemetria') }}
    GROUP BY flight_id
)

SELECT
    flight_id,
    max_velocity,
    max_altitude,
    CASE
        WHEN max_velocity > 330 AND max_altitude > 13300 THEN 'Above commercial speed and altitude'
        WHEN max_velocity > 330 THEN 'Above commercial speed'
        WHEN max_altitude > 13300 THEN 'Above commercial altitude'
        ELSE 'Possible sensor noise'
    END AS anomaly_reason
FROM flight_max
WHERE max_velocity > 300 OR max_altitude > 13000
