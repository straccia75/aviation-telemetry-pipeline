# Gold layer

The Gold layer turns Silver telemetry into tables for reporting. It is built with dbt and stored in BigQuery as a star schema: one dimension table for aircraft and two fact tables.

Models are in `dbt/models/gold/`. Tests are in `dbt/models/gold/schema.yml`.

## Design

- **Star schema.** Call sign and country are stored once per aircraft in the dimension table. The fact tables keep only `flight_id` and metrics, so they stay small and cheaper to scan.
- **Latest state per aircraft.** Call signs can change during a flight. The dimension keeps the most recent record per aircraft using `QUALIFY ROW_NUMBER()` (SCD Type 1).
- **Tolerance band for anomalies.** Sensor readings are noisy, so values slightly above the limits are labelled as possible noise and not as real anomalies.
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
Aircraft whose maximum speed is above 300 m/s or maximum altitude above 13,000 m.

| `anomaly_reason` | Rule |
|---|---|
| Above commercial speed and altitude | speed > 330 m/s and altitude > 13,300 m |
| Above commercial speed | speed > 330 m/s |
| Above commercial altitude | altitude > 13,300 m |
| Possible sensor noise | above 300 m/s or 13,000 m, but within the tolerance band |

Speed is ground speed, so strong tailwinds can push commercial aircraft above the limit. The table flags flights for review. It does not identify aircraft type.

Tests: `flight_id` unique and not null, `anomaly_reason` limited to the four values above.
