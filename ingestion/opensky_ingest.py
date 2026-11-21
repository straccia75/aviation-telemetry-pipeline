import requests
import logging
import sys, os
import json
import time
from kafka import KafkaProducer

logging.basicConfig(level=logging.INFO)
producer = KafkaProducer(
    bootstrap_servers='localhost:19092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)


ENDPOINT_URL = "https://opensky-network.org/api/states/all"
OPEN_SKY_USERNAME = "straccia75"

def fetch_opensky_data():
    try:
        response = requests.get(ENDPOINT_URL, auth=(OPEN_SKY_USERNAME, ''))
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        logging.error(f"Error fetching data from OpenSky API: {e}")
        return None



if __name__ == "__main__":
    while True:
        data = fetch_opensky_data()
        
        # Validates that 'data' exists and the 'states' key has content
        if data and data.get("states"):
            flights = data["states"]
            
            # Unpacks the payload: sends plane by plane (event by event)
            for avion in flights:
                producer.send('vuelos_telemetria', avion)
            
            # Forces the producer to send all queued messages
            producer.flush() 
            
            # Logs only the count, not the raw data to avoid RAM saturation
            logging.info(f"Sent {len(flights)} plane records to Redpanda.")
        else:
            logging.warning("No valid data retrieved in this iteration.")
            
        # Anonymous OpenSky access: 400 credits/day, 4 per global call -> max ~100 calls/day
        time.sleep(900)