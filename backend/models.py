from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime
from datetime import datetime
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    uid = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    password = Column(String, nullable=False)
    display_name = Column(String, nullable=True)
    role = Column(String, default="driver")
    created_at = Column(String, nullable=True)

class Node(Base):
    __tablename__ = "nodes"

    id = Column(Integer, primary_key=True, index=True)
    node_id = Column(String, unique=True, index=True, nullable=False) # Maps to legacy vehicle_id or new node_id
    vehicle_id = Column(String, unique=True, index=True, nullable=False) # Legacy compatibility
    vehicle_name = Column(String, nullable=True)
    role = Column(String, default="tx") # tx, gateway, relay
    status = Column(String, default="online") # online, offline, warning
    
    last_seen = Column(DateTime, default=datetime.utcnow)
    battery_last = Column(Float, default=100.0)
    rssi_last = Column(Integer, default=0)
    snr_last = Column(Integer, default=0)
    
    # Legacy and current status parameters for instant dashboard load
    transport_id = Column(String, nullable=True)
    online = Column(Boolean, default=True)
    
    temperature = Column(Float, default=0.0)
    humidity = Column(Float, default=0.0)
    accel_magnitude = Column(Float, default=0.0)
    light_level = Column(Integer, default=0)
    tamper = Column(Integer, default=0)
    anomaly_flag = Column(Integer, default=0)
    
    rf_anomaly_state = Column(String, default="NORMAL")
    knn_prediction = Column(String, default="NORMAL")
    ml_prediction = Column(String, default="NORMAL")
    ml_score = Column(Float, default=0.0)
    
    latitude = Column(Float, default=0.0)
    longitude = Column(Float, default=0.0)
    gateway_rssi = Column(Integer, default=0)
    gateway_snr = Column(Integer, default=0)
    
    last_updated = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Telemetry(Base):
    __tablename__ = "telemetry"

    id = Column(Integer, primary_key=True, index=True)
    node_id = Column(String, index=True, nullable=False)
    vehicle_id = Column(String, index=True, nullable=False) # Legacy compatibility
    
    seq = Column(Integer, default=0)
    session_id = Column(Integer, default=0)
    
    temperature = Column(Float, default=0.0)
    humidity = Column(Float, default=0.0)
    acceleration = Column(Float, default=0.0) # Standard name
    accel_magnitude = Column(Float, default=0.0) # Legacy compatibility
    light = Column(Float, default=0.0) # Standard name
    light_level = Column(Integer, default=0) # Legacy compatibility
    
    latitude = Column(Float, default=0.0)
    longitude = Column(Float, default=0.0)
    battery = Column(Float, default=100.0)
    
    rssi = Column(Integer, default=0) # Standard name
    gateway_rssi = Column(Integer, default=0) # Legacy compatibility
    snr = Column(Integer, default=0) # Standard name
    gateway_snr = Column(Integer, default=0) # Legacy compatibility
    
    alert_flags = Column(Integer, default=0)
    tamper = Column(Integer, default=0)
    anomaly_flag = Column(Integer, default=0)
    
    ml_prediction = Column(String, default="NORMAL")
    ml_score = Column(Float, default=0.0)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    timestamp = Column(String, nullable=False) # Legacy compatibility

class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, index=True)
    node_id = Column(String, index=True, nullable=False)
    vehicle_id = Column(String, index=True, nullable=False) # Legacy compatibility
    alert_type = Column(String, nullable=False) # low_battery, tamper, route_deviation, sensor_abnormal, offline, security
    severity = Column(String, default="medium") # low, medium, high, critical
    message = Column(String, nullable=False)
    resolved = Column(Boolean, default=False)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    resolved_at = Column(DateTime, nullable=True)

class Mission(Base):
    __tablename__ = "missions"

    id = Column(Integer, primary_key=True, index=True)
    mission_id = Column(String, unique=True, index=True, nullable=False)
    vehicle_id = Column(String, nullable=True)
    driver_uid = Column(String, nullable=True)
    cargo_description = Column(String, default="Dan duoc")
    origin = Column(String, nullable=True)
    destination = Column(String, nullable=True)
    status = Column(String, default="pending") # pending, inProgress, completed, cancelled
    notes = Column(String, nullable=True)
    route_points_json = Column(String, nullable=True) # JSON-serialized list of route points
    created_at = Column(String, nullable=True)
    started_at = Column(String, nullable=True)
    completed_at = Column(String, nullable=True)

class ActiveRoute(Base):
    __tablename__ = "active_routes"

    id = Column(Integer, primary_key=True, index=True)
    vehicle_id = Column(String, unique=True, index=True, nullable=False)
    mission_id = Column(String, nullable=True)
    points_json = Column(String, nullable=True) # JSON-serialized list of route points
    created_at = Column(String, nullable=True)

class SystemLog(Base):
    __tablename__ = "system_logs"

    id = Column(Integer, primary_key=True, index=True)
    source = Column(String, nullable=False) # backend, gateway, radio, security
    level = Column(String, default="INFO") # INFO, WARN, ERROR, SECURITY
    code = Column(String, nullable=True) # e.g. AUTH_FAIL, NODE_NOT_FOUND, TELEMETRY_INVALID_PAYLOAD
    message = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
