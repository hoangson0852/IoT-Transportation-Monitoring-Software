# Tài Liệu API Local Backend (API_Documentation.md)

Tài liệu này mô tả chi tiết các endpoint HTTP REST của FastAPI Local Server phục vụ cho việc giám sát hành trình đạn dược.

## 📌 1. Cấu hình Chung (General)
* **Base URL**: `http://localhost:5001` (Hoặc địa chỉ IP local của máy chạy backend)
* **Format Dữ Liệu**: JSON (UTF-8)

---

## 🔍 2. Danh Sách Endpoint

### 2.1. Health Check
* **Endpoint**: `GET /health` hoặc `GET /api/health`
* **Mô tả**: Kiểm tra trạng thái hoạt động của Server và Database SQLite.
* **Response Mẫu (200 OK)**:
  ```json
  {
    "status": "ok",
    "service": "local-iot-backend",
    "database": "connected"
  }
  ```

---

### 2.2. Nhóm Nodes / Vehicles (Phương Tiện Giám Sát)

#### A. Lấy danh sách các Node
* **Endpoint**: `GET /nodes` hoặc `GET /api/vehicles`
* **Mô tả**: Lấy danh sách toàn bộ các xe/node cảm biến, bao gồm các chỉ số telemetry mới nhất và trạng thái kết nối.
* **Response Mẫu (200 OK)**:
  ```json
  {
    "success": true,
    "nodes": [
      {
        "id": 1,
        "node_id": "vehicle_01",
        "vehicle_id": "vehicle_01",
        "vehicle_name": "Vehicle 01",
        "role": "tx",
        "status": "online",
        "online": true,
        "battery_last": 87.5,
        "rssi_last": -45,
        "snr_last": 12,
        "temperature": 28.5,
        "humidity": 65.2,
        "accel_magnitude": 0.05,
        "light_level": 350,
        "tamper": 0,
        "anomaly_flag": 0,
        "rf_anomaly_state": "NORMAL",
        "knn_prediction": "NORMAL",
        "ml_prediction": "NORMAL",
        "ml_score": 0.0,
        "latitude": 10.772,
        "longitude": 106.657,
        "gateway_rssi": -45,
        "gateway_snr": 12,
        "last_updated": "2026-06-25T13:30:00Z"
      }
    ]
  }
  ```

#### B. Lấy thông tin chi tiết một Node
* **Endpoint**: `GET /nodes/{node_id}` hoặc `GET /api/vehicles/{vehicle_id}`
* **Mô tả**: Lấy chi tiết thông tin và trạng thái hiện tại của một node/xe dựa theo ID.
* **Response Mẫu (200 OK)**:
  ```json
  {
    "success": true,
    "node": {
      "id": 1,
      "node_id": "vehicle_01",
      ...
    }
  }
  ```

---

### 2.3. Nhóm Telemetry (Dữ Liệu Cảm Biến)

#### A. Nhập Dữ Liệu Cảm Biến (Gateway đẩy lên)
* **Endpoint**: `POST /telemetry` hoặc `POST /api/vehicles/{node_id}/telemetry`
* **Mô tả**: Dùng để Gateway (hoặc bridge script) gửi dữ liệu cảm biến nhận được từ Node LoRa vào backend. Backend sẽ tự động chạy thuật toán ML Supervisor (BallTree) kiểm tra lệch tuyến, cập nhật trạng thái node, lưu telemetry log, và kích hoạt cảnh báo tự động nếu phát hiện bất thường.
* **Body Format (JSON)**:
  ```json
  {
    "node_id": "vehicle_01",
    "seq": 125,
    "session_id": 9991,
    "temperature": 30.5,
    "humidity": 70.2,
    "acceleration": 0.12,
    "light": 300.0,
    "latitude": 10.772,
    "longitude": 106.657,
    "battery": 87.0,
    "rssi": -45,
    "snr": 12,
    "alert_flags": 0,
    "tamper": 0,
    "anomaly_flag": 0
  }
  ```
* **Response Mẫu (200 OK)**:
  ```json
  {
    "success": true,
    "status": "created",
    "telemetry_id": 102,
    "node": {
      "node_id": "vehicle_01",
      "status": "online",
      "ml_prediction": "NORMAL",
      "ml_score": 5.4,
      ...
    }
  }
  ```

