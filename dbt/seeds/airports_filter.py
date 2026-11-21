import pandas as pd

# Load the full OurAirports dataset.
# keep_default_na=False stops pandas from reading "NA" (Namibia's ISO code) as null.
# na_values=[''] keeps empty cells as null, so missing elevations stay NaN.
df_source = pd.read_csv('dbt/data/raw/airports_info.csv', keep_default_na=False, na_values=[''])

# Keep only the columns the altitude test and the dashboard need.
df_airports_mid_filtered = df_source[["ident", "name", "elevation_ft", "latitude_deg", "longitude_deg", "iso_country", "type"]]


# Keep commercial airports only. Heliports, small airfields and closed airports
# would match almost any location and hide real errors in the test.
def filter_by_type(df):
    mask = df["type"].isin(["large_airport", "medium_airport"])
    return df[mask]

df_airports_ready = filter_by_type(df_airports_mid_filtered)

# Sanity checks: expected ~5,282 rows, 161 null elevations, 0 null countries.
print(df_airports_ready.head(), len(df_airports_ready))
print(df_airports_ready.isnull().sum())

# Drop the type column, which is no longer needed.
df_airports_ready = df_airports_ready.drop(columns=['type'])

# Save the filtered dataset to a new CSV file for dbt to use as a seed.
df_airports_ready.to_csv('dbt/seeds/ref_airports.csv', index=False)