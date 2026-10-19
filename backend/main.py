import json
from datetime import datetime
import os
import ast
import numpy as np
import pandas as pd
import networkx as nx
import csv
import io
from typing import List, Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, Depends, HTTPException, Query, Request, status, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse, HTMLResponse, StreamingResponse
from sqlalchemy import desc
from sqlalchemy.orm import Session
from sklearn.neighbors import BallTree

# Import local modules
import models
import schemas
import crud
import config
from database import engine, SessionLocal
import auth
from cache import global_cache
from mqtt_engine import EmbeddedMQTTEngine
from routing import louvain_astar, haversine, community_louvain
from api_tester_html import TESTER_HTML
from dqm_engine import dqm_engine
from prediction_engine import prediction_engine

import hmac
import hashlib
import base64
from datetime import timedelta

# ==========================================
# WEBSOCKET & IN-MEMORY CACHE ENGINE
# ==========================================
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in list(self.active_connections):
            try:
                await connection.send_json(message)
            except Exception:
                self.disconnect(connection)

ws_telemetry_manager = ConnectionManager()
ws_alerts_manager = ConnectionManager()
LATEST_TELEMETRY_CACHE = {}

# ==========================================
# JWT SECURITY & AUTHENTICATION
# ==========================================
JWT_SECRET = os.getenv("JWT_SECRET", "super-secret-key-datn-2026")

def create_jwt_token(data: dict, expires_hours: int = 24) -> str:
    header = base64.urlsafe_b64encode(json.dumps({"alg": "HS256", "typ": "JWT"}).encode()).decode().rstrip("=")
    payload_data = data.copy()
    payload_data["exp"] = int((datetime.utcnow() + timedelta(hours=expires_hours)).timestamp())
    payload = base64.urlsafe_b64encode(json.dumps(payload_data).encode()).decode().rstrip("=")
    signature_input = f"{header}.{payload}".encode()
    signature = base64.urlsafe_b64encode(hmac.new(JWT_SECRET.encode(), signature_input, hashlib.sha256).digest()).decode().rstrip("=")
    return f"{header}.{payload}.{signature}"

def verify_jwt_token(token: str) -> Optional[dict]:
    try:
        parts = token.split(".")
        if len(parts) != 3:
            return None
        header, payload, signature = parts
        signature_input = f"{header}.{payload}".encode()
        expected_sig = base64.urlsafe_b64encode(hmac.new(JWT_SECRET.encode(), signature_input, hashlib.sha256).digest()).decode().rstrip("=")
        if not hmac.compare_digest(signature, expected_sig):
            return None
        padded_payload = payload + "=" * (-len(payload) % 4)
        data = json.loads(base64.urlsafe_b64decode(padded_payload).decode())
        if data.get("exp", 0) < int(datetime.utcnow().timestamp()):
            return None
        return data
    except Exception:
        return None


# ==========================================
# 1. GRAPH & COMMUNITIES LOAD
# ==========================================
base_dir = os.path.dirname(os.path.abspath(__file__))
csv_path = os.path.join(base_dir, "dataset.csv")

if not os.path.exists(csv_path):
    # Fallback to write an empty or small dataset if missing during testing
    print(f"[WARNING] dataset.csv not found at {csv_path}!")
    
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
        risk_penalty=0.0,
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
            G.add_edge(source, target, distance=d, weight=d)
    except:
        continue

partition = community_louvain.best_partition(G)
print(f"[GRAPH] Loaded {G.number_of_nodes()} nodes and {G.number_of_edges()} edges.")

# Khởi tạo BallTree toàn cục để ánh xạ toạ độ bất kỳ thành node trên đồ thị (Giai đoạn 4)
global_node_ids = list(G.nodes())
global_coords = np.array([[G.nodes[n]["lat"], G.nodes[n]["lon"]] for n in global_node_ids])
global_graph_tree = BallTree(np.deg2rad(global_coords), metric='haversine')
print("[GRAPH] Global BallTree initialized for Spatiotemporal mapping.")

# ==========================================
# 2. ML SUPERVISOR (BallTree)
# ==========================================
route_trees = {}

def build_route_tree(vehicle_id: str, points: list):
    if not points or len(points) == 0:
        return
    try:
        coords = np.array([[p['lat'], p['lng']] for p in points])
        tree = BallTree(np.deg2rad(coords), metric='haversine')
        route_trees[vehicle_id] = tree
        print(f"[ML] BallTree built for vehicle {vehicle_id} with {len(coords)} points.")
    except Exception as e:
        print(f"[ERROR] Error building BallTree for {vehicle_id}: {e}")

def check_route_deviation(vehicle_id: str, tel: schemas.TelemetryCreate):
    if vehicle_id not in route_trees:
        return "NORMAL", 0.0
    try:
        tree = route_trees[vehicle_id]
        lat = float(tel.latitude)
        lon = float(tel.longitude)
        curr_rad = np.deg2rad([[lat, lon]])
        dist, _ = tree.query(curr_rad, k=1)
        distance_m = dist[0][0] * 6371000
        
        # Dynamic threshold logic (Giai đoạn 3)
        dynamic_threshold = config.ML_THRESHOLD_METERS
        
        accel = tel.accel_magnitude if tel.accel_magnitude is not None else (tel.acceleration or 0.0)
        snr = tel.snr if tel.snr is not None else (tel.gateway_snr or 0)
        
        if accel > 2.0:
            dynamic_threshold += (accel - 2.0) * 10.0
            
        if snr < 0:
            dynamic_threshold += 15.0
            
        dynamic_threshold = min(dynamic_threshold, config.ML_THRESHOLD_METERS * 2.5)
        
        prediction = "NORMAL" if distance_m <= dynamic_threshold else "OUT_OF_ROUTE"
        return prediction, round(distance_m, 2)
    except Exception as e:
        print(f"[ERROR] Error checking route deviation: {e}")
        return "NORMAL", 0.0

