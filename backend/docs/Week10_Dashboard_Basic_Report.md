# Báo Cáo Tuần 10: Xây Dựng Dashboard Điều Phối Cơ Bản (Week10_Dashboard_Basic_Report.md)

Báo cáo này tổng hợp kết quả tích hợp và chạy thử nghiệm giao diện **Dashboard điều phối** của ứng dụng Flutter di động (`ammo_monitor`) kết nối với **FastAPI Local Server** vừa nâng cấp ở Tuần 9.

---

## 🛠️ 1. Kiến Trúc và Công Nghệ Sử Dụng

Kiến trúc luồng dữ liệu điều phối thời gian thực:
```text
LoRa Node (Sensors/GPS) --> LoRa Gateway --> [gateway_reader.py / Sim]
                                                      ↓ (POST /telemetry)
                                                FastAPI Local Server (Port 5001)
                                                      ↓ (SQLite Database)
                                                REST APIs
                                                      ↓ (HTTP Polling / HTTP Streams)
                                                Flutter App Dashboard (ammo_monitor)
```

### Chi tiết các công nghệ chính:
1.  **Frontend (Dashboard)**: Viết bằng **Flutter (Dart)** chạy đa nền tảng (Mobile/Web Chrome).
2.  **Bản đồ GPS**: Tích hợp thư viện **Flutter Map** (sử dụng nguồn bản đồ mở OpenStreetMap) để hiển thị vị trí thực tế của các xe trên bản đồ.
3.  **Backend (API Server)**: Chạy **FastAPI** cổng `5001`.
4.  **Database**: **SQLite** lưu trữ dữ liệu thông số và cảnh báo.

---

## 🔄 2. Đặc Tả Tích Hợp API Lên Dashboard

Ứng dụng di động Flutter tự động gửi các yêu cầu kéo (polling) tới FastAPI Server thông qua class `FirestoreService` để cập nhật giao diện:

| Chức năng Dashboard | API Backend được gọi | Tần suất Polling | Trạng thái tích hợp |
| :--- | :--- | :--- | :--- |
| **Kiểm tra trạng thái server** | `GET /health` | Mỗi 4 giây | ✅ Đã tích hợp |
| **Đếm số xe và vẽ Node Cards** | `GET /api/vehicles` | Mỗi 2 giây | ✅ Đã tích hợp |
| **Vẽ vị trí GPS trên Bản đồ** | `GET /api/vehicles` | Mỗi 2 giây | ✅ Đã tích hợp |
| **Bảng dữ liệu Telemetry** | `GET /api/vehicles/{id}/logs` | Mỗi 5 giây | ✅ Đã tích hợp |
| **Danh sách cảnh báo (Alerts)** | `GET /api/alerts` | Mỗi 4 giây | ✅ Đã tích hợp |
| **Nhật ký hệ thống (Logs)** | `GET /api/system_logs` | Mỗi 4 giây | ✅ Đã tích hợp |
| **Xuất báo cáo an ninh** | `GET /api/reports/export/{id}`| Trực tiếp qua Click | ✅ Đã tích hợp |

---

## 🧪 3. Kết Quả Kiểm Thử Hệ Thống (Test Report)

Để kiểm thử, chúng ta chạy đồng thời:
1.  FastAPI Server ở cổng `5001`.
2.  Script giả lập `gateway_reader.py` sinh dữ liệu chạy liên tục.
3.  Ứng dụng di động Flutter trên trình duyệt Chrome.

Kết quả ghi nhận như sau:

| Kịch bản kiểm thử (Test Case) | Kết quả mong đợi trên Dashboard App | Kết quả thực tế | Trạng thái |
| :--- | :--- | :--- | :--- |
| **Khởi chạy ứng dụng** | Status bar hiển thị: `Server: ok` (màu xanh). | Giao diện hiển thị Server online, database connected. | **PASSED** |
| **Nhận diện thiết bị** | Hiển thị `Tổng thiết bị: 1`, `Đang hoạt động: 1`. | Node card của `vehicle_01` xuất hiện trên UI. | **PASSED** |
| **Nhận dữ liệu cảm biến** | Hiển thị nhiệt độ, độ ẩm, gia tốc rung lắc trên card và bảng. | Dữ liệu cập nhật realtime mỗi khi có telemetry mới. | **PASSED** |
| **Hiển thị sóng LoRa** | Hiển thị chỉ số RSSI và SNR gần nhất. | RSSI (~ -48 dBm) và SNR (~ 11 dB) hiển thị rõ trên Node Card. | **PASSED** |
| **Hiển thị bản đồ GPS** | Marker của `vehicle_01` xuất hiện trên bản đồ Leaflet. | Xe hiển thị đúng vị trí GPS khu vực Bách Khoa TP.HCM. | **PASSED** |
| **Cảnh báo Cạy nắp hộp (Tamper)**| Thẻ xe chuyển sang màu đỏ, xuất hiện dòng cảnh báo nguy hiểm. | App hiển thị cảnh báo đỏ chói: *"Hộp cảm biến trên xe vehicle_01 bị cạy mở..."* | **PASSED** |
| **Tự động chuyển Offline** | Tắt script giả lập > 30s, Node Card chuyển sang màu xám. | Node Card của `vehicle_01` cập nhật trạng thái `offline`. | **PASSED** |

---

## 📸 4. Minh Chứng Vận Hành Hệ Thống

1.  **Swagger UI (API Verification)**: Hoạt động ổn định tại `http://localhost:5001/docs`.
2.  **Console Logs (FastAPI)**:
    ```text
    INFO:     127.0.0.1:62300 - "GET /health HTTP/1.1" 200 OK
    INFO:     127.0.0.1:62302 - "GET /api/vehicles HTTP/1.1" 200 OK
    INFO:     127.0.0.1:62305 - "GET /api/alerts?limit=5 HTTP/1.1" 200 OK
    ```
3.  **Giao diện Dashboard Flutter**: Hiển thị đầy đủ thông tin hệ thống, biểu đồ tần suất cảnh báo và vị trí GPS di động.

---

## 🎯 5. Kế Hoạch Tuần 11 (Tiếp Theo)
*   Nâng cấp giao diện Dashboard với các bố cục chi tiết hơn.
*   Xây dựng chức năng Overview tập trung cho đội xe nhiều Node.
*   Tích hợp bộ lọc dữ liệu (Filter) và xem lịch sử nâng cao.
*   Phân quyền người dùng (Role-based access control - Admin vs Driver) trên Local Server.
