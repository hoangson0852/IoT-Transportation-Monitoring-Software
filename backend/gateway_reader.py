#!/usr/bin/env python3
"""
gateway_reader.py
Đọc dữ liệu nối tiếp từ LoRa Gateway qua UART Serial Port và gửi POST lên FastAPI Local Backend.
Có hỗ trợ chế độ giả lập (Simulation Mode) nếu không kết nối được cổng Serial thật.
"""

import time
import json
import random
import requests
import serial
import sys
import os

# Import cấu hình
try:
    import config
    APP_PORT = config.APP_PORT
    APP_HOST = config.APP_HOST
    SERIAL_PORT = config.SERIAL_PORT
    SERIAL_BAUD = config.SERIAL_BAUD
except ImportError:
    APP_HOST = os.getenv("APP_HOST", "127.0.0.1")
    APP_PORT = int(os.getenv("APP_PORT", "5001"))
    SERIAL_PORT = os.getenv("SERIAL_PORT", "COM3")
    SERIAL_BAUD = int(os.getenv("SERIAL_BAUD", "115200"))

client_host = APP_HOST if APP_HOST != "0.0.0.0" else "127.0.0.1"
SERVER_URL = f"http://{client_host}:{APP_PORT}/telemetry"

def log_info(msg):
    print(f"[INFO] {msg}", flush=True)

def log_error(msg):
    print(f"[ERROR] {msg}", flush=True)

def send_telemetry(payload):
    try:
        headers = {"Content-Type": "application/json"}
        response = requests.post(SERVER_URL, json=payload, headers=headers, timeout=3)
        if response.status_code == 200:
            log_info(f"Đã gửi thành công Telemetry: Node={payload.get('node_id')}, Status={response.status_code}")
            return True
        else:
            log_error(f"Gửi Telemetry thất bại! Status={response.status_code}, Detail={response.text}")
            return False
    except Exception as e:
        log_error(f"Không kết nối được tới server tại {SERVER_URL}: {e}")
        return False

def run_simulation(node_id="vehicle_01"):
    log_info("Khởi động chế độ GIẢ LẬP (Simulation Mode). Đang tạo dữ liệu mẫu...")
    seq = 0
    session_id = random.randint(100, 999)
    
    # Starting coordinates (Bach Khoa Area)
    lat = 10.7723
    lon = 106.6578
    
    while True:
        seq += 1
        
        # Simulate slight movement
        lat += random.uniform(-0.0002, 0.0002)
        lon += random.uniform(-0.0002, 0.0002)
        
        # Normal ranges
        temp = round(random.uniform(25.0, 32.0), 1)
        hum = round(random.uniform(60.0, 80.0), 1)
        accel = round(random.uniform(0.01, 0.1), 2)
        light = round(random.uniform(300.0, 450.0), 1)
        battery = round(random.uniform(85.0, 95.0), 1)
        rssi = random.randint(-65, -45)
        snr = random.randint(8, 15)
        
        # Occasionally simulate a tamper (open lid)
        tamper = 0
        if random.random() < 0.02:
            tamper = 1
            light = 900.0
            accel = 0.5
            log_info("🔥 Giả lập sự kiện: TAMPER (Mở hộp nắp đạn)!")
            
        # Occasionally simulate anomaly (TinyML flag)
        anomaly = 0
        if random.random() < 0.03:
            anomaly = 1
            temp = 48.5
            hum = 18.0
            accel = 1.9
            log_info("⚠️ Giả lập sự kiện: TINYML ANOMALY (Rung lắc & nhiệt cao)!")

        # Occasionally simulate low battery (<20%)
        if random.random() < 0.04:
            battery = round(random.uniform(5.0, 19.0), 1)
            log_info(f"🔋 Giả lập sự kiện: PIN YẾU ({battery}%)!")

        payload = {
            "node_id": node_id,
            "seq": seq,
            "session_id": session_id,
            "temperature": temp,
            "humidity": hum,
            "acceleration": accel,
            "light": light,
            "latitude": round(lat, 5),
            "longitude": round(lon, 5),
            "battery": battery,
            "rssi": rssi,
            "snr": snr,
            "alert_flags": 0,
            "tamper": tamper,
            "anomaly_flag": anomaly
        }
        
        send_telemetry(payload)
        time.sleep(5) # Send every 5 seconds