#### B. Lấy Lịch Sử Telemetry của một Node
* **Endpoint**: `GET /telemetry/{node_id}?limit=100` hoặc `GET /api/vehicles/{vehicle_id}/logs?limit=100`
* **Mô tả**: Truy xuất lịch sử các bản ghi telemetry của một node cụ thể (mặc định giới hạn 100 bản ghi mới nhất, tối đa 1000).
* **Response Mẫu (200 OK)**:
  ```json
  {
    "success": true,
    "logs": [
      {
        "timestamp": "2026-06-25T13:30:00Z",
        "seq": 125,
        "temperature": 30.5,
        "humidity": 70.2,
        ...
      }
    ]
  }
  ```

#### C. Lấy Danh Sách Telemetry Mới Nhất (Tất cả các Node)
* **Endpoint**: `GET /telemetry/latest?limit=20`
* **Response Mẫu (200 OK)**:
  ```json
  {
    "success": true,
    "telemetry": [
      {
        "id": 102,
        "node_id": "vehicle_01",
        "seq": 125,
        "temperature": 30.5,
        ...
      }
    ]
  }
  ```

---

### 2.4. Nhóm Cảnh Báo (Alerts)

#### A. Lấy Danh Sách Cảnh Báo
* **Endpoint**: `GET /alerts?resolved=false` hoặc `GET /api/alerts?resolved=false`
* **Tham số query (Optional)**: `resolved` (true/false) để lọc cảnh báo đã xử lý hay chưa.
* **Response Mẫu (200 OK)**:
  ```json
  {
    "success": true,
    "alerts": [
      {
        "id": 5,
        "node_id": "vehicle_01",
        "vehicle_id": "vehicle_01",
        "alert_type": "tamper",
        "severity": "critical",
        "message": "Hộp cảm biến trên xe vehicle_01 bị cạy mở trái phép!",
        "resolved": false,
        "created_at": "2026-06-25T13:25:00Z",
        "resolved_at": null
      }
    ]
  }
  ```

#### B. Tạo Cảnh Báo Thủ Công
* **Endpoint**: `POST /alerts` hoặc `POST /api/alerts`
* **Body Format (JSON)**:
  ```json
  {
    "node_id": "vehicle_01",
    "alert_type": "security",
    "severity": "high",
    "message": "Nghi ngờ xe bị tấn công replay hoặc nhiễu sóng LoRa tầm xa."
  }
  ```

#### C. Xác Nhận Xử Lý Cảnh Báo (Resolve Alert)
* **Endpoint**: `PATCH /alerts/{alert_id}/resolve` hoặc `PATCH /api/alerts/{alert_id}/resolve`
* **Response Mẫu (200 OK)**:
  ```json
  {
    "status": "resolved",
    "alert_id": 5,
    "alert": {
      "id": 5,
      "node_id": "vehicle_01",
      "resolved": true,
      "resolved_at": "2026-06-25T13:40:00Z"
    }
  }
  ```

---

### 2.5. Nhóm Hệ Thống Logs (System Logs)
* **Endpoint**: `GET /logs?level=ERROR` hoặc `GET /api/system_logs`
* **Response Mẫu (200 OK)**:
  ```json
  {
    "success": true,
    "logs": [
      {
        "id": 41,
        "source": "security",
        "level": "SECURITY",
        "code": "TAMPER_ALERT",
        "message": "TAMPER ALERT on node vehicle_01",
        "created_at": "2026-06-25T13:25:00Z"
      }
    ]
  }
  ```

---

### 2.6. Nhóm Định Tuyến Nhiệm Vụ (Missions)

#### A. Tạo Nhiệm Vụ Mới
* **Endpoint**: `POST /api/missions`
* **Mô tả**: Tạo một nhiệm vụ vận chuyển đạn dược, kèm danh sách tọa độ lộ trình để xây dựng `BallTree` cho ML Supervisor.
* **Body Mẫu (JSON)**:
  ```json
  {
    "vehicle_id": "vehicle_01",
    "driver_uid": "user_123",
    "cargo_description": "Vận chuyển đạn dược đợt 1",
    "origin": "Kho A",
    "destination": "Kho B",
    "route_points": [
      {"lat": 10.772, "lng": 106.657},
      {"lat": 10.775, "lng": 106.660}
    ]
  }
  ```

#### B. Cập Nhật Trạng Thái Nhiệm Vụ
* **Endpoint**: `PATCH /api/missions/{mission_id}`
* **Body Mẫu (JSON)**:
  ```json
  {
    "status": "inProgress" 
  }
  ```

---

### 2.7. Xuất Báo Cáo Bảo Mật (CSV Export)
* **Endpoint**: `GET /api/reports/export/{node_id}`
* **Mô tả**: Xuất file CSV chứa toàn bộ lịch sử cảm biến và trạng thái an ninh của node để tải xuống.
* **Response**: Trả về luồng tải file `.csv` trực tiếp qua header `Content-Disposition`.
