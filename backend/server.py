import json
from datetime import datetime
import os
import ast
import numpy as np
import pandas as pd
import networkx as nx
import csv
import io
from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from sklearn.neighbors import BallTree

from main import louvain_astar, haversine, community_louvain
from database import engine, Base, SessionLocal
import models
from api_tester_html import TESTER_HTML

# 1. KHOI TẠO DATABASE
Base.metadata.create_all(bind=engine)

app = Flask(__name__)
CORS(app)

# Path configuration
base_dir = os.path.dirname(__file__)
csv_path = os.path.join(base_dir, "dataset.csv")

# ==========================================
# 2. LOAD GRAPH & COMMUNITIES
# ==========================================
df = pd.read_csv(csv_path, encoding="utf-8")
PLACE_COL = "place"
ADJ_COL = "adjacent_nodes" if "adjacent_nodes" in df.columns else "connected_nodes"
LAT_COL = "latitude"
LON_COL = "longitude"

G = nx.Graph()

for _, row in df.iterrows():
    node_id = int(row["id"])
    place = str(row.get(PLACE_COL, f"Place {node_id}"))
    G.add_node(
        node_id,
        lat=float(row[LAT_COL]),
        lon=float(row[LON_COL]),
        place=place,
    )

for _, row in df.iterrows():
    source = int(row["id"])
    conn_str = str(row.get(ADJ_COL, "")).strip()

    if not conn_str or conn_str == "nan":
        continue

    try:
        if not conn_str.startswith("["):
            conn_str = f"[{conn_str}]"

        neighbors = ast.literal_eval(conn_str)

        if isinstance(neighbors, int):
            neighbors = [neighbors]

        for target in neighbors:
            target = int(target)
            if target not in G:
                continue

            d = haversine(
                G.nodes[source]["lat"],
                G.nodes[source]["lon"],
                G.nodes[target]["lat"],
                G.nodes[target]["lon"],
            )
            G.add_edge(source, target, weight=d)
    except Exception:
        continue

partition = community_louvain.best_partition(G)

# ==========================================
# 3. INTEGRATED ML SUPERVISOR (BallTree)
# ==========================================
route_trees = {}
ML_THRESHOLD_METERS = 50.0

def build_route_tree(vehicle_id, points):
    if not points or len(points) == 0:
        return
    try:
        coords = np.array([[p['lat'], p['lng']] for p in points])
        tree = BallTree(np.deg2rad(coords), metric='haversine')
        route_trees[vehicle_id] = tree
        print(f"[ML] BallTree built for vehicle {vehicle_id} with {len(coords)} points.")
    except Exception as e:
        print(f"[ERROR] Error building BallTree for {vehicle_id}: {e}")

def check_route_deviation(vehicle_id, lat, lon):
    if vehicle_id not in route_trees:
        return "NORMAL", 0.0
    try:
        tree = route_trees[vehicle_id]
        curr_rad = np.deg2rad([[lat, lon]])
        dist, _ = tree.query(curr_rad, k=1)
        distance_m = dist[0][0] * 6371000
        prediction = "NORMAL" if distance_m <= ML_THRESHOLD_METERS else "OUT_OF_ROUTE"
        return prediction, round(distance_m, 2)
    except Exception as e:
        print(f"[ERROR] Error checking route deviation: {e}")
        return "NORMAL", 0.0

# Build trees and load active routes on startup from DB
db = SessionLocal()
try:
    # Build trees
    active_routes = db.query(models.ActiveRoute).all()
    for route in active_routes:
        if route.points_json:
            try:
                points = json.loads(route.points_json)
                build_route_tree(route.vehicle_id, points)
            except Exception as e:
                print(f"[ERROR] Error loading active route points for {route.vehicle_id}: {e}")
                
    # Create default user if empty
    if db.query(models.User).count() == 0:
        admin = models.User(
            uid="user_admin",
            email="admin@gmail.com",
            password="admin",
            display_name="Admin",
            role="admin",
            created_at=datetime.utcnow().isoformat() + "Z"
        )
        db.add(admin)
        db.commit()
        print("[DB] Created default admin user: admin@gmail.com / admin")
