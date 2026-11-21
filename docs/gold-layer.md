# Gold layer

The Gold layer turns Silver telemetry into tables for reporting. It is built with dbt and stored in BigQuery as a star schema: one dimension table for aircraft and two fact tables.

Models are in `dbt/models/gold/`. Tests are in `dbt/models/gold/schema.yml`.

## Design

- **Star schema.** Call sign and country are stored once per aircraft in the dimension table. The fact tables keep only `flight_id` and metrics, so they stay small and cheaper to scan.
- **Latest state per aircraft.** Call signs can change during a flight. The dimension keeps the most recent record per aircraft using `QUALIFY ROW_NUMBER()` (SCD Type 1).
- **Isolated spikes vs sustained readings.** Sensor readings are noisy. A single reading above a limit in a day is labelled as an isolated spike. Two or more readings from the same aircraft on the same day count as sustained. This works the same whether the producer polls every minute or every 15 minutes.
- **Rebuildable.** Every model is a full rebuild from Silver. Running `dbt run` again gives the same result.

## Models

### `gold_dim_aircraft`
One row per aircraft.

| Column | Description |
|---|---|
| `flight_id` | Aircraft identifier (ICAO 24-bit address). Primary key. |
| `call_sign` | Latest call sign |
| `origin_country` | Country of registration |

Tests: `flight_id` unique and not null.

### `gold_daily_flight_metrics`
One row per aircraft per day.

| Column | Description |
|---|---|
| `flight_id` | References `gold_dim_aircraft` |
| `ingestion_date` | Day |
| `ping_count` | Telemetry events received |
| `max_velocity` | Highest ground speed, m/s |
| `max_altitude` | Highest barometric altitude, m |

Tests: `flight_id` not null and present in `gold_dim_aircraft`.

### `gold_anomalous_flights`
One row per aircraft per day with at least one reading above 380 m/s ground speed or 16,000 m altitude.

Both limits sit above normal civil traffic: airliners with a strong jet-stream tailwind reach about 370 m/s ground speed, and business jets fly up to about 15,500 m.

| Column | Description |
|---|---|
| `flight_id` | References `gold_dim_aircraft` |
| `ingestion_date` | Day |
| `total_pings` | Readings received that day |
| `high_speed_pings` | Readings above 380 m/s |
| `high_altitude_pings` | Readings above 16,000 m |
| `max_velocity` | Highest ground speed, m/s |
| `max_altitude` | Highest barometric altitude, m |
| `anomaly_reason` | Classification, see below |

| `anomaly_reason` | Rule |
|---|---|
| Sustained high speed and altitude | 2 or more readings above both limits |
| Sustained high speed | 2 or more readings above 380 m/s |
| Sustained high altitude | 2 or more readings above 16,000 m |
| Isolated spike | only 1 reading above a limit, likely sensor noise |

The table flags aircraft for review. It does not identify the aircraft type.

Tests: one row per aircraft and day, `flight_id` not null and present in `gold_dim_aircraft`, `anomaly_reason` limited to the four values above.
