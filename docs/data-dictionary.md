# Data dictionary

## Source: OpenSky state vector

Each aircraft in the `/states/all` response is a **positional array**. The producer sends each array as one event without changing it.

| Index | Field | Type | Description |
|---|---|---|---|
| 0 | `icao24` | string | Unique ICAO 24-bit transponder address (hex) |
| 1 | `callsign` | string | Call sign, may be empty or padded with spaces |
| 2 | `origin_country` | string | Country inferred from the ICAO address |
| 3 | `time_position` | int | Unix time of the last position update, may be null |
| 4 | `last_contact` | int | Unix time of the last message received |
| 5 | `longitude` | float | WGS-84 longitude, degrees |
| 6 | `latitude` | float | WGS-84 latitude, degrees |
| 7 | `baro_altitude` | float | Barometric altitude, metres |
| 8 | `on_ground` | bool | True if the position comes from a surface report |
| 9 | `velocity` | float | Ground speed, m/s |
| 10 | `true_track` | float | Track angle, degrees clockwise from north |
| 11 | `vertical_rate` | float | Vertical rate, m/s (positive = climbing) |
| 12 | `sensors` | int[] | Receiver IDs, usually null |
| 13 | `geo_altitude` | float | Geometric altitude, metres |
| 14 | `squawk` | string | Transponder code |
| 15 | `spi` | bool | Special purpose indicator |
| 16 | `position_source` | int | 0 ADS-B, 1 ASTERIX, 2 MLAT, 3 FLARM |

---

## Bronze: `bronze/telemetria`

Parquet, partitioned by `ingestion_date`.

| Column | Type | Description |
|---|---|---|
| `json_payload` | string | Raw state vector as received |
| `ingested_at` | timestamp | Kafka broker timestamp |
| `ingestion_date` | date | Partition key, derived from `ingested_at` |

---

## Silver: `silver_telemetria` (BigQuery, dbt)

Parsed and typed telemetry, one row per aircraft event. Incremental model partitioned by `ingestion_date`: each run replaces only the latest day and the day before it (`insert_overwrite`), so re-runs never duplicate rows. Rows without an aircraft identifier are discarded.

| Column | Type | Source | Description |
|---|---|---|---|
| `ingestion_date` | date | Bronze | Partition key |
| `ingested_at` | timestamp | Bronze | Kafka broker timestamp |
| `flight_id` | string | `[0]` icao24 | Aircraft identifier |
| `call_sign` | string | `[1]` | Call sign, trimmed |
| `origin_country` | string | `[2]` | Country of registration |
| `longitude` | float | `[5]` | Degrees |
| `latitude` | float | `[6]` | Degrees |
| `baro_altitude` | float | `[7]` | Barometric altitude, metres |
| `on_ground` | bool | `[8]` | Surface report flag |
| `velocity` | float | `[9]` | Ground speed, m/s |
| `true_track` | float | `[10]` | Track angle, degrees |

**Data quality tests** (dbt, severity `warn`): coordinates out of range or null, negative or extreme velocity, altitude below -300 m or above 18,500 m, aircraft reported on ground with high altitude or speed, null velocity, null origin country.

---|---|---|
| `flight_id` | string | Aircraft identifier (from `icao24`) |
| `call_sign` | string | Trimmed call sign |
| `origin_country` | string | Country of registration |
| `velocity` | float | Ground speed, m/s |
| `baro_altitude` | float | Barometric altitude, metres |
| `ingestion_date` | date / timestamp | Ingestion date |

---

## Gold (BigQuery, dbt)

### `gold_dim_aircraft`
One row per aircraft, latest known attributes (SCD Type 1).

| Column | Type | Description |
|---|---|---|
| `flight_id` | string | **Primary key** |
| `call_sign` | string | Latest call sign |
| `origin_country` | string | Country of registration |

### `gold_daily_flight_metrics`
One row per aircraft per day.

| Column | Type | Description |
|---|---|---|
| `flight_id` | string | References `gold_dim_aircraft` |
| `ingestion_date` | timestamp | Day of activity |
| `ping_count` | int | Telemetry events received that day |
| `max_velocity` | float | Highest ground speed, m/s |
| `max_altitude` | float | Highest barometric altitude, metres |

### `gold_anomalous_flights`
Aircraft whose maximum speed exceeds 300 m/s or whose maximum altitude exceeds 13,000 m.

| Column | Type | Description |
|---|---|---|
| `flight_id` | string | References `gold_dim_aircraft` |
| `max_velocity` | float | Highest ground speed observed, m/s |
| `max_altitude` | float | Highest barometric altitude observed, metres |
| `anomaly_reason` | string | Classification: likely sensor noise (within the tolerance band) or sustained out-of-envelope reading |

---

## Reference: `ref_airports` (dbt seed)

Large and medium airports from OurAirports. Built by `dbt/seeds/airports_filter.py`.

| Column | Type | Description |
|---|---|---|
| `ident` | string | Airport code (usually the ICAO code) |
| `name` | string | Airport name |
| `elevation_ft` | float | Elevation in feet. Null for 161 airports |
| `latitude_deg` | float | Degrees |
| `longitude_deg` | float | Degrees |
| `iso_country` | string | ISO country code |

Note: Namibia's country code is `NA`. The filter script reads the CSV with `keep_default_na=False` so pandas does not turn it into a null value.
