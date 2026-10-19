# Tài Liệu Cấu Trúc Cơ Sở Dữ Liệu (Database_Schema.md)

Hệ thống Local Backend sử dụng cơ sở dữ liệu **SQLite** (`iot_transport.db` lưu trong thư mục `app_data/`) để quản lý thông tin các xe, dữ liệu cảm biến (telemetry), cảnh báo an ninh, nhật ký vận hành và lộ trình di chuyển.

Sử Dụng thư viện ORM **SQLAlchemy** để ánh xạ cơ sở dữ liệu.

---

## 🗺️ Sơ đồ Quan hệ Bảng (Relational Schema)

```mermaid
erDiagram
    users {
        int id PK
        string uid UK
        string email UK
        string password
        string display_name
        string role
        string created_at
    }
    nodes {
        int id PK
        string node_id UK "Mã node cảm biến"
        string vehicle_id UK "Mã xe (Legacy)"
        string vehicle_name
        string role
        string status "online/offline/warning"
        datetime last_seen
        float battery_last
        int rssi_last
        int snr_last
        boolean online
        float temperature
        float humidity
        float accel_magnitude
        int light_level
        int tamper
        int anomaly_flag
        string rf_anomaly_state
        string knn_prediction
        string ml_prediction
        float ml_score
        float latitude
        float longitude
        datetime created_at
        datetime updated_at
    }
    telemetry {
        int id PK
        string node_id FK "Liên kết với nodes.node_id"
        string vehicle_id FK
        int seq
        int session_id
        float temperature
        float humidity
        float acceleration
        float accel_magnitude
        float light
        int light_level
        float latitude
        float longitude
        float battery
        int rssi
        int gateway_rssi
        int snr
        int gateway_snr
        int alert_flags
        int tamper
        int anomaly_flag
        string ml_prediction
        float ml_score
        datetime created_at
        string timestamp
    }
    alerts {
        int id PK
        string node_id FK
        string vehicle_id FK
        string alert_type "tamper/deviation/battery/etc"
        string severity "low/medium/high/critical"
        string message
        boolean resolved
        datetime created_at
        datetime resolved_at
    }
    missions {
        int id PK
        string mission_id UK
        string vehicle_id FK
        string driver_uid FK
        string cargo_description
        string origin
        string destination
        string status "pending/inProgress/completed/cancelled"
        string notes
        string route_points_json "Danh sách tọa độ định tuyến dạng JSON"
        string created_at
        string started_at
        string completed_at
    }
    active_routes {
        int id PK
        string vehicle_id UK FK
        string mission_id FK
        string points_json
        string created_at
    }
    system_logs {
        int id PK
        string source "backend/gateway/radio/security"
        string level "INFO/WARN/ERROR/SECURITY"
        string code "e.g. AUTH_FAIL"
        string message
        datetime created_at
    }

    nodes ||--o{ telemetry : "gửi"
    nodes ||--o{ alerts : "phát sinh"
    nodes ||--o| active_routes : "có"
    users ||--o{ missions : "nhận nhiệm vụ"
    missions ||--o| active_routes : "dùng tuyến đường"
```

---

## 📋 Chi Tiết Các Bảng Dữ Liệu

### 1. Bảng `users` (Quản lý tài khoản)
Lưu trữ tài khoản người dùng đăng nhập hệ thống (Lái xe, Quản trị viên).

| Field | Type | Constraint | Description |
| :--- | :--- | :--- | :--- |
| `id` | Integer | PK, Auto Increment | ID hệ thống tự sinh. |
| `uid` | String | Unique, Index, Not Null | ID chuỗi ngẫu nhiên (ví dụ `user_2026...`). |
| `email` | String | Unique, Index, Not Null | Địa chỉ email đăng nhập. |
| `password` | String | Not Null | Mật khẩu tài khoản (dạng thô hoặc hash). |
| `display_name` | String | Nullable | Tên hiển thị người dùng. |
| `role` | String | Default: `"driver"` | Vai trò: `"admin"` hoặc `"driver"`. |
| `created_at` | String | Nullable | Thời gian tạo tài khoản (ISO String). |