def check_route_deviation_batch(vehicle_id: str, coords: list):
    """
    Vectorized query for multiple points simultaneously.
    coords is a list of [lat, lon] pairs.
    Returns list of (prediction, distance_m)
    """
    if vehicle_id not in route_trees:
        return [("NORMAL", 0.0) for _ in coords]
    try:
        tree = route_trees[vehicle_id]
        curr_rad = np.deg2rad(coords)
        # Vectorized query instead of for loop
        dist, _ = tree.query(curr_rad, k=1)
        
        distances_m = dist[:, 0] * 6371000
        results = []
        for d in distances_m:
            pred = "NORMAL" if d <= config.ML_THRESHOLD_METERS else "OUT_OF_ROUTE"
            results.append((pred, round(d, 2)))
        return results
    except Exception as e:
        print(f"[ERROR] Error checking route deviation batch: {e}")
        return [("NORMAL", 0.0) for _ in coords]

# ==========================================
# 3. FASTAPI LIFESPAN
# ==========================================
import asyncio

async def periodic_partition_update():
    global partition
    while True:
        await asyncio.sleep(60) # Cập nhật định kỳ 60s
        try:
            print("[BACKGROUND] Updating Louvain partition...")
            partition = await asyncio.to_thread(community_louvain.best_partition, G, weight="weight")
            print(f"[BACKGROUND] Louvain partition updated. {len(set(partition.values()))} communities found.")
        except asyncio.CancelledError:
            break
        except Exception as e:
            print(f"[BACKGROUND ERROR] {e}")

async def spatiotemporal_prediction():
    while True:
        await asyncio.sleep(3600) # Cập nhật mỗi 1 giờ
        try:
            print("[BACKGROUND] Chạy mô hình dự đoán Không gian - Thời gian (Spatiotemporal)...")
            await asyncio.to_thread(run_spatiotemporal_model)
        except asyncio.CancelledError:
            break
        except Exception as e:
            print(f"[BACKGROUND ERROR] Spatiotemporal: {e}")

def run_spatiotemporal_model():
    from database import SessionLocal
    current_hour = datetime.utcnow().hour
    db = SessionLocal()
    try:
        # Giả lập: Lấy 1000 telemetry gần nhất
        recent_telemetry = db.query(models.Telemetry).order_by(models.Telemetry.id.desc()).limit(1000).all()
        node_snr_sum = {}
        node_snr_count = {}
        for t in recent_telemetry:
            # Nếu bản ghi thuộc khung giờ hiện tại
            if t.created_at and t.created_at.hour == current_hour:
                curr_rad = np.deg2rad([[t.latitude, t.longitude]])
                _, indices = global_graph_tree.query(curr_rad, k=1)
                mapped_node_id = global_node_ids[indices[0][0]]
                snr_val = t.snr if t.snr is not None else (t.gateway_snr or 0)
                node_snr_sum[mapped_node_id] = node_snr_sum.get(mapped_node_id, 0) + snr_val
                node_snr_count[mapped_node_id] = node_snr_count.get(mapped_node_id, 0) + 1
                
        affected_nodes = 0
        for node_id, total_snr in node_snr_sum.items():
            avg_snr = total_snr / node_snr_count[node_id]
            if avg_snr < 0:
                # Tín hiệu có xu hướng kém => Chủ động áp dụng rủi ro 0.5 (Giai đoạn 4)
                G.nodes[node_id]["risk_penalty"] = max(G.nodes[node_id].get("risk_penalty", 0.0), 0.5)
                for neighbor in G.neighbors(node_id):
                    r1 = G.nodes[node_id].get("risk_penalty", 0.0)
                    r2 = G.nodes[neighbor].get("risk_penalty", 0.0)
                    dist = G[node_id][neighbor]["distance"]
                    G[node_id][neighbor]["weight"] = dist * (1.0 + max(r1, r2))
                affected_nodes += 1
                
        # Clear cache after updating weights
        if affected_nodes > 0:
            route_cache.clear()
            
        print(f"[PREDICTION] Đã dự đoán và cập nhật rủi ro cho {affected_nodes} khu vực dựa trên xu hướng SNR vào lúc {current_hour}h.")
        return {"success": True, "affected_nodes": affected_nodes, "message": f"Spatiotemporal updated {affected_nodes} nodes"}
    except Exception as e:
        print(f"[ERROR] run_spatiotemporal_model: {e}")
        return {"success": False, "error": str(e)}
    finally:
        db.close()



