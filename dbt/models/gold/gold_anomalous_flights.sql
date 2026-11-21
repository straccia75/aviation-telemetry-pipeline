-- Aircraft-days with readings above 380 m/s ground speed or 16,000 m altitude.
-- Both limits sit above what normal civil traffic reaches: airliners with a
-- strong jet-stream tailwind (~370 m/s) and business jets (~15,500 m).
-- One reading above a limit in a day is treated as an isolated spike (likely
-- sensor noise). Two or more readings in the same day count as sustained.

WITH daily_counts AS (
    SELECT
        flight_id,
        ingestion_date,
        COUNT(*)                         AS total_pings,
        COUNTIF(velocity > 380)          AS high_speed_pings,
        COUNTIF(baro_altitude > 16000)   AS high_altitude_pings,
        MAX(velocity)                    AS max_velocity,
        MAX(baro_altitude)               AS max_altitude
    FROM {{ ref('silver_telemetria') }}
    GROUP BY flight_id, ingestion_date
)

SELECT
    flight_id,
    ingestion_date,
    total_pings,
    high_speed_pings,
    high_altitude_pings,
    max_velocity,
    max_altitude,
    CASE
        WHEN high_speed_pings >= 2 AND high_altitude_pings >= 2 THEN 'Sustained high speed and altitude'
        WHEN high_speed_pings >= 2 THEN 'Sustained high speed'
        WHEN high_altitude_pings >= 2 THEN 'Sustained high altitude'
        ELSE 'Isolated spike'
    END AS anomaly_reason
FROM daily_counts
WHERE high_speed_pings >= 1 OR high_altitude_pings >= 1
