{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by={
      "field": "ingestion_date",
      "data_type": "date"
    },
    on_schema_change='append_new_columns'
) }}

WITH raw_data AS (
    SELECT * FROM {{ source('opensky', 'bronze_telemetria') }}
    -- Rows without an aircraft identifier are discarded
    WHERE JSON_VALUE(json_payload, '$[0]') IS NOT NULL

    {% if is_incremental() %}
      -- Reprocess only the latest partition and the day before it
      AND ingestion_date >= DATE_SUB(_dbt_max_partition, INTERVAL 1 DAY)
    {% endif %}
)

SELECT
    ingestion_date,
    ingested_at,
    JSON_VALUE(json_payload, '$[0]') AS flight_id, -- icao24 in the OpenSky API
    TRIM(JSON_VALUE(json_payload, '$[1]')) AS call_sign,
    JSON_VALUE(json_payload, '$[2]') AS origin_country,
    SAFE_CAST(JSON_VALUE(json_payload, '$[5]') AS FLOAT64) AS longitude,
    SAFE_CAST(JSON_VALUE(json_payload, '$[6]') AS FLOAT64) AS latitude,
    SAFE_CAST(JSON_VALUE(json_payload, '$[7]') AS FLOAT64) AS baro_altitude,
    SAFE_CAST(JSON_VALUE(json_payload, '$[8]') AS BOOL) AS on_ground,
    SAFE_CAST(JSON_VALUE(json_payload, '$[9]') AS FLOAT64) AS velocity,
    SAFE_CAST(JSON_VALUE(json_payload, '$[10]') AS FLOAT64) AS true_track
FROM raw_data