@asynccontextmanager
async def lifespan(app: FastAPI):
    # Khởi động background task (Giai đoạn 2)
    partition_task = asyncio.create_task(periodic_partition_update())
    # Khởi động predictive task (Giai đoạn 4)
    predict_task = asyncio.create_task(spatiotemporal_prediction())
    
    # Create DB tables
    models.Base.metadata.create_all(bind=engine)
    
    # Load active routes & build BallTrees
    db = SessionLocal()
    try:
        active_routes = db.query(models.ActiveRoute).all()
        for route in active_routes:
            if route.points_json:
                try:
                    points = json.loads(route.points_json)
                    build_route_tree(route.vehicle_id, points)
                except Exception as e:
                    print(f"[ERROR] Error loading active route points for {route.vehicle_id}: {e}")
        
        # Create default admin if not exists
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
        print(f"[ERROR] Error initializing database: {e}")
    finally:
        db.close()
        
    # Start Embedded MQTT Engine
    mqtt_engine = EmbeddedMQTTEngine(ws_telemetry_manager, ws_alerts_manager)
    mqtt_engine.start_background()

    # Start mDNS Service (iot-server.local)
    zeroconf_inst = None
    try:
        from zeroconf import Zeroconf, ServiceInfo
        import socket
        # Smart local IP resolution: prioritize physical Wi-Fi/LAN, avoid virtual adapters (WARP, Docker, VirtualBox)
        local_ip = os.getenv("SERVER_IP", os.getenv("HOST_IP", "")).strip()
        if not local_ip:
            candidate_ips = []
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.connect(("8.8.8.8", 80))
                default_ip = s.getsockname()[0]
                s.close()
                candidate_ips.append(default_ip)
            except Exception:
                pass

            try:
                hostname = socket.gethostname()
                for addr_info in socket.getaddrinfo(hostname, None, socket.AF_INET):
                    ip = addr_info[4][0]
                    if ip not in candidate_ips:
                        candidate_ips.append(ip)
            except Exception:
                pass

            virtual_prefixes = ("172.16.", "172.17.", "172.18.", "192.168.56.", "127.", "169.254.")
            # Priority 1: 192.168.x.x (excluding virtualbox) or 10.x.x.x
            for ip in candidate_ips:
                if not any(ip.startswith(p) for p in virtual_prefixes):
                    if ip.startswith("192.168.") or ip.startswith("10."):
                        local_ip = ip
                        break

            # Priority 2: any other non-virtual IP
            if not local_ip:
                for ip in candidate_ips:
                    if not any(ip.startswith(p) for p in virtual_prefixes):
                        local_ip = ip
                        break

            # Fallback
            if not local_ip:
                local_ip = candidate_ips[0] if candidate_ips else "127.0.0.1"

        service_info = ServiceInfo(
            "_http._tcp.local.",
            "BackendServer._http._tcp.local.",
            addresses=[socket.inet_aton(local_ip)],
            port=config.APP_PORT,
            server="iot-server.local.",
        )
        zeroconf_inst = Zeroconf()
        zeroconf_inst.register_service(service_info)
        print(f"[mDNS] Registered local mDNS service: iot-server.local ({local_ip}:{config.APP_PORT})")
    except Exception as e:
        print(f"[mDNS] Could not register mDNS service: {e}")

    yield

    # Shutdown logic
    if zeroconf_inst:
        try:
            zeroconf_inst.unregister_all_services()
            zeroconf_inst.close()
        except Exception:
            pass
    mqtt_engine.stop()
    partition_task.cancel()
    predict_task.cancel()

# Initialize FastAPI

app = FastAPI(
    title="Local IoT Transport Security Backend",
    description="API Server chuẩn hóa cho hệ thống giám sát an ninh đạn dược vận chuyển (LoRa WAN & TinyML)",
    version="1.0.0",
    lifespan=lifespan
)

# --- WebSocket Endpoints ---
@app.websocket("/ws/telemetry")
async def websocket_telemetry_endpoint(websocket: WebSocket):
    await ws_telemetry_manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        ws_telemetry_manager.disconnect(websocket)
    except Exception:
        ws_telemetry_manager.disconnect(websocket)

@app.websocket("/ws/alerts")
async def websocket_alerts_endpoint(websocket: WebSocket):
    await ws_alerts_manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        ws_alerts_manager.disconnect(websocket)
    except Exception:
        ws_alerts_manager.disconnect(websocket)


@app.post("/api/routing/trigger_prediction")
async def trigger_prediction():
    # Chạy mô hình dự đoán thủ công thay vì đợi background task
    import time
    start_time = time.time()
    result = await asyncio.to_thread(run_spatiotemporal_model)
    end_time = time.time()
    print(f"[BENCHMARK] Spatiotemporal Prediction executed in {(end_time - start_time)*1000:.2f} ms")
    return result

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# DB Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ==========================================
# 4. CUSTOM ERROR HANDLERS (Standard JSON format)
# ==========================================
@app.exception_handler(HTTPException)
async def custom_http_exception_handler(request: Request, exc: HTTPException):
    detail = exc.detail
    if isinstance(detail, dict) and "code" in detail:
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": detail}
        )
    else:
        code_map = {
            404: "NOT_FOUND",
            400: "BAD_REQUEST",
            401: "UNAUTHORIZED",
            403: "FORBIDDEN",
            422: "VALIDATION_ERROR",
            500: "INTERNAL_SERVER_ERROR"
        }
        code = code_map.get(exc.status_code, "ERROR")
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": {
                    "code": code,
                    "message": str(detail),
                    "details": {}
                }
            }
        )

# Helper function to write system log in DB
def write_db_log(db: Session, source: str, level: str, code: str, message: str):
    try:
        crud.create_system_log(db, schemas.SystemLogCreate(
            source=source,
            level=level,
            code=code,
            message=message
        ))
    except Exception as e:
        print(f"[ERROR] Fail to write system log: {e}")

# ==========================================
# 5. API ENDPOINTS
# ==========================================

# --- Health check ---
@app.get("/health")
@app.get("/api/health")
async def health_check(db: Session = Depends(get_db)):
    try:
        # Quick DB check
        db.execute(models.Base.metadata.tables['users'].select().limit(1))
        db_status = "connected"
    except Exception:
        db_status = "disconnected"
        
    return {
        "status": "ok",
        "service": "local-iot-backend",
        "database": db_status
    }

# --- Developer Console ---
@app.get("/", response_class=HTMLResponse)
@app.get("/api/tester", response_class=HTMLResponse)
@app.get("/api/docs-ui", response_class=HTMLResponse)
async def get_api_tester():
    return HTMLResponse(content=TESTER_HTML)

