from sqlalchemy.orm import Session
from sqlalchemy import desc
from datetime import datetime
import json
import models
import schemas

# --- USER CRUD ---
def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email.collate('NOCASE') == email).first()

def create_user(db: Session, user: schemas.UserCreate, uid: str):
    now_str = datetime.utcnow().isoformat() + "Z"
    db_user = models.User(
        uid=uid,
        email=user.email,
        password=user.password,
        display_name=user.display_name or user.email.split("@")[0],
        role=user.role or "driver",
        created_at=now_str
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def normalize_node_id(node_id: str) -> str:
    if not node_id:
        return "vehicle_01"
    nid = str(node_id).strip()
    mapping = {
        "Transport-1": "vehicle_01",
        "Transport-01": "vehicle_01",
        "transport-1": "vehicle_01",
        "1": "vehicle_01",
        "Node-1": "vehicle_01",
        "node-1": "vehicle_01",
        "Transport-2": "vehicle_02",
        "Transport-02": "vehicle_02",
        "transport-2": "vehicle_02",
        "2": "vehicle_02",
        "Node-2": "vehicle_02",
        "node-2": "vehicle_02",
    }
    return mapping.get(nid, nid)

# --- NODE / VEHICLE CRUD ---
def get_nodes(db: Session):
    # Loại bỏ các node có tên định danh cũ không chuẩn
    return db.query(models.Node).filter(
        models.Node.node_id.notin_(["Transport-1", "Transport-01", "transport-1", "Transport-2", "Node-1", "Node-2"])
    ).all()

def get_node_by_id(db: Session, node_id: str):
    node_id = normalize_node_id(node_id)
    return db.query(models.Node).filter(models.Node.node_id == node_id).first()

def get_or_create_node(db: Session, node_id: str):
    node_id = normalize_node_id(node_id)
    node = get_node_by_id(db, node_id)
    if not node:
        now = datetime.utcnow()
        node = models.Node(
            node_id=node_id,
            vehicle_id=node_id, # Compatibility
            vehicle_name=node_id,
            role="tx",
            status="online",
            online=True,
            created_at=now,
            updated_at=now,
            last_seen=now
        )
        db.add(node)
        db.commit()
        db.refresh(node)
    return node

def update_node_telemetry(db: Session, node_id: str, tel: schemas.TelemetryCreate, ml_prediction: str, ml_score: float):
    node_id = normalize_node_id(node_id)
    node = get_or_create_node(db, node_id)
    
    # Update status fields based on device timestamp if available
    now = datetime.utcnow()
    packet_time = now
    if tel.timestamp and tel.timestamp > 1000000000:
        packet_time = datetime.utcfromtimestamp(tel.timestamp)
        
    # Only update last_seen if the packet is newer than the current last_seen
    if not node.last_seen or packet_time >= node.last_seen:
        node.last_seen = packet_time
        node.online = tel.online if tel.online is not None else True
        node.status = "online" if node.online else "offline"
    
    # Update battery, rssi, snr (with fallback for legacy fields)
    if tel.battery is not None:
        node.battery_last = float(tel.battery)
    node.rssi_last = int(tel.rssi if tel.rssi is not None else (tel.gateway_rssi or 0))
    node.snr_last = int(tel.snr if tel.snr is not None else (tel.gateway_snr or 0))
    
    # Update telemetry fields
    node.temperature = float(tel.temperature)
    node.humidity = float(tel.humidity)
    node.accel_magnitude = float(tel.acceleration if tel.acceleration is not None else (tel.accel_magnitude or 0.0))
    node.light_level = int(tel.light if tel.light is not None else (tel.light_level or 0))
    node.tamper = int(tel.tamper)
    node.anomaly_flag = int(tel.anomaly_flag)
    
    node.rf_anomaly_state = tel.rf_anomaly_state
    node.knn_prediction = tel.knn_prediction
    node.ml_prediction = ml_prediction
    node.ml_score = ml_score
    
    node.latitude = float(tel.latitude)
    node.longitude = float(tel.longitude)
    node.gateway_rssi = node.rssi_last
    node.gateway_snr = node.snr_last
    
    if not node.updated_at or packet_time >= node.updated_at:
        node.last_updated = packet_time.isoformat() + "Z"
        node.updated_at = packet_time
    
    db.commit()
    db.refresh(node)
    return node

# --- TELEMETRY CRUD ---
def create_telemetry_log(db: Session, node_id: str, tel: schemas.TelemetryCreate, ml_prediction: str, ml_score: float):
    now = datetime.utcnow()
    
    # Use device timestamp if provided (offline-to-online sync)
    if tel.timestamp and tel.timestamp > 1000000000:
        now = datetime.utcfromtimestamp(tel.timestamp)
        
    now_str = now.isoformat() + "Z"
    
    accel = float(tel.acceleration if tel.acceleration is not None else (tel.accel_magnitude or 0.0))
    light = float(tel.light if tel.light is not None else (tel.light_level or 0.0))
    rssi_val = int(tel.rssi if tel.rssi is not None else (tel.gateway_rssi or 0))
    snr_val = int(tel.snr if tel.snr is not None else (tel.gateway_snr or 0))
    
    db_telemetry = models.Telemetry(
        node_id=node_id,
        vehicle_id=node_id, # Compatibility
        seq=tel.seq or 0,
        session_id=tel.session_id or 0,
        temperature=float(tel.temperature),
        humidity=float(tel.humidity),
        acceleration=accel,
        accel_magnitude=accel, # Compatibility
        light=light,
        light_level=int(light), # Compatibility
        latitude=float(tel.latitude),
        longitude=float(tel.longitude),
        battery=float(tel.battery) if tel.battery is not None else 0.0,
        rssi=rssi_val,
        gateway_rssi=rssi_val, # Compatibility
        snr=snr_val,
        gateway_snr=snr_val, # Compatibility
        alert_flags=tel.alert_flags or 0,
        tamper=int(tel.tamper),
        anomaly_flag=int(tel.anomaly_flag),
        ml_prediction=ml_prediction,
        ml_score=ml_score,
        created_at=now,
        timestamp=now_str # Compatibility
    )
    db.add(db_telemetry)
    db.commit()
    db.refresh(db_telemetry)
    return db_telemetry

def get_telemetry_logs(db: Session, node_id: str, limit: int = 100):
    return db.query(models.Telemetry).filter(
        models.Telemetry.node_id == node_id
    ).order_by(
        desc(models.Telemetry.created_at)
    ).limit(limit).all()

# --- ALERT CRUD ---
def create_alert(db: Session, alert: schemas.AlertCreate):
    now = datetime.utcnow()
    # Handle either node_id or vehicle_id from request
    target_node = alert.node_id or alert.vehicle_id or "Unknown"
    
    db_alert = models.Alert(
        node_id=target_node,
        vehicle_id=target_node, # Compatibility
        alert_type=alert.alert_type,
        severity=alert.severity or "medium",
        message=alert.message,
        resolved=False,
        created_at=now
    )
    db.add(db_alert)
    db.commit()
    db.refresh(db_alert)
    return db_alert

def get_alerts(db: Session, resolved: bool = None, limit: int = 50):
    query = db.query(models.Alert)
    if resolved is not None:
        query = query.filter(models.Alert.resolved == resolved)
    return query.order_by(desc(models.Alert.created_at)).limit(limit).all()

def resolve_alert(db: Session, alert_id: int):
    alert = db.query(models.Alert).filter(models.Alert.id == alert_id).first()
    if alert:
        alert.resolved = True
        alert.resolved_at = datetime.utcnow()
        db.commit()
        db.refresh(alert)
    return alert

# --- SYSTEM LOG CRUD ---
def create_system_log(db: Session, log: schemas.SystemLogCreate):
    db_log = models.SystemLog(
        source=log.source,
        level=log.level or "INFO",
        code=log.code,
        message=log.message,
        created_at=datetime.utcnow()
    )
    db.add(db_log)
    db.commit()
    db.refresh(db_log)
    return db_log

def get_system_logs(db: Session, limit: int = 100):
    return db.query(models.SystemLog).order_by(desc(models.SystemLog.created_at)).limit(limit).all()

# --- MISSION & ACTIVE ROUTE CRUD ---
def get_missions(db: Session):
    return db.query(models.Mission).all()

def get_driver_missions(db: Session, driver_uid: str):
    return db.query(models.Mission).filter(models.Mission.driver_uid == driver_uid).all()

def create_mission(db: Session, mission: schemas.MissionCreate, mission_id: str, route_points_json: str):
    now_str = datetime.utcnow().isoformat() + "Z"
    db_mission = models.Mission(
        mission_id=mission_id,
        vehicle_id=mission.vehicle_id,
        driver_uid=mission.driver_uid,
        cargo_description=mission.cargo_description or "Đạn dược",
        origin=mission.origin,
        destination=mission.destination,
        status="pending",
        notes=mission.notes,
        route_points_json=route_points_json,
        created_at=now_str
    )
    db.add(db_mission)
    db.commit()
    db.refresh(db_mission)
    return db_mission

def update_mission_status(db: Session, mission_id: str, status: str, started_at: str = None, completed_at: str = None):
    mission = db.query(models.Mission).filter(models.Mission.mission_id == mission_id).first()
    if mission:
        mission.status = status
        if started_at:
            mission.started_at = started_at
        if completed_at:
            mission.completed_at = completed_at
        db.commit()
        db.refresh(mission)
    return mission

def get_active_route(db: Session, vehicle_id: str):
    return db.query(models.ActiveRoute).filter(models.ActiveRoute.vehicle_id == vehicle_id).first()

def create_or_update_active_route(db: Session, vehicle_id: str, mission_id: str, points_json: str):
    active_route = get_active_route(db, vehicle_id)
    now = datetime.utcnow()
    if not active_route:
        active_route = models.ActiveRoute(
            vehicle_id=vehicle_id,
            mission_id=mission_id,
            points_json=points_json,
            created_at=now.isoformat() + "Z"
        )
        db.add(active_route)
    else:
        active_route.mission_id = mission_id
        active_route.points_json = points_json
        active_route.created_at = now.isoformat() + "Z"
    db.commit()
    db.refresh(active_route)
    return active_route

def delete_active_route(db: Session, vehicle_id: str):
    active_route = get_active_route(db, vehicle_id)
    if active_route:
        db.delete(active_route)
        db.commit()
        return True
    return False
