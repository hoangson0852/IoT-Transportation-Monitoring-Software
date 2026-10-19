from pydantic import BaseModel, Field, EmailStr, model_validator
from typing import List, Optional, Any
from datetime import datetime

# --- USER SCHEMAS ---
class UserBase(BaseModel):
    email: EmailStr
    display_name: Optional[str] = None
    role: Optional[str] = "driver"

class UserCreate(UserBase):
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(UserBase):
    uid: str
    created_at: Optional[str] = None

    class Config:
        from_attributes = True

# --- NODE / VEHICLE SCHEMAS ---
class NodeBase(BaseModel):
    node_id: str
    vehicle_name: Optional[str] = None
    role: Optional[str] = "tx"
    status: Optional[str] = "online"
    battery_last: Optional[float] = 100.0
    rssi_last: Optional[int] = 0
    snr_last: Optional[int] = 0

class NodeCreate(NodeBase):
    pass

class NodeResponse(NodeBase):
    id: int
    vehicle_id: str
    online: bool
    transport_id: Optional[str] = None
    
    # Telemetry values stored directly
    temperature: float
    humidity: float
    accel_magnitude: float
    light_level: int
    tamper: int
    anomaly_flag: int
    
    rf_anomaly_state: str
    knn_prediction: str
    ml_prediction: str
    ml_score: float
    
    latitude: float
    longitude: float
    gateway_rssi: int
    gateway_snr: int
    
    last_updated: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# --- TELEMETRY SCHEMAS ---
class TelemetryCreate(BaseModel):
    # Support both new format and legacy fields
    node_id: Optional[str] = None
    seq: Optional[int] = 0
    session_id: Optional[int] = 0
    timestamp: Optional[int] = None # Added for offline-to-online sync
    
    temperature: Optional[float] = 0.0
    humidity: Optional[float] = 0.0
    
    # Acceleration
    acceleration: Optional[float] = None
    accel_magnitude: Optional[float] = None # Legacy
    
    # Light
    light: Optional[float] = None
    light_level: Optional[int] = None # Legacy
    
    latitude: Optional[float] = 0.0
    longitude: Optional[float] = 0.0
    battery: Optional[float] = None
    
    # Signal
    rssi: Optional[int] = 0
    gateway_rssi: Optional[int] = None # Legacy
    snr: Optional[int] = 0
    gateway_snr: Optional[int] = None # Legacy
    
    alert_flags: Optional[int] = 0
    tamper: Optional[int] = 0
    anomaly_flag: Optional[int] = 0
    
    rf_anomaly_state: Optional[str] = "NORMAL"
    knn_prediction: Optional[str] = "NORMAL"
    ml_prediction: Optional[str] = "NORMAL"
    ml_score: Optional[float] = 0.0
    
    online: Optional[bool] = True

    @model_validator(mode='before')
    @classmethod
    def normalize_fields(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if "gps_latitude" in data and ("latitude" not in data or data["latitude"] == 0.0):
                data["latitude"] = data["gps_latitude"]
            if "gps_longitude" in data and ("longitude" not in data or data["longitude"] == 0.0):
                data["longitude"] = data["gps_longitude"]
            if "tamper_flag" in data and "tamper" not in data:
                data["tamper"] = data["tamper_flag"]
            if "vehicle_id" in data and not data.get("node_id"):
                data["node_id"] = data["vehicle_id"]
            if "accel_magnitude" in data and "acceleration" not in data:
                data["acceleration"] = data["accel_magnitude"]
            if "light_level" in data and "light" not in data:
                data["light"] = data["light_level"]

            # Auto-scale integer-scaled telemetry from Gateway (*10 for temp/hum, *100 for accel)
            if "temperature" in data and data["temperature"] is not None:
                try:
                    val = float(data["temperature"])
                    if val > 100.0:
                        data["temperature"] = round(val / 10.0, 1)
                except (ValueError, TypeError):
                    pass
            if "humidity" in data and data["humidity"] is not None:
                try:
                    val = float(data["humidity"])
                    if val > 100.0:
                        data["humidity"] = round(val / 10.0, 1)
                except (ValueError, TypeError):
                    pass
            if "accel_magnitude" in data and data["accel_magnitude"] is not None:
                try:
                    val = float(data["accel_magnitude"])
                    if val > 30.0:
                        data["accel_magnitude"] = round(val / 100.0, 2)
                        data["acceleration"] = data["accel_magnitude"]
                except (ValueError, TypeError):
                    pass
        return data

class TelemetryResponse(BaseModel):
    id: int
    node_id: str
    vehicle_id: str
    seq: int
    session_id: int
    
    temperature: float
    humidity: float
    acceleration: float
    accel_magnitude: float
    light: float
    light_level: int
    
    latitude: float
    longitude: float
    battery: float
    
    rssi: int
    gateway_rssi: int
    snr: int
    gateway_snr: int
    
    alert_flags: int
    tamper: int
    anomaly_flag: int
    
    ml_prediction: str
    ml_score: float
    created_at: datetime
    timestamp: str

    class Config:
        from_attributes = True

# --- ALERT SCHEMAS ---
class AlertCreate(BaseModel):
    node_id: Optional[str] = None
    vehicle_id: Optional[str] = None # Legacy compatibility
    alert_type: str # low_battery, tamper, route_deviation, sensor_abnormal, offline, security
    severity: Optional[str] = "medium"
    message: str

class AlertResponse(BaseModel):
    id: int
    node_id: str
    vehicle_id: str
    alert_type: str
    severity: str
    message: str
    resolved: bool
    created_at: datetime
    resolved_at: Optional[datetime] = None

    class Config:
        from_attributes = True

# --- MISSION & ROUTE SCHEMAS ---
class RoutePoint(BaseModel):
    lat: float
    lng: float

class MissionCreate(BaseModel):
    vehicle_id: str
    driver_uid: str
    cargo_description: Optional[str] = "Đạn dược"
    origin: Optional[str] = None
    destination: Optional[str] = None
    notes: Optional[str] = None
    route_points: Optional[List[RoutePoint]] = []

class MissionUpdateStatus(BaseModel):
    status: str # pending, inProgress, completed, cancelled

class MissionResponse(BaseModel):
    id: int
    mission_id: str
    vehicle_id: Optional[str] = None
    driver_uid: Optional[str] = None
    cargo_description: Optional[str] = None
    origin: Optional[str] = None
    destination: Optional[str] = None
    status: str
    notes: Optional[str] = None
    route_points: Optional[List[RoutePoint]] = []
    created_at: Optional[str] = None
    started_at: Optional[str] = None
    completed_at: Optional[str] = None

    class Config:
        from_attributes = True

class ActiveRouteResponse(BaseModel):
    vehicle_id: str
    points: List[RoutePoint]

# --- SYSTEM LOG SCHEMAS ---
class SystemLogCreate(BaseModel):
    source: str # backend, gateway, radio, security
    level: Optional[str] = "INFO" # INFO, WARN, ERROR, SECURITY
    code: Optional[str] = None
    message: str

class SystemLogResponse(BaseModel):
    id: int
    source: str
    level: str
    code: Optional[str] = None
    message: str
    created_at: datetime

    class Config:
        from_attributes = True