# --- Places & Routing ---
@app.get("/places")
@app.get("/api/places")
async def get_places():
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
        return {
            "success": True,
            "count": len(places),
            "places": places,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi tải địa điểm: {str(e)}")

# Thêm bộ đệm (cache) cho các request tìm đường trùng lặp
route_cache = {}

@app.post("/get_route")
@app.post("/api/get_route")
async def get_route(req_data: dict):
    try:
        start_id = int(req_data.get("start"))
        goal_id = int(req_data.get("goal"))

        if start_id not in G:
            raise HTTPException(status_code=400, detail={
                "code": "INVALID_QUERY_PARAM",
                "message": f"Điểm bắt đầu (id={start_id}) không tồn tại trên bản đồ.",
                "details": {}
            })
        if goal_id not in G:
            raise HTTPException(status_code=400, detail={
                "code": "INVALID_QUERY_PARAM",
                "message": f"Điểm đích (id={goal_id}) không tồn tại trên bản đồ.",
                "details": {}
            })

        cache_key = (start_id, goal_id)
        if cache_key in route_cache and route_cache[cache_key]:
            # Hit cache
            path = route_cache[cache_key]
            import time
            start_time = time.time()
            end_time = time.time()
            print(f"[BENCHMARK] A* (Cached) Execution Time: {(end_time - start_time)*1000:.2f} ms")
        else:
            import time
            start_time = time.time()
            # Chạy thuật toán A* trong ThreadPool để không block Event Loop
            path = await asyncio.to_thread(louvain_astar, G, partition, start_id, goal_id)
            end_time = time.time()
            print(f"[BENCHMARK] A* Execution Time: {(end_time - start_time)*1000:.2f} ms")
            if path:
                route_cache[cache_key] = path

        if not path:
            return {"success": False, "error": "Không tìm thấy đường đi giữa 2 địa điểm."}

        route = []
        for node in path:
            route.append({
                "id": int(node),
                "place": G.nodes[node].get("place", f"Place {node}"),
                "lat": float(G.nodes[node]["lat"]),
                "lng": float(G.nodes[node]["lon"]),
            })
        return {"success": True, "path": route}
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/routing/update_risk")
async def api_update_risk(req_data: dict):
    global partition
    try:
        node_id = int(req_data.get("node_id"))
        risk_penalty = float(req_data.get("risk_penalty", 0.0))
    except:
        raise HTTPException(status_code=400, detail="Thiếu hoặc sai kiểu tham số node_id / risk_penalty")
        
    if node_id not in G:
        raise HTTPException(status_code=404, detail="Node không tồn tại trên bản đồ")
        
    # Cập nhật rủi ro cho node
    G.nodes[node_id]["risk_penalty"] = risk_penalty
    
    # Cập nhật trọng số của tất cả các cạnh nối với node này
    for neighbor in G.neighbors(node_id):
        r1 = G.nodes[node_id].get("risk_penalty", 0.0)
        r2 = G.nodes[neighbor].get("risk_penalty", 0.0)
        max_risk = max(r1, r2)
        
        dist = G[node_id][neighbor]["distance"]
        new_weight = dist * (1.0 + max_risk)
        G[node_id][neighbor]["weight"] = new_weight
        
    # Xoá cache định tuyến vì đồ thị đã thay đổi trọng số
    route_cache.clear()
        
    # Giai đoạn 2: Thuật toán phân cụm Louvain sẽ được chạy định kỳ ở background
    # thay vì chạy đồng bộ (blocking) ở đây.
    
    return {
        "success": True, 
        "message": f"Cập nhật rủi ro cho node {node_id} (penalty={risk_penalty}) thành công", 
        "new_communities_count": len(set(partition.values()))
    }

@app.post("/api/routing/trigger_prediction")
async def api_trigger_prediction():
    try:
        run_spatiotemporal_model()
        return {"success": True, "message": "Spatiotemporal prediction triggered successfully."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- Authentication ---
@app.post("/api/auth/login")
async def api_login(req: schemas.UserLogin, db: Session = Depends(get_db)):
    user = crud.get_user_by_email(db, req.email)
    if not user or user.password != req.password:
        write_db_log(db, "server", "WARN", "AUTH_FAIL", f"Failed login attempt for: {req.email}")
        raise HTTPException(status_code=401, detail={
            "code": "AUTH_FAIL",
            "message": "Email hoặc mật khẩu không chính xác.",
            "details": {}
        })
        
    token = create_jwt_token({"uid": user.uid, "email": user.email, "role": user.role})
    user_info = {
        "uid": user.uid,
        "email": user.email,
        "display_name": user.display_name,
        "role": user.role,
        "created_at": user.created_at
    }
    write_db_log(db, "server", "INFO", "AUTH_SUCCESS", f"User logged in: {req.email}")
    return {"success": True, "access_token": token, "token_type": "bearer", "user": user_info}

@app.post("/api/auth/register")
async def api_register(req: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = crud.get_user_by_email(db, req.email)
    if existing:
        raise HTTPException(status_code=400, detail={
            "code": "EMAIL_EXISTS",
            "message": "Email này đã được đăng ký trên hệ thống.",
            "details": {}
        })
        
    uid = "user_" + datetime.utcnow().strftime("%Y%m%d%H%M%S")
    new_user = crud.create_user(db, req, uid)
    
    user_info = {
        "uid": new_user.uid,
        "email": new_user.email,
        "display_name": new_user.display_name,
        "role": new_user.role,
        "created_at": new_user.created_at
    }
    write_db_log(db, "server", "INFO", "USER_REGISTER", f"New user registered: {req.email}")
    return {"success": True, "user": user_info}

# --- Nodes / Vehicles API ---
@app.get("/nodes")
@app.get("/api/vehicles")
async def api_get_nodes(db: Session = Depends(get_db)):
    nodes = crud.get_nodes(db)
    # Output matching list of vehicles dict format
    list_nodes = []
    for n in nodes:
        node_dict = {
            "id": n.id,
            "vehicle_id": n.node_id,
            "node_id": n.node_id,
            "vehicle_name": n.vehicle_name,
            "role": n.role,
            "status": n.status,
            "online": n.online,
            "battery_last": n.battery_last,
            "rssi_last": n.rssi_last,
            "snr_last": n.snr_last,
            "temperature": n.temperature,
            "humidity": n.humidity,
            "accel_magnitude": n.accel_magnitude,
            "light_level": n.light_level,
            "tamper": n.tamper,
            "anomaly_flag": n.anomaly_flag,
            "rf_anomaly_state": n.rf_anomaly_state,
            "knn_prediction": n.knn_prediction,
            "ml_prediction": n.ml_prediction,
            "ml_score": n.ml_score,
            "latitude": n.latitude,
            "longitude": n.longitude,
            "gateway_rssi": n.gateway_rssi,
            "gateway_snr": n.gateway_snr,
            "last_updated": n.last_updated
        }
        list_nodes.append(node_dict)
    return {"success": True, "vehicles": list_nodes, "nodes": list_nodes}

@app.get("/nodes/{node_id}")
@app.get("/api/vehicles/{node_id}")
async def api_get_node(node_id: str, db: Session = Depends(get_db)):
    n = crud.get_node_by_id(db, node_id)
    if not n:
        raise HTTPException(status_code=404, detail={
            "code": "NODE_NOT_FOUND",
            "message": f"Không tìm thấy node hoặc phương tiện có ID: {node_id}",
            "details": {}
        })
    node_dict = {
        "id": n.id,
        "vehicle_id": n.node_id,
        "node_id": n.node_id,
        "vehicle_name": n.vehicle_name,
        "role": n.role,
        "status": n.status,
        "online": n.online,
        "battery_last": n.battery_last,
        "rssi_last": n.rssi_last,
        "snr_last": n.snr_last,
        "temperature": n.temperature,
        "humidity": n.humidity,
        "accel_magnitude": n.accel_magnitude,
        "light_level": n.light_level,
        "tamper": n.tamper,
        "anomaly_flag": n.anomaly_flag,
        "rf_anomaly_state": n.rf_anomaly_state,
        "knn_prediction": n.knn_prediction,
        "ml_prediction": n.ml_prediction,
        "ml_score": n.ml_score,
        "latitude": n.latitude,
        "longitude": n.longitude,
        "gateway_rssi": n.gateway_rssi,
        "gateway_snr": n.gateway_snr,
        "last_updated": n.last_updated
    }
    return {"success": True, "vehicle": node_dict, "node": node_dict}

# --- Telemetry Ingestion ---
@app.post("/telemetry")
@app.post("/api/vehicles/{node_id}/telemetry")
@app.post("/api/nodes/{node_id}/telemetry")
async def api_update_telemetry(
    tel: schemas.TelemetryCreate, 
    node_id: Optional[str] = None, 
    db: Session = Depends(get_db)
):
    # Extract node_id from payload (prefer explicit vehicle_id/node_id over URL numeric id)
    target_node = crud.normalize_node_id(tel.node_id or node_id)
    if not target_node:
        raise HTTPException(status_code=400, detail={
            "code": "TELEMETRY_INVALID_PAYLOAD",
            "message": "Thiếu thông tin node_id/vehicle_id.",
            "details": {}
        })
        
    lat = float(tel.latitude)
    lon = float(tel.longitude)
    
    # Calculate route deviation using BallTree with dynamic threshold
    ml_prediction, ml_score = check_route_deviation(target_node, tel)
    
    # Update node current status
    node = crud.update_node_telemetry(db, target_node, tel, ml_prediction, ml_score)
    
    # Log telemetry log entry
    telemetry_log = crud.create_telemetry_log(db, target_node, tel, ml_prediction, ml_score)
    
    # Automatic warnings/alerts creation logic
    now = datetime.utcnow()
    
    # 1. Tamper Alert (NAP HOP BI MO)
    if node.tamper == 1:
        alert_payload = schemas.AlertCreate(
            node_id=target_node,
            alert_type="tamper",
            severity="critical",
            message=f"Hộp cảm biến trên xe {target_node} bị cạy mở trái phép!"
        )
        crud.create_alert(db, alert_payload)
        write_db_log(db, "security", "SECURITY", "TAMPER_ALERT", f"TAMPER ALERT on node {target_node}")
        
    # 2. Route Deviation Alert (LECH TUYEN)
    if ml_prediction == "OUT_OF_ROUTE":
        alert_payload = schemas.AlertCreate(
            node_id=target_node,
            alert_type="route_deviation",
            severity="high",
            message=f"Xe {target_node} lệch hành trình cho phép: {ml_score} mét!"
        )
        crud.create_alert(db, alert_payload)
        write_db_log(db, "security", "SECURITY", "DEVIATION_ALERT", f"ROUTE DEVIATION ALERT on node {target_node}: {ml_score}m")
        
    # 3. Low Battery Alert
    if node.battery_last < 20.0:
        alert_payload = schemas.AlertCreate(
            node_id=target_node,
            alert_type="low_battery",
            severity="medium",
            message=f"Pin của node {target_node} đã giảm xuống dưới 20% ({node.battery_last}%)."
        )
        crud.create_alert(db, alert_payload)
        write_db_log(db, "gateway", "WARN", "LOW_BATTERY", f"Low battery warning on node {target_node}: {node.battery_last}%")
        
    # 4. TinyML / Sensor Abnormal Alert
    if node.anomaly_flag == 1:
        alert_payload = schemas.AlertCreate(
            node_id=target_node,
            alert_type="sensor_abnormal",
            severity="medium",
            message=f"Phát hiện chỉ số cảm biến bất thường tại xe {target_node} (TinyML phát hiện Anomaly)."
        )
        crud.create_alert(db, alert_payload)
        write_db_log(db, "security", "WARN", "TINYML_ANOMALY", f"TinyML anomaly flag detected on node {target_node}")
        
    # 5. DQM & Predictive Analysis Pipeline
    dqm_res = dqm_engine.filter_telemetry(target_node, node.temperature, node.humidity, node.accel_magnitude)
    pred_res = prediction_engine.analyze_node_trend(target_node, dqm_res["temp_clean"], dqm_res["humidity_clean"])
    
    if pred_res["condensation_risk"]:
        alert_payload = schemas.AlertCreate(
            node_id=target_node,
            alert_type="dew_point_risk",
            severity="high",
            message=pred_res["warning_message"]
        )
        crud.create_alert(db, alert_payload)
        write_db_log(db, "environment", "WARN", "DEW_POINT_RISK", pred_res["warning_message"])

    # Convert node DB model to return format
    node_data = {
        "id": node.id,
        "vehicle_id": node.node_id,
        "node_id": node.node_id,
        "online": node.online,
        "temperature": dqm_res["temp_clean"],
        "temperature_raw": node.temperature,
        "humidity": dqm_res["humidity_clean"],
        "humidity_raw": node.humidity,
        "accel_magnitude": node.accel_magnitude,
        "light_level": node.light_level,
        "tamper": node.tamper,
        "anomaly_flag": node.anomaly_flag,
        "rf_anomaly_state": node.rf_anomaly_state,
        "knn_prediction": node.knn_prediction,
        "ml_prediction": node.ml_prediction,
        "ml_score": node.ml_score,
        "latitude": node.latitude,
        "longitude": node.longitude,
        "gateway_rssi": node.gateway_rssi,
        "gateway_snr": node.gateway_snr,
        "battery": node.battery_last,
        "battery_last": node.battery_last,
        "last_updated": node.last_updated,
        "dqm": dqm_res,
        "prediction": pred_res
    }
    
    LATEST_TELEMETRY_CACHE[target_node] = node_data
    try:
        asyncio.create_task(ws_telemetry_manager.broadcast({"type": "telemetry", "data": node_data}))
    except Exception:
        pass

    return {
        "success": True, 
        "status": "created", 
        "telemetry_id": telemetry_log.id,
        "vehicle": node_data,
        "node": node_data
    }

# --- Telemetry Logs History ---
@app.get("/telemetry/{node_id}")
@app.get("/api/vehicles/{node_id}/logs")
async def api_get_logs(
    node_id: str, 
    limit: int = Query(default=100, ge=1, le=1000), 
    db: Session = Depends(get_db)
):
    logs = crud.get_telemetry_logs(db, node_id, limit)
    list_logs = []
    for l in logs:
        list_logs.append({
            "timestamp": l.timestamp,
            "created_at": l.created_at.isoformat() + "Z",
            "seq": l.seq,
            "session_id": l.session_id,
            "vehicle_id": l.vehicle_id or l.node_id or node_id,
            "transport_id": l.vehicle_id or l.node_id or node_id,
            "temperature": l.temperature,
            "humidity": l.humidity,
            "accel_magnitude": l.accel_magnitude,
            "acceleration": l.acceleration,
            "speed": round(abs(l.acceleration or 0.0) * 3.6, 1) if l.acceleration else 14.5,
            "light_level": l.light_level,
            "light": l.light,
            "tamper": l.tamper,
            "anomaly_flag": l.anomaly_flag,
            "ml_prediction": l.ml_prediction,
            "prediction": l.ml_prediction or "NORMAL",
            "ml_score": l.ml_score,
            "distance": l.ml_score or 0.0,
            "latitude": l.latitude,
            "lat": l.latitude,
            "longitude": l.longitude,
            "lon": l.longitude,
            "gateway_rssi": l.gateway_rssi,
            "gateway_snr": l.gateway_snr,
            "battery": l.battery
        })
    return {"success": True, "logs": list_logs}

@app.get("/telemetry/latest")
async def api_get_latest_telemetry_all(
    limit: int = Query(default=20, ge=1, le=100), 
    db: Session = Depends(get_db)
):
    # Retrieve latest telemetry records from all nodes
    logs = db.query(models.Telemetry).order_by(desc(models.Telemetry.created_at)).limit(limit).all()
    list_logs = []
    for l in logs:
        list_logs.append({
            "id": l.id,
            "node_id": l.node_id,
            "seq": l.seq,
            "session_id": l.session_id,
            "temperature": l.temperature,
            "humidity": l.humidity,
            "acceleration": l.acceleration,
            "light": l.light,
            "latitude": l.latitude,
            "longitude": l.longitude,
            "battery": l.battery,
            "rssi": l.rssi,
            "snr": l.snr,
            "created_at": l.created_at.isoformat() + "Z"
        })
    return {"success": True, "telemetry": list_logs}

@app.get("/api/prediction/{node_id}")
async def api_get_node_prediction(node_id: str, db: Session = Depends(get_db)):
    node = crud.get_node_by_id(db, node_id)
    if not node:
        raise HTTPException(status_code=404, detail=f"Node {node_id} not found")
    dqm_res = dqm_engine.filter_telemetry(node_id, node.temperature or 25.0, node.humidity or 60.0, node.accel_magnitude or 0.0)
    pred_res = prediction_engine.analyze_node_trend(node_id, dqm_res["temp_clean"], dqm_res["humidity_clean"])
    return {"success": True, "node_id": node_id, "dqm": dqm_res, "prediction": pred_res}

@app.get("/api/qos/{node_id}")
async def api_get_node_qos(node_id: str, db: Session = Depends(get_db)):
    node = crud.get_node_by_id(db, node_id)
    if not node:
        raise HTTPException(status_code=404, detail=f"Node {node_id} not found")
    logs = crud.get_telemetry_logs(db, node_id, limit=50)
    packet_loss_pct = 0.0
    if len(logs) >= 2 and logs[0].seq is not None and logs[-1].seq is not None:
        expected_seqs = logs[0].seq - logs[-1].seq + 1
        received_cnt = len(logs)
        if expected_seqs > 0 and expected_seqs >= received_cnt:
            packet_loss_pct = round(((expected_seqs - received_cnt) / float(expected_seqs)) * 100.0, 1)
    return {
        "success": True,
        "node_id": node_id,
        "rssi": node.rssi_last,
        "snr": node.snr_last,
        "battery": node.battery_last,
        "packet_loss_rate_pct": packet_loss_pct,
        "last_updated": node.last_updated
    }

# --- Missions ---
@app.get("/api/missions")
async def api_get_missions(db: Session = Depends(get_db)):
    missions = crud.get_missions(db)
    list_missions = []
    for m in missions:
        m_dict = {
            "id": m.id,
            "mission_id": m.mission_id,
            "vehicle_id": m.vehicle_id,
            "driver_uid": m.driver_uid,
            "cargo_description": m.cargo_description,
            "origin": m.origin,
            "destination": m.destination,
            "status": m.status,
            "notes": m.notes,
            "created_at": m.created_at,
            "started_at": m.started_at,
            "completed_at": m.completed_at
        }
        # Deserialize route points
        if m.route_points_json:
            try:
                m_dict["route_points"] = json.loads(m.route_points_json)
            except:
                m_dict["route_points"] = []
        else:
            m_dict["route_points"] = []
        list_missions.append(m_dict)
        
    list_missions.sort(key=lambda item: item.get("created_at", ""), reverse=True)
    return {"success": True, "missions": list_missions}

@app.get("/api/missions/driver/{driver_uid}")
async def api_get_driver_missions(driver_uid: str, db: Session = Depends(get_db)):
    missions = crud.get_driver_missions(db, driver_uid)
    list_missions = []
    for m in missions:
        m_dict = {
            "id": m.id,
            "mission_id": m.mission_id,
            "vehicle_id": m.vehicle_id,
            "driver_uid": m.driver_uid,
            "cargo_description": m.cargo_description,
            "origin": m.origin,
            "destination": m.destination,
            "status": m.status,
            "notes": m.notes,
            "created_at": m.created_at,
            "started_at": m.started_at,
            "completed_at": m.completed_at
        }
        if m.route_points_json:
            try:
                m_dict["route_points"] = json.loads(m.route_points_json)
            except:
                m_dict["route_points"] = []
        else:
            m_dict["route_points"] = []
        list_missions.append(m_dict)
        
    list_missions.sort(key=lambda item: item.get("created_at", ""), reverse=True)
    return {"success": True, "missions": list_missions}

@app.post("/api/missions")
async def api_create_mission(mission: schemas.MissionCreate, db: Session = Depends(get_db)):
    mission_id = "mission_" + datetime.utcnow().strftime("%Y%m%d%H%M%S")
    route_points = [p.dict() for p in mission.route_points] if mission.route_points else []
    route_points_json = json.dumps(route_points) if route_points else None
    
    # Save mission DB entry
    db_mission = crud.create_mission(db, mission, mission_id, route_points_json)
    
    # Setup active route & BallTree for ML deviation check
    if route_points:
        crud.create_or_update_active_route(db, mission.vehicle_id, mission_id, route_points_json)
        build_route_tree(mission.vehicle_id, route_points)
        
    write_db_log(db, "server", "INFO", "MISSION_CREATE", f"Created new mission {mission_id} for vehicle {mission.vehicle_id}")
    
    res_dict = {
        "id": db_mission.id,
        "mission_id": db_mission.mission_id,
        "vehicle_id": db_mission.vehicle_id,
        "driver_uid": db_mission.driver_uid,
        "cargo_description": db_mission.cargo_description,
        "origin": db_mission.origin,
        "destination": db_mission.destination,
        "status": db_mission.status,
        "notes": db_mission.notes,
        "route_points": route_points,
        "created_at": db_mission.created_at
    }
    return {"success": True, "mission_id": mission_id, "mission": res_dict}

@app.patch("/api/missions/{mission_id}")
async def api_update_mission(
    mission_id: str, 
    status_update: schemas.MissionUpdateStatus, 
    db: Session = Depends(get_db)
):
    # Fetch mission
    mission = db.query(models.Mission).filter(models.Mission.mission_id == mission_id).first()
    if not mission:
        raise HTTPException(status_code=404, detail={
            "code": "MISSION_NOT_FOUND",
            "message": f"Không tìm thấy nhiệm vụ: {mission_id}",
            "details": {}
        })
        
    now_str = datetime.utcnow().isoformat() + "Z"
    started_at = None
    completed_at = None
    
    status_val = status_update.status
    if status_val == "inProgress":
        started_at = now_str
        write_db_log(db, "server", "INFO", "MISSION_START", f"Mission started: {mission_id}")
    elif status_val in ["completed", "cancelled"]:
        completed_at = now_str
        write_db_log(db, "server", "INFO", "MISSION_FINISH", f"Mission {status_val}: {mission_id}")
        
        # Clear active route & BallTree
        vid = mission.vehicle_id
        crud.delete_active_route(db, vid)
        route_trees.pop(vid, None)
        print(f"[ML] Cleared active route & BallTree for vehicle {vid}")
        
    crud.update_mission_status(db, mission_id, status_val, started_at, completed_at)
    
    # Return formatted mission
    m_dict = {
        "id": mission.id,
        "mission_id": mission.mission_id,
        "vehicle_id": mission.vehicle_id,
        "driver_uid": mission.driver_uid,
        "cargo_description": mission.cargo_description,
        "origin": mission.origin,
        "destination": mission.destination,
        "status": mission.status,
        "notes": mission.notes,
        "created_at": mission.created_at,
        "started_at": mission.started_at,
        "completed_at": mission.completed_at
    }
    if mission.route_points_json:
        try:
            m_dict["route_points"] = json.loads(mission.route_points_json)
        except:
            m_dict["route_points"] = []
    else:
        m_dict["route_points"] = []
        
    return {"success": True, "mission": m_dict}

# --- Active Routes ---
@app.get("/api/active_routes/{vehicle_id}")
async def api_get_active_route(vehicle_id: str, db: Session = Depends(get_db)):
    route_info = crud.get_active_route(db, vehicle_id)
    if not route_info:
        # Fallback thử vehicle_01 hoặc bản ghi active_route bất kỳ
        if vehicle_id in ["Transport-1", "vehicle_01", "Transport-01"]:
            route_info = db.query(models.ActiveRoute).filter(
                models.ActiveRoute.vehicle_id.in_(["vehicle_01", "Transport-1", "Transport-01"])
            ).first()
        if not route_info:
            route_info = db.query(models.ActiveRoute).first()
    if not route_info or not route_info.points_json:
        return {"success": True, "points": []}
    try:
        points = json.loads(route_info.points_json)
    except:
        points = []
    return {"success": True, "points": points}

# --- Alerts API ---
@app.get("/alerts")
@app.get("/api/alerts")
async def api_get_alerts(
    resolved: Optional[bool] = Query(default=None), 
    limit: int = Query(default=50, ge=1, le=200), 
    db: Session = Depends(get_db)
):
    alerts = crud.get_alerts(db, resolved, limit)
    list_alerts = []
    for a in alerts:
        list_alerts.append({
            "id": a.id,
            "node_id": a.node_id,
            "vehicle_id": a.node_id, # Compatibility
            "alert_type": a.alert_type,
            "severity": a.severity,
            "message": a.message,
            "resolved": a.resolved,
            "created_at": a.created_at.isoformat() + "Z",
            "resolved_at": a.resolved_at.isoformat() + "Z" if a.resolved_at else None
        })
    return {"success": True, "alerts": list_alerts}

@app.post("/alerts")
@app.post("/api/alerts")
async def api_create_alert(alert: schemas.AlertCreate, db: Session = Depends(get_db)):
    db_alert = crud.create_alert(db, alert)
    write_db_log(db, "server", "INFO", "ALERT_CREATE", f"Manual alert created for node {db_alert.node_id}")
    
    res_dict = {
        "id": db_alert.id,
        "node_id": db_alert.node_id,
        "vehicle_id": db_alert.node_id,
        "alert_type": db_alert.alert_type,
        "severity": db_alert.severity,
        "message": db_alert.message,
        "resolved": db_alert.resolved,
        "created_at": db_alert.created_at.isoformat() + "Z"
    }
    return {"success": True, "alert": res_dict}

@app.patch("/alerts/{alert_id}/resolve")
@app.patch("/api/alerts/{alert_id}/resolve")
async def api_resolve_alert(alert_id: int, db: Session = Depends(get_db)):
    alert = db.query(models.Alert).filter(models.Alert.id == alert_id).first()
    if not alert:
        raise HTTPException(status_code=404, detail={
            "code": "ALERT_NOT_FOUND",
            "message": f"Không tìm thấy cảnh báo với ID: {alert_id}",
            "details": {}
        })
        
    resolved_alert = crud.resolve_alert(db, alert_id)
    write_db_log(db, "server", "INFO", "ALERT_RESOLVE", f"Alert {alert_id} resolved")
    return {
        "status": "resolved", 
        "alert_id": alert_id,
        "alert": {
            "id": resolved_alert.id,
            "node_id": resolved_alert.node_id,
            "resolved": resolved_alert.resolved,
            "resolved_at": resolved_alert.resolved_at.isoformat() + "Z" if resolved_alert.resolved_at else None
        }
    }

# --- System Logs API ---
@app.get("/logs")
@app.get("/api/system_logs")
async def api_get_logs(
    level: Optional[str] = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500), 
    db: Session = Depends(get_db)
):
    logs = crud.get_system_logs(db, limit)
    # Filter by level in Python to keep CRUD simple
    if level:
        logs = [l for l in logs if l.level.upper() == level.upper()]
        
    list_logs = []
    for l in logs:
        list_logs.append({
            "id": l.id,
            "source": l.source,
            "level": l.level,
            "code": l.code,
            "message": l.message,
            "created_at": l.created_at.isoformat() + "Z"
        })
    return {"success": True, "logs": list_logs}

@app.post("/logs")
async def api_create_system_log(log: schemas.SystemLogCreate, db: Session = Depends(get_db)):
    db_log = crud.create_system_log(db, log)
    return {
        "success": True,
        "log": {
            "id": db_log.id,
            "source": db_log.source,
            "level": db_log.level,
            "code": db_log.code,
            "message": db_log.message,
            "created_at": db_log.created_at.isoformat() + "Z"
        }
    }

# --- CSV Report Export ---
@app.get("/api/reports/export/{node_id}")
async def export_report_csv(node_id: str, db: Session = Depends(get_db)):
    logs = db.query(models.Telemetry).filter(
        models.Telemetry.node_id == node_id
    ).order_by(
        desc(models.Telemetry.created_at)
    ).all()
    
    if not logs:
        raise HTTPException(status_code=404, detail={
            "code": "TELEMETRY_EMPTY",
            "message": f"Không có dữ liệu telemetry cho node {node_id}",
            "details": {}
        })
        
    output = io.StringIO()
    writer = csv.writer(output)
    
    # Write CSV headers
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
        
    write_db_log(db, "server", "INFO", "REPORT_EXPORT", f"Exported CSV report for node {node_id}")
    
    # Return streaming response
    output.seek(0)
    response_headers = {
        "Content-Disposition": f"attachment; filename=Bao_cao_an_ninh_{node_id}.csv"
    }
    return StreamingResponse(
        iter([output.getvalue()]), 
        media_type="text/csv", 
        headers=response_headers
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=config.APP_HOST, port=config.APP_PORT, reload=True)