---

### 2. Bảng `nodes` (Danh sách thiết bị / Xe giám sát)
Lưu trữ thông tin chi tiết từng xe/node, cấu hình phần cứng LoRa, và trạng thái telemetry mới nhất.

| Field | Type | Constraint | Description |
| :--- | :--- | :--- | :--- |
| `id` | Integer | PK, Auto Increment | ID hệ thống tự sinh. |
| `node_id` | String | Unique, Index, Not Null | ID định danh của node cảm biến (LoRa Node). |
| `vehicle_id` | String | Unique, Index, Not Null | Đồng bộ với `node_id` phục vụ tương thích ngược. |
| `vehicle_name` | String | Nullable | Tên thân thiện của phương tiện. |
| `role` | String | Default: `"tx"` | Vai trò node: `"tx"` (phát), `"gateway"`, `"relay"`. |
| `status` | String | Default: `"online"` | Trạng thái: `"online"`, `"offline"`, `"warning"`. |
| `last_seen` | DateTime | Default: `now()` | Lần cuối nhận dữ liệu thành công. |
| `battery_last` | Float | Default: `100.0` | % pin cập nhật gần nhất. |
| `rssi_last` | Integer | Default: `0` | Cường độ sóng RSSI gần nhất (dBm). |
| `snr_last` | Integer | Default: `0` | Chỉ số tỷ lệ tín hiệu/nhiễu SNR gần nhất (dB). |
| `online` | Boolean | Default: `True` | Phục vụ tương thích ngược trạng thái kết nối. |
| `temperature` | Float | Default: `0.0` | Nhiệt độ khoang chứa hàng gần nhất (°C). |
| `humidity` | Float | Default: `0.0` | Độ ẩm khoang chứa gần nhất (%). |
| `accel_magnitude` | Float | Default: `0.0` | Gia tốc rung lắc gần nhất (g). |
| `light_level` | Integer | Default: `0` | Cường độ ánh sáng gần nhất (ADC). |
| `tamper` | Integer | Default: `0` | Cờ tháo cạy: `1` (bị cạy nap), `0` (an toàn). |
| `anomaly_flag` | Integer | Default: `0` | Cờ bất thường TinyML: `1` (abnormal), `0` (normal). |
| `rf_anomaly_state` | String | Default: `"NORMAL"` | Trạng thái an ninh truyền thông không dây. |
| `knn_prediction` | String | Default: `"NORMAL"` | Dự đoán của thuật toán KNN. |
| `ml_prediction` | String | Default: `"NORMAL"` | Kết quả kiểm tra lệch tuyến: `"NORMAL"` / `"OUT_OF_ROUTE"`. |
| `ml_score` | Float | Default: `0.0` | Khoảng cách lệch lộ trình thực tế tính bằng mét. |
| `latitude` | Float | Default: `0.0` | Vĩ độ hiện tại. |
| `longitude` | Float | Default: `0.0` | Kinh độ hiện tại. |
| `created_at` | DateTime | Default: `now()` | Thời điểm khởi tạo node. |
| `updated_at` | DateTime | Default: `now()` | Lần cuối cập nhật thông tin trong DB. |

---

### 3. Bảng `telemetry` (Nhật ký dữ liệu cảm biến)
Lưu trữ chuỗi dữ liệu lịch sử cảm biến theo thời gian của tất cả các xe gửi về.

