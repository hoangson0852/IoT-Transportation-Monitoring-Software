"""
===============================================================================
MODULE NHÚNG ENGINE MQTT SUBSCRIBER ASYNC (EMBEDDED MQTT SUBSCRIBER ENGINE)
Backend Server - Đồ án Tốt nghiệp 2026
===============================================================================
"""

import os
import json
import asyncio
import paho.mqtt.client as mqtt
from datetime import datetime

import crud
import schemas
from database import SessionLocal
from cache import global_cache

MQTT_HOST = os.getenv("MQTT_HOST", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", 8883))
MQTT_USE_TLS = os.getenv("MQTT_USE_TLS", "true" if MQTT_PORT == 8883 else "false").lower() == "true"
MQTT_CA_CERT = os.getenv("MQTT_CA_CERT", None)
MQTT_TOPIC_TELEMETRY = "iot/ammo/telemetry/#"
MQTT_TOPIC_ALERTS = "iot/ammo/alerts/#"
MQTT_TOPIC_VEHICLES_TELEMETRY = "vehicles/+/telemetry"
MQTT_TOPIC_VEHICLES_STATUS = "vehicles/+/status"

class EmbeddedMQTTEngine:
    def __init__(self, ws_telemetry_manager=None, ws_alerts_manager=None):
        self.ws_telemetry_manager = ws_telemetry_manager
        self.ws_alerts_manager = ws_alerts_manager
        self.client = mqtt.Client(client_id="Backend_FastAPI_Subscriber")
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.is_running = False

        if MQTT_USE_TLS:
            if MQTT_CA_CERT and os.path.exists(MQTT_CA_CERT):
                self.client.tls_set(ca_certs=MQTT_CA_CERT)
                print(f"[MQTT ENGINE] TLS Enabled with CA Cert: {MQTT_CA_CERT}")
            else:
                try:
                    self.client.tls_set()
                    self.client.tls_insecure_set(True)
                    print("[MQTT ENGINE] TLS Enabled (Default CA / Insecure mode for local dev)")
                except Exception as e:
                    print(f"[MQTT ENGINE WARNING] TLS setup error: {e}")


    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            print(f"[MQTT ENGINE] Connected to Mosquitto Broker at {MQTT_HOST}:{MQTT_PORT}")
            client.subscribe(MQTT_TOPIC_TELEMETRY)
            client.subscribe(MQTT_TOPIC_ALERTS)
            client.subscribe(MQTT_TOPIC_VEHICLES_TELEMETRY)
            client.subscribe(MQTT_TOPIC_VEHICLES_STATUS)
            print(f"[MQTT ENGINE] Subscribed to topics: {MQTT_TOPIC_TELEMETRY}, {MQTT_TOPIC_ALERTS}, {MQTT_TOPIC_VEHICLES_TELEMETRY}, {MQTT_TOPIC_VEHICLES_STATUS}")
        else:
            print(f"[MQTT ENGINE] Connection failed with response code: {rc}")

    def on_message(self, client, userdata, msg):
        try:
            payload = json.loads(msg.payload.decode('utf-8'))
            topic = msg.topic
            
            db = SessionLocal()
            try:
                if "telemetry" in topic:
                    node_id = payload.get("node_id") or payload.get("vehicle_id") or "node_unknown"
                    
                    # Deduplication check
                    seq = payload.get("seq", 0)
                    ts = payload.get("timestamp", 0)
                    if global_cache.is_duplicate_packet(node_id, seq, ts):
                        print(f"[MQTT DEDUP] Ignored duplicate packet from {node_id} (seq: {seq})")
                        return

                    tel_obj = schemas.TelemetryCreate(**payload)
                    node = crud.update_node_telemetry(db, node_id, tel_obj, "NORMAL", 0.0)
                    crud.create_telemetry_log(db, node_id, tel_obj, "NORMAL", 0.0)
                    
                    node_data = {
                        "node_id": node.node_id,
                        "vehicle_id": node.node_id,
                        "online": node.online,
                        "temperature": node.temperature,
                        "humidity": node.humidity,
                        "accel_magnitude": node.accel_magnitude,
                        "latitude": node.latitude,
                        "longitude": node.longitude,
                        "battery": node.battery_last,
                        "tamper": node.tamper,
                        "anomaly_flag": node.anomaly_flag,
                        "last_updated": node.last_updated
                    }
                    global_cache.set_latest(node_id, node_data)
                    
                    # Broadcast via WebSocket if manager available
                    if self.ws_telemetry_manager:
                        asyncio.run_coroutine_threadsafe(
                            self.ws_telemetry_manager.broadcast({"type": "telemetry", "data": node_data}),
                            asyncio.get_event_loop()
                        )
                elif "alerts" in topic:
                    alert_obj = schemas.AlertCreate(**payload)
                    crud.create_alert(db, alert_obj)
                    if self.ws_alerts_manager:
                        asyncio.run_coroutine_threadsafe(
                            self.ws_alerts_manager.broadcast({"type": "alert", "data": payload}),
                            asyncio.get_event_loop()
                        )
            finally:
                db.close()
        except Exception as e:
            print(f"[MQTT ENGINE ERROR] {e}")

    def start_background(self):
        try:
            self.client.connect_async(MQTT_HOST, MQTT_PORT, 60)
            self.client.loop_start()
            self.is_running = True
            print("[MQTT ENGINE] Background Loop Started.")
        except Exception as e:
            print(f"[MQTT ENGINE WARNING] Could not start MQTT client: {e}")

    def stop(self):
        if self.is_running:
            self.client.loop_stop()
            self.client.disconnect()
            self.is_running = False
            print("[MQTT ENGINE] Engine Stopped.")