except Exception as e:
    print(f"[ERROR] Error initializing DB data: {e}")
finally:
    db.close()

# Helper function to serialize model objects to dict
def model_to_dict(model_obj):
    if model_obj is None:
        return None
    d = {}
    for column in model_obj.__table__.columns:
        d[column.name] = getattr(model_obj, column.name)
    return d

# Helper function to write system logs
def write_system_log(source, level, message):
    db = SessionLocal()
    try:
        log = models.SystemLog(
            source=source,
            level=level,
            message=message,
            created_at=datetime.utcnow().isoformat() + "Z"
        )
        db.add(log)
        db.commit()
    except Exception as e:
        print(f"[ERROR] Fail to write system log: {e}")
    finally:
        db.close()

# ==========================================
# 4. HEALTH CHECK ENDPOINT
# ==========================================
@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "ok",
        "service": "local-iot-backend",
        "database": "sqlite"
    })

# ==========================================
# 4b. API DEVELOPER CONSOLE & TESTER
# ==========================================
@app.route("/", methods=["GET"])
@app.route("/api/docs", methods=["GET"])
@app.route("/api/tester", methods=["GET"])
def api_tester():
    return TESTER_HTML

# ==========================================
# 5. ORIGINAL API ENDPOINTS
# ==========================================
@app.route("/places", methods=["GET"])
def get_places():
    try:
        places = []
        for node_id, data in G.nodes(data=True):
            places.append({
                "id": int(node_id),
                "place": data.get("place", f"Place {node_id}"),
                "lat": float(data["lat"]),
                "lng": float(data["lon"]),
            })
        places.sort(key=lambda item: item["place"].lower())
        return jsonify({
            "success": True,
            "count": len(places),
            "places": places,
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route("/get_route", methods=["POST"])
def get_route():
    try:
        req_data = request.json or {}
        start_id = int(req_data.get("start"))
        goal_id = int(req_data.get("goal"))

        if start_id not in G:
            return jsonify({"success": False, "error": f"Start node {start_id} không tồn tại."}), 400
        if goal_id not in G:
            return jsonify({"success": False, "error": f"Goal node {goal_id} không tồn tại."}), 400

        import time
        start_time = time.time()
        path = louvain_astar(G, partition, start_id, goal_id)
        end_time = time.time()
        print(f"⏱️ [BENCHMARK] A* Execution Time: {(end_time - start_time)*1000:.2f} ms")
        if not path:
            return jsonify({"success": False, "error": "Không tìm thấy đường."})

        route = []
        for node in path:
            route.append({
                "id": int(node),
                "place": G.nodes[node].get("place", f"Place {node}"),
                "lat": float(G.nodes[node]["lat"]),
                "lng": float(G.nodes[node]["lon"]),
            })
        return jsonify({"success": True, "path": route})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

# ==========================================
# 6. REST API ENDPOINTS WITH SQLITE
# ==========================================

# --- Auth ---
@app.route("/api/auth/login", methods=["POST"])
def api_login():
    req = request.json or {}
    email = req.get("email", "").strip()
    password = req.get("password", "").strip()

    db = SessionLocal()
    try:
        user = db.query(models.User).filter(
            models.User.email.collate('NOCASE') == email,
            models.User.password == password
        ).first()
        
        if user:
            user_info = model_to_dict(user)
            user_info.pop("password", None)
            write_system_log("server", "INFO", f"User logged in: {email}")
            return jsonify({"success": True, "user": user_info})
            
        return jsonify({"success": False, "error": "Email hoặc mật khẩu không đúng."}), 401
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

@app.route("/api/auth/register", methods=["POST"])
def api_register():
    req = request.json or {}
    email = req.get("email", "").strip()
    password = req.get("password", "").strip()

    if not email or not password:
        return jsonify({"success": False, "error": "Email và mật khẩu không được để trống."}), 400

    db = SessionLocal()
    try:
        existing = db.query(models.User).filter(models.User.email.collate('NOCASE') == email).first()
        if existing:
            return jsonify({"success": False, "error": "Email đã tồn tại trên hệ thống."}), 400

        uid = "user_" + datetime.utcnow().strftime("%Y%m%d%H%M%S")
        now_str = datetime.utcnow().isoformat() + "Z"

        new_user = models.User(
            uid=uid,
            email=email,
            password=password,
            display_name=email.split("@")[0],
            role="driver",
            created_at=now_str
        )
        db.add(new_user)
        db.commit()
        
        user_info = model_to_dict(new_user)
        user_info.pop("password", None)
        write_system_log("server", "INFO", f"New user registered: {email}")
        return jsonify({"success": True, "user": user_info})
    except Exception as e:
        db.rollback()
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

def normalize_vehicle_id(vid: str) -> str:
    if not vid:
        return "vehicle_01"
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
    return mapping.get(str(vid).strip(), str(vid).strip())

# --- Vehicles ---
@app.route("/api/vehicles", methods=["GET"])
def api_get_vehicles():
    db = SessionLocal()
    try:
        vehicles = db.query(models.Vehicle).filter(
            models.Vehicle.vehicle_id.notin_(["Transport-1", "Transport-01", "transport-1", "Transport-2", "Node-1", "Node-2"])
        ).all()
        list_vehicles = [model_to_dict(v) for v in vehicles]
        return jsonify({"success": True, "vehicles": list_vehicles})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

@app.route("/api/vehicles/<vehicle_id>", methods=["GET"])
def api_get_vehicle(vehicle_id):
    vehicle_id = normalize_vehicle_id(vehicle_id)
    db = SessionLocal()
    try:
        vehicle = db.query(models.Vehicle).filter(models.Vehicle.vehicle_id == vehicle_id).first()
        if not vehicle:
            return jsonify({"success": False, "error": "Không tìm thấy phương tiện."}), 404
        return jsonify({"success": True, "vehicle": model_to_dict(vehicle)})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

@app.route("/api/vehicles/<vehicle_id>/telemetry", methods=["POST"])
def api_update_telemetry(vehicle_id):
    vehicle_id = normalize_vehicle_id(vehicle_id)
    req = request.json or {}
    
    # Extract coordinates
    lat = float(req.get("latitude", req.get("lat", 0.0)))
    lon = float(req.get("longitude", req.get("lon", req.get("lng", 0.0))))
    
    # Calculate route deviation using BallTree
    ml_prediction, ml_score = check_route_deviation(vehicle_id, lat, lon)
    
    now_str = datetime.utcnow().isoformat() + "Z"
    
    db = SessionLocal()
    try:
        vehicle = db.query(models.Vehicle).filter(models.Vehicle.vehicle_id == vehicle_id).first()
        if not vehicle:
            vehicle = models.Vehicle(
                vehicle_id=vehicle_id,
                transport_id=vehicle_id,
                created_at=now_str
            )
            db.add(vehicle)
        
        # Update fields
        vehicle.online = req.get("online", True)
        vehicle.temperature = float(req.get("temperature", req.get("temp", vehicle.temperature)))
        vehicle.humidity = float(req.get("humidity", req.get("hum", vehicle.humidity)))
        vehicle.accel_magnitude = float(req.get("accel_magnitude", req.get("accel_mag", vehicle.accel_magnitude)))
        vehicle.light_level = int(req.get("light_level", req.get("light", vehicle.light_level)))
        vehicle.tamper = int(req.get("tamper", vehicle.tamper))
        vehicle.anomaly_flag = int(req.get("anomaly_flag", vehicle.anomaly_flag))
        vehicle.rf_anomaly_state = req.get("rf_anomaly_state", vehicle.rf_anomaly_state)
        vehicle.knn_prediction = req.get("knn_prediction", vehicle.knn_prediction)
        
        vehicle.ml_prediction = ml_prediction
        vehicle.ml_score = ml_score
        vehicle.latitude = lat
        vehicle.longitude = lon
        vehicle.gateway_rssi = int(req.get("gateway_rssi", req.get("rssi", vehicle.gateway_rssi)))
        vehicle.gateway_snr = int(req.get("gateway_snr", req.get("snr", vehicle.gateway_snr)))
        vehicle.last_updated = now_str
        
        # Create telemetry log entry
        telemetry_log = models.Telemetry(
            vehicle_id=vehicle_id,
            timestamp=now_str,
            temperature=vehicle.temperature,
            humidity=vehicle.humidity,
            accel_magnitude=vehicle.accel_magnitude,
            light_level=vehicle.light_level,
            tamper=vehicle.tamper,
            anomaly_flag=vehicle.anomaly_flag,
            ml_prediction=ml_prediction,
            ml_score=ml_score,
            latitude=lat,
            longitude=lon,
            gateway_rssi=vehicle.gateway_rssi,
            gateway_snr=vehicle.gateway_snr
        )
        db.add(telemetry_log)
        
        # Create alert if abnormal
        if vehicle.tamper == 1:
            alert = models.Alert(
                vehicle_id=vehicle_id,
                alert_type="tamper",
                severity="critical",
                message=f"Xe {vehicle_id} bi mo nap hop trai phep!",
                created_at=now_str
            )
            db.add(alert)
            write_system_log("security", "SECURITY", f"TAMPER ALERT on {vehicle_id}")
            
        if ml_prediction == "OUT_OF_ROUTE":
            alert = models.Alert(
                vehicle_id=vehicle_id,
                alert_type="route_deviation",
                severity="high",
                message=f"Xe {vehicle_id} di lech lo trinh cho phep: {ml_score}m",
                created_at=now_str
            )
            db.add(alert)
            write_system_log("security", "SECURITY", f"ROUTE DEVIATION ALERT on {vehicle_id}: {ml_score}m")
            
        if vehicle.anomaly_flag == 1:
            alert = models.Alert(
                vehicle_id=vehicle_id,
                alert_type="sensor_abnormal",
                severity="medium",
                message=f"Xe {vehicle_id} co chi so cam bien bat thuong (TinyML score cao)",
                created_at=now_str
            )
            db.add(alert)
            write_system_log("security", "WARN", f"TinyML anomaly detected on {vehicle_id}")
            
        db.commit()
        vehicle_data = model_to_dict(vehicle)
        return jsonify({"success": True, "vehicle": vehicle_data})
    except Exception as e:
        db.rollback()
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

# --- Vehicle Logs ---
@app.route("/api/vehicles/<vehicle_id>/logs", methods=["GET"])
def api_get_logs(vehicle_id):
    limit = int(request.args.get("limit", 200))
    db = SessionLocal()
    try:
        logs = db.query(models.Telemetry).filter(
            models.Telemetry.vehicle_id == vehicle_id
        ).order_by(
            models.Telemetry.timestamp.desc()
        ).limit(limit).all()
        
        list_logs = []
        for log in logs:
            list_logs.append({
                "timestamp": log.timestamp,
                "temperature": log.temperature,
                "humidity": log.humidity,
                "accel_magnitude": log.accel_magnitude,
                "light_level": log.light_level,
                "tamper": log.tamper,
                "anomaly_flag": log.anomaly_flag,
                "ml_prediction": log.ml_prediction,
                "ml_score": log.ml_score,
                "latitude": log.latitude,
                "longitude": log.longitude,
                "gateway_rssi": log.gateway_rssi,
                "gateway_snr": log.gateway_snr
            })
        return jsonify({"success": True, "logs": list_logs})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

# --- Missions ---
@app.route("/api/missions", methods=["GET"])
def api_get_missions():
    db = SessionLocal()
    try:
        missions = db.query(models.Mission).all()
        list_missions = []
        for m in missions:
            m_dict = model_to_dict(m)
            # Deserialize route points
            if m.route_points_json:
                m_dict["route_points"] = json.loads(m.route_points_json)
            else:
                m_dict["route_points"] = []
            m_dict.pop("route_points_json", None)
            list_missions.append(m_dict)
            
        list_missions.sort(key=lambda m: m.get("created_at", ""), reverse=True)
        return jsonify({"success": True, "missions": list_missions})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

@app.route("/api/missions/driver/<driver_uid>", methods=["GET"])
def api_get_driver_missions(driver_uid):
    db = SessionLocal()
    try:
        missions = db.query(models.Mission).filter(models.Mission.driver_uid == driver_uid).all()
        list_missions = []
        for m in missions:
            m_dict = model_to_dict(m)
            # Deserialize route points
            if m.route_points_json:
                m_dict["route_points"] = json.loads(m.route_points_json)
            else:
                m_dict["route_points"] = []
            m_dict.pop("route_points_json", None)
            list_missions.append(m_dict)
            
        list_missions.sort(key=lambda m: m.get("created_at", ""), reverse=True)
        return jsonify({"success": True, "missions": list_missions})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

@app.route("/api/missions", methods=["POST"])
def api_create_mission():
    req = request.json or {}
    
    mission_id = "mission_" + datetime.utcnow().strftime("%Y%m%d%H%M%S")
    now_str = datetime.utcnow().isoformat() + "Z"
    route_points = req.get("route_points", [])
    vehicle_id = req.get("vehicle_id", "")
    
    db = SessionLocal()
    try:
        mission = models.Mission(
            mission_id=mission_id,
            vehicle_id=vehicle_id,
            driver_uid=req.get("driver_uid", ""),
            cargo_description=req.get("cargo_description", "Đạn dược"),
            origin=req.get("origin", ""),
            destination=req.get("destination", ""),
            status="pending",
            notes=req.get("notes", ""),
            route_points_json=json.dumps(route_points) if route_points else None,
            created_at=now_str
        )
        db.add(mission)
        
        # Save active route for ML Supervisor
        if route_points:
            active_route = db.query(models.ActiveRoute).filter(models.ActiveRoute.vehicle_id == vehicle_id).first()
            if not active_route:
                active_route = models.ActiveRoute(
                    vehicle_id=vehicle_id,
                    mission_id=mission_id,
                    points_json=json.dumps(route_points),
                    created_at=now_str
                )
                db.add(active_route)
            else:
                active_route.mission_id = mission_id
                active_route.points_json = json.dumps(route_points)
                active_route.created_at = now_str
                
            build_route_tree(vehicle_id, route_points)
            
        db.commit()
        
        m_dict = model_to_dict(mission)
        m_dict["route_points"] = route_points
        m_dict.pop("route_points_json", None)
        write_system_log("server", "INFO", f"Created new mission: {mission_id} for {vehicle_id}")
        return jsonify({"success": True, "mission_id": mission_id, "mission": m_dict})
    except Exception as e:
        db.rollback()
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

@app.route("/api/missions/<mission_id>", methods=["PATCH"])
def api_update_mission_status(mission_id):
    req = request.json or {}
    status = req.get("status")
    
    db = SessionLocal()
    try:
        mission = db.query(models.Mission).filter(models.Mission.mission_id == mission_id).first()
        if not mission:
            return jsonify({"success": False, "error": "Không tìm thấy nhiệm vụ."}), 404
            
        mission.status = status
        now_str = datetime.utcnow().isoformat() + "Z"
        
        if status == "inProgress":
            mission.started_at = now_str
            write_system_log("server", "INFO", f"Mission started: {mission_id}")
        elif status in ["completed", "cancelled"]:
            mission.completed_at = now_str
            write_system_log("server", "INFO", f"Mission {status}: {mission_id}")
            
            # Remove from active routes
            vid = mission.vehicle_id
            active_route = db.query(models.ActiveRoute).filter(models.ActiveRoute.vehicle_id == vid).first()
            if active_route:
                db.delete(active_route)
                route_trees.pop(vid, None)
                print(f"[ML] Cleared active route & BallTree for {vid}")
                
        db.commit()
        m_dict = model_to_dict(mission)
        if mission.route_points_json:
            m_dict["route_points"] = json.loads(mission.route_points_json)
        else:
            m_dict["route_points"] = []
        m_dict.pop("route_points_json", None)
        return jsonify({"success": True, "mission": m_dict})
    except Exception as e:
        db.rollback()
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

# --- Active Routes ---
@app.route("/api/active_routes/<vehicle_id>", methods=["GET"])
def api_get_active_route(vehicle_id):
    db = SessionLocal()
    try:
        route_info = db.query(models.ActiveRoute).filter(models.ActiveRoute.vehicle_id == vehicle_id).first()
        if not route_info or not route_info.points_json:
            return jsonify({"success": True, "points": []})
        points = json.loads(route_info.points_json)
        return jsonify({"success": True, "points": points})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

# ==========================================
# 7. ALERTS & SYSTEM LOGS API (NEW)
# ==========================================
@app.route("/api/alerts", methods=["POST"])
def api_create_alert():
    req = request.json or {}
    vehicle_id = req.get("vehicle_id", req.get("node_id", ""))
    alert_type = req.get("alert_type", "sensor_abnormal")
    severity = req.get("severity", "medium")
    message = req.get("message", "")
    
    if not vehicle_id or not message:
        return jsonify({"success": False, "error": "Missing vehicle_id or message"}), 400
        
    db = SessionLocal()
    try:
        alert = models.Alert(
            vehicle_id=str(vehicle_id),
            alert_type=alert_type,
            severity=severity,
            message=message,
            created_at=datetime.utcnow().isoformat() + "Z"
        )
        db.add(alert)
        db.commit()
        db.refresh(alert)
        return jsonify({"success": True, "alert": model_to_dict(alert)})
    except Exception as e:
        db.rollback()
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

@app.route("/api/alerts", methods=["GET"])
def api_get_alerts():
    limit = int(request.args.get("limit", 50))
    db = SessionLocal()
    try:
        alerts = db.query(models.Alert).order_by(
            models.Alert.created_at.desc()
        ).limit(limit).all()
        list_alerts = [model_to_dict(a) for a in alerts]
        return jsonify({"success": True, "alerts": list_alerts})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

@app.route("/api/system_logs", methods=["GET"])
def api_get_system_logs():
    limit = int(request.args.get("limit", 100))
    db = SessionLocal()
    try:
        logs = db.query(models.SystemLog).order_by(
            models.SystemLog.created_at.desc()
        ).limit(limit).all()
        list_logs = [model_to_dict(l) for l in logs]
        return jsonify({"success": True, "logs": list_logs})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

# ==========================================
# 8. CSV REPORT EXPORT ENDPOINT (NEW)
# ==========================================
@app.route("/api/reports/export/<vehicle_id>", methods=["GET"])
def export_report_csv(vehicle_id):
    db = SessionLocal()
    try:
        logs = db.query(models.Telemetry).filter(
            models.Telemetry.vehicle_id == vehicle_id
        ).order_by(
            models.Telemetry.timestamp.desc()
        ).all()
        
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Write headers
        writer.writerow([
            "Thoi gian", "Nhiet do (C)", "Do am (%)", "Gia toc (g)", 
            "Anh sang", "Canh bao Cay mo (Tamper)", "Do lech lo trinh (m)", "ML Prediction", "Vi do (Lat)", "Kinh do (Lng)"
        ])
        
        for log in logs:
            writer.writerow([
                log.timestamp,
                log.temperature,
                log.humidity,
                log.accel_magnitude,
                log.light_level,
                "BI MO" if log.tamper == 1 else "AN TOAN",
                log.ml_score,
                log.ml_prediction,
                log.latitude,
                log.longitude
            ])
            
        write_system_log("server", "INFO", f"Exported CSV report for {vehicle_id}")
        response = Response(output.getvalue(), mimetype="text/csv")
        response.headers["Content-Disposition"] = f"attachment; filename=Bao_cao_an_ninh_{vehicle_id}.csv"
        return response
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        db.close()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)