| Field | Type | Constraint | Description |
| :--- | :--- | :--- | :--- |
| `id` | Integer | PK, Auto Increment | ID hệ thống tự sinh. |
| `node_id` | String | Index, Not Null | Liên kết với `nodes.node_id`. |
| `vehicle_id` | String | Index, Not Null | Bản sao tương thích của `node_id`. |
| `seq` | Integer | Default: `0` | Số thứ tự gói tin gửi đi từ Node (Sequence Number). |
| `session_id` | Integer | Default: `0` | ID phiên truyền thông hiện tại của Node. |
| `temperature` | Float | Default: `0.0` | Giá trị nhiệt độ đo được. |
| `humidity` | Float | Default: `0.0` | Giá trị độ ẩm đo được. |
| `acceleration` | Float | Default: `0.0` | Giá trị gia tốc đo được (g). |
| `accel_magnitude` | Float | Default: `0.0` | Tương thích ngược của `acceleration`. |
| `light` | Float | Default: `0.0` | Cường độ ánh sáng. |
| `light_level` | Integer | Default: `0` | Tương thích ngược cường độ ánh sáng. |
| `latitude` | Float | Default: `0.0` | Tọa độ Vĩ độ GPS. |
| `longitude` | Float | Default: `0.0` | Tọa độ Kinh độ GPS. |
| `battery` | Float | Default: `100.0` | Điện áp pin (%). |
| `rssi` | Integer | Default: `0` | Chỉ số RSSI sóng LoRa tại trạm thu. |
| `gateway_rssi` | Integer | Default: `0` | Tương thích ngược RSSI. |
| `snr` | Integer | Default: `0` | Chỉ số SNR sóng LoRa tại trạm thu. |
| `gateway_snr` | Integer | Default: `0` | Tương thích ngược SNR. |
| `alert_flags` | Integer | Default: `0` | Cờ cảnh báo của thiết bị phần cứng gửi kèm. |
| `tamper` | Integer | Default: `0` | Cờ tháo cạy nap hộp. |
| `anomaly_flag` | Integer | Default: `0` | Trạng thái bất thường TinyML. |
| `ml_prediction` | String | Default: `"NORMAL"` | Đánh giá lệch tuyến: `"NORMAL"` / `"OUT_OF_ROUTE"`. |
| `ml_score` | Float | Default: `0.0` | Khoảng cách lệch lộ trình thực tế tính bằng mét. |
| `created_at` | DateTime | Default: `now()` | Thời điểm Server ghi nhận bản ghi. |
| `timestamp` | String | Not Null | Thời gian gửi gói tin dạng chuỗi (tương thích ngược). |

---

### 4. Bảng `alerts` (Nhật ký cảnh báo an ninh)
Lưu trữ và phân loại các cảnh báo phát sinh trong quá trình vận chuyển.

| Field | Type | Constraint | Description |
| :--- | :--- | :--- | :--- |
| `id` | Integer | PK, Auto Increment | ID cảnh báo tự sinh. |
| `node_id` | String | Index, Not Null | Node phát sinh cảnh báo. |
| `vehicle_id` | String | Index, Not Null | Tương thích ngược. |
| `alert_type` | String | Not Null | Loại: `"tamper"`, `"route_deviation"`, `"low_battery"`, `"sensor_abnormal"`. |
| `severity` | String | Default: `"medium"` | Độ nghiêm trọng: `"low"`, `"medium"`, `"high"`, `"critical"`. |
| `message` | String | Not Null | Chi tiết nội dung cảnh báo để hiển thị. |
| `resolved` | Boolean | Default: `False` | Trạng thái: `True` (đã xử lý), `False` (chưa xử lý). |
| `created_at` | DateTime | Default: `now()` | Thời gian phát hiện cảnh báo. |
| `resolved_at` | DateTime | Nullable | Thời gian xác nhận xử lý cảnh báo. |

---

### 5. Bảng `system_logs` (Nhật ký hoạt động hệ thống)
Lưu trữ log debug, log an ninh truyền thông của backend hoặc trạm thu Gateway gửi về.

| Field | Type | Constraint | Description |
| :--- | :--- | :--- | :--- |
| `id` | Integer | PK, Auto Increment | ID dòng log tự sinh. |
| `source` | String | Not Null | Nguồn log: `"backend"`, `"gateway"`, `"radio"`, `"security"`. |
| `level` | String | Default: `"INFO"` | Mức độ log: `"INFO"`, `"WARN"`, `"ERROR"`, `"SECURITY"`. |
| `code` | String | Nullable | Mã lỗi kỹ thuật phục vụ tra cứu lỗi nhanh (e.g. `AUTH_FAIL`). |
| `message` | String | Not Null | Nội dung chi tiết thông điệp log. |
| `created_at` | DateTime | Default: `now()` | Thời điểm ghi nhận dòng log. |