def run_serial_reader():
    log_info(f"Đang thử kết nối cổng Serial UART: {SERIAL_PORT} (Baudrate: {SERIAL_BAUD})...")
    try:
        ser = serial.Serial(SERIAL_PORT, SERIAL_BAUD, timeout=1)
        log_info(f"✅ Đã kết nối thành công với cổng {SERIAL_PORT}!")
        
        while True:
            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if not line:
                    continue
                    
                log_info(f"Nhận dữ liệu thô: {line}")
                
                try:
                    # Trạm Gateway ESP32 thường gửi chuỗi JSON dạng:
                    # {"v":"vehicle_01","t":305,"h":702,"a":12,"l":350,"x":0,"la":10.7723,"lo":106.6578,"rssi":-45,"snr":12}
                    payload_raw = json.loads(line)
                    
                    # Convert to standardized FastAPI format
                    # Normalizing raw scaled values from LoRa packets
                    is_raw_lora = "t" in payload_raw or "h" in payload_raw or "a" in payload_raw
                    
                    if is_raw_lora:
                        temp = float(payload_raw.get("t", 0)) / 10.0
                        hum = float(payload_raw.get("h", 0)) / 10.0
                        accel = float(payload_raw.get("a", 0)) / 100.0
                    else:
                        temp = float(payload_raw.get("temperature", payload_raw.get("temp", 0)))
                        hum = float(payload_raw.get("humidity", payload_raw.get("hum", 0)))
                        accel = float(payload_raw.get("acceleration", payload_raw.get("accel_magnitude", 0)))
                        
                    node_id = str(payload_raw.get("v", payload_raw.get("node_id", "vehicle_01")))
                    lat = float(payload_raw.get("la", payload_raw.get("latitude", 0.0)))
                    lon = float(payload_raw.get("lo", payload_raw.get("longitude", 0.0)))
                    
                    payload_formatted = {
                        "node_id": node_id,
                        "seq": int(payload_raw.get("seq", 0)),
                        "session_id": int(payload_raw.get("session_id", 0)),
                        "timestamp": int(payload_raw.get("timestamp", payload_raw.get("ts", 0))) or None,
                        "temperature": round(temp, 1),
                        "humidity": round(hum, 1),
                        "acceleration": round(accel, 2),
                        "light": float(payload_raw.get("l", payload_raw.get("light", 0.0))),
                        "latitude": lat,
                        "longitude": lon,
                        "battery": float(payload_raw.get("battery", 100.0)),
                        "rssi": int(payload_raw.get("rssi", 0)),
                        "snr": int(payload_raw.get("snr", 0)),
                        "alert_flags": int(payload_raw.get("alert_flags", 0)),
                        "tamper": int(payload_raw.get("x", payload_raw.get("tamper", 0))),
                        "anomaly_flag": int(payload_raw.get("anomaly_flag", 0))
                    }
                    
                    send_telemetry(payload_formatted)
                except json.JSONDecodeError:
                    log_error("Không thể phân tích (parse) chuỗi JSON thô từ Serial!")
                except Exception as e:
                    log_error(f"Lỗi xử lý gói tin Serial: {e}")
            time.sleep(0.1)
    except serial.SerialException as e:
        log_error(f"Lỗi cổng Serial: {e}")
        log_info("Không tìm thấy phần cứng LoRa Gateway kết nối cổng Serial.")
        run_simulation()

if __name__ == "__main__":
    try:
        run_serial_reader()
    except KeyboardInterrupt:
        log_info("Đã dừng gateway_reader.py.")
        sys.exit(0)
