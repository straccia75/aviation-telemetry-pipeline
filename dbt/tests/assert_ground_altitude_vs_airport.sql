{{ config(severity = 'warn') }}

-- Aircraft reported on the ground whose barometric altitude differs from the
-- elevation of the nearest airport (within 5 km) by more than 300 m.
-- 300 m covers normal pressure variation: baro_altitude is pressure altitude,
-- not true height, and shifts about 8 m per hPa away from 1013 hPa.

WITH aircraft_on_ground AS (
    SELECT
        flight_id,
        ingested_at,
        baro_altitude,
        ST_GEOGPOINT(longitude, latitude) AS position  -- longitude first
    FROM {{ ref('silver_telemetria') }}
    WHERE on_ground = true
      AND baro_altitude IS NOT NULL
      AND latitude IS NOT NULL
      AND longitude IS NOT NULL
),

airports AS (
    SELECT
        ident,
        name,
        elevation_ft * 0.3048 AS elevation_m,
        ST_GEOGPOINT(longitude_deg, latitude_deg) AS position
    FROM {{ ref('ref_airports') }}
),

nearest_airport AS (
    SELECT
        g.flight_id,
        g.ingested_at,
        g.baro_altitude,
        a.ident,
        a.name AS airport_name,
        a.elevation_m,
        ST_DISTANCE(g.position, a.position) AS distance_m
    FROM aircraft_on_ground AS g
    JOIN airports AS a
      ON ST_DWITHIN(g.position, a.position, 5000)
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY g.flight_id, g.ingested_at
        ORDER BY ST_DISTANCE(g.position, a.position)
    ) = 1
)

SELECT
    flight_id,
    ingested_at,
    ident,
    airport_name,
    ROUND(baro_altitude) AS baro_altitude_m,
    ROUND(elevation_m) AS airport_elevation_m,
    ROUND(ABS(baro_altitude - elevation_m)) AS difference_m,
    ROUND(distance_m) AS distance_m
FROM nearest_airport
WHERE elevation_m IS NOT NULL  -- no known elevation: skip the check
  AND ABS(baro_altitude - elevation_m) > 300
