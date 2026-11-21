-- One row per aircraft with its latest call sign and country (SCD Type 1).
SELECT
    flight_id,
    call_sign,
    origin_country
FROM {{ ref('silver_telemetria') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY flight_id ORDER BY ingested_at DESC) = 1
