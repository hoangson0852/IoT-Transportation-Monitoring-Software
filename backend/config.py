import os
from dotenv import load_dotenv

# Load env variables from .env file if it exists
load_dotenv()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
APP_DATA_DIR = os.path.join(BASE_DIR, "app_data")
if not os.path.exists(APP_DATA_DIR):
    os.makedirs(APP_DATA_DIR)

APP_HOST = os.getenv("APP_HOST", "0.0.0.0")
APP_PORT = int(os.getenv("APP_PORT", "5002"))
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{os.path.join(APP_DATA_DIR, 'iot_transport.db')}")

# Gateway Serial parameters
SERIAL_PORT = os.getenv("SERIAL_PORT", "COM3")
SERIAL_BAUD = int(os.getenv("SERIAL_BAUD", "115200"))

# ML Supervisor Config
ML_THRESHOLD_METERS = float(os.getenv("ML_THRESHOLD_METERS", "50.0"))
