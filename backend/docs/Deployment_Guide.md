# Hướng Dẫn Triển Khai Backend (Deployment_Guide.md)

Tài liệu này hướng dẫn chi tiết cách thiết lập, cấu hình và khởi động FastAPI Local Backend phục vụ hệ thống giám sát vận chuyển đạn dược.

---

## 💻 1. Yêu Cầu Hệ Thống & Môi Trường
1. **Hệ điều hành**: Windows 10/11 hoặc Linux (Ubuntu 20.04+)
2. **Python**: Phiên bản **3.10** hoặc **3.11** (Đã có sẵn trên máy của bạn).
3. **Thư viện chính**:
   - FastAPI (Framework web)
   - Uvicorn (ASGI server chạy FastAPI)
   - SQLAlchemy (Thư viện ORM tương tác SQLite)
   - Scikit-Learn (Phục vụ thuật toán giám sát BallTree)
   - Pandas, NetworkX, Python-Louvain (Phục vụ thuật toán định tuyến)

---

## 🛠️ 2. Các Bước Cài Đặt Chi Tiết

### Bước 2.1. Chuẩn bị Thư mục và Virtual Environment
Do dự án của bạn đã cấu hình sẵn môi trường Python ảo (venv) tại thư mục `Software/.venv/`, chúng ta có thể sử dụng trực tiếp venv này để chạy.

Nếu bạn cần cài đặt mới hoặc chạy lại trên môi trường sạch, thực hiện các lệnh sau:
1. Mở cửa sổ Terminal (PowerShell hoặc Command Prompt).
2. Di chuyển đến thư mục backend của bạn:
   ```bash
   cd MobileApp/backend
   ```
3. Tạo môi trường ảo mới nếu cần:
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # Trên Linux/macOS
   # hoặc
   .venv\Scripts\activate     # Trên Windows
   ```

### Bước 2.2. Cài đặt các thư viện phụ thuộc (Dependencies)
Cài đặt toàn bộ các thư viện được liệt kê trong `requirements.txt` bằng lệnh:
```bash
pip install -r requirements.txt
```

---

## ⚙️ 3. Cấu hình Môi Trường (`.env`)
Tạo hoặc chỉnh sửa file `.env` nằm tại thư mục `MobileApp/backend/.env` với các nội dung sau:
```ini
APP_HOST=0.0.0.0
APP_PORT=5001
SERIAL_PORT=COM3
SERIAL_BAUD=115200
ML_THRESHOLD_METERS=50.0
```
* **APP_PORT**: Mặc định đặt là `5001` để khớp với cấu hình gọi API hiện có của ứng dụng di động Flutter (không cần sửa code Flutter).
* **SERIAL_PORT**: Cổng kết nối USB của thiết bị Gateway thu nhận sóng LoRa (Ví dụ: `COM3` trên Windows hoặc `/dev/ttyUSB0` trên Linux).
* **ML_THRESHOLD_METERS**: Khoảng cách giới hạn lệch lộ trình (mét), vượt quá khoảng cách này xe sẽ bị báo cảnh báo lệch tuyến `OUT_OF_ROUTE`.

---

## 🚀 4. Khởi Chạy Server

### Cách 4.1: Sử dụng Script chạy nhanh (Khuyến nghị)
* **Trên Windows**: 
  Click đúp vào file [run_server.bat](file:///c:/Users/Lenovo/Old_computer/University/Year_4/DATN_253/MobileApp/backend/run_server.bat). Script này sẽ tự động kích hoạt venv và khởi chạy server trên cổng `5001`.
* **Trên Linux/macOS**:
  Cấp quyền thực thi và chạy script:
  ```bash
  chmod +x run_server.sh
  ./run_server.sh
  ```

### Cách 4.2: Chạy thủ công qua dòng lệnh (Terminal)
Kích hoạt venv và chạy lệnh:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 5001
```

---

## 🧪 5. Kiểm tra Hoạt Động (Verification)
1. **Kiểm tra Swagger UI**: 
   Mở trình duyệt web và truy cập: [http://localhost:5001/docs](http://localhost:5001/docs). Bạn sẽ thấy giao diện Swagger UI tự động hiển thị đầy đủ các REST API và cho phép gọi thử trực tiếp.
2. **Kiểm tra Health Endpoint**:
   Truy cập [http://localhost:5001/health](http://localhost:5001/health). Kết quả mong đợi:
   ```json
   {
     "status": "ok",
     "service": "local-iot-backend",
     "database": "connected"
   }
   ```
3. **Kiểm tra Developer Tester**:
   Truy cập [http://localhost:5001/api/tester](http://localhost:5001/api/tester) để mở bảng điều khiển giả lập gửi nhận dữ liệu telemetry mà không cần phần cứng.
