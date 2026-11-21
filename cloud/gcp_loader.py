import os
import logging
from pathlib import Path
from google.cloud import storage

logging.basicConfig(level=logging.INFO)

# 1. CONFIGURATION
# Path to your downloaded Service Account JSON key
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "../credentials/gcp_key.json"

BUCKET_NAME = "opensky-data-lake-straccia"  # Replace with your GCS bucket name
LOCAL_BRONZE_DIR = Path("../data/bronze/telemetria")
GCS_PREFIX = "bronze/telemetria"

def upload_bronze_to_gcs():
    if not LOCAL_BRONZE_DIR.exists(): #Idempotency: If the local directory doesn't exist, we don't attempt to upload anything.
        logging.warning(f"Local directory {LOCAL_BRONZE_DIR} does not exist.")
        return

    client = storage.Client()
    bucket = client.bucket(BUCKET_NAME)
    uploaded_count = 0

    # Walks through Hive-partitioned folders (ingestion_date=YYYY-MM-DD)
    for file_path in LOCAL_BRONZE_DIR.rglob("*.parquet"):
        # Preserves the Hive partition structure in GCS
        relative_path = file_path.relative_to(LOCAL_BRONZE_DIR).as_posix()
        blob_path = f"{GCS_PREFIX}/{relative_path}"
        blob = bucket.blob(blob_path)

        # Uploads only if the file doesn't already exist in the bucket (Idempotency)
        if not blob.exists(): #Idempotency: If the file already exists in GCS, we skip the upload to avoid duplicates.
            logging.info(f"Uploading {relative_path} to gs://{BUCKET_NAME}/{blob_path}...")
            blob.upload_from_filename(str(file_path))
            uploaded_count += 1

    logging.info(f"Sync complete. Uploaded {uploaded_count} new Parquet files to GCS.")

if __name__ == "__main__":
    upload_bronze_to_gcs()