from pyspark.sql import SparkSession
import logging

logging.basicConfig(level=logging.INFO)

# 1. INITIALIZE SPARK (THE ENGINE)
# Creates the session and download the Kafka connector matching PySpark 3.5.3 (Scala 2.12)
spark = SparkSession.builder \
    .appName("OpenSky_Streaming_Processor") \
    .config("spark.jars.packages", "org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.3") \
    .getOrCreate()

# Reduces the amount of garbage logs Spark throws in the console
spark.sparkContext.setLogLevel("WARN")

logging.info("Spark Session initialized successfully.")

# 2. READS FROM REDPANDA (THE RAW STREAM)
# Connects Spark to the broker and listen to the topic
df_kafka = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:19092") \
    .option("subscribe", "vuelos_telemetria") \
    .option("startingOffsets", "latest") \
    .load()

# 3. MINIMAL TRANSFORMATION (UNPACK BINARY & ADD METADATA)
# Extracts the raw JSON string, the exact Kafka ingestion timestamp, and the date for partitioning
df_bronze = df_kafka.selectExpr(
    "CAST(value AS STRING) as json_payload",
    "timestamp as ingested_at",
    "CAST(timestamp AS DATE) as ingestion_date"
)

# 4. WRITES TO THE DATA LAKE (BRONZE LAYER WITH HIVE PARTITIONING)
# Partitioning by 'ingestion_date' automatically creates folders like: ingestion_date=YYYY-MM-DD
query = df_bronze.writeStream \
    .outputMode("append") \
    .format("parquet") \
    .partitionBy("ingestion_date") \
    .option("path", "../data/bronze/telemetria") \
    .option("checkpointLocation", "../data/checkpoints/telemetria") \
    .start()

logging.info("Streaming started. Saving partitioned data to ../data/bronze/telemetria")

# 5. KEEPS THE SCRIPT ALIVE
query.awaitTermination()