# MobileApp - Hệ thống giám sát vận tải

Thư mục này chứa toàn bộ mã nguồn của hệ thống phần mềm giám sát, bao gồm ứng dụng di động (Flutter) và máy chủ xử lý dữ liệu (FastAPI).

## 1. Cấu trúc thư mục

```text
MobileApp/
├── ammo_monitor/                      # Mã nguồn ứng dụng di động (Flutter App)
│   ├── android/, ios/, web/...        # Cấu hình cho các nền tảng tương ứng
│   ├── lib/                           # Chứa mã nguồn Dart chính
│   │   ├── core/                      # Các thành phần cốt lõi, constants, utils
│   │   ├── models/                    # Lớp mô hình dữ liệu (Data models)
│   │   ├── providers/                 # Quản lý trạng thái (State management)
│   │   ├── screens/                   # Giao diện người dùng (UI Screens)
│   │   └── services/                  # Xử lý logic nghiệp vụ, gọi API, MQTT, Firebase
│   ├── pubspec.yaml                   # Khai báo cấu hình và thư viện Flutter
│   └── README.md                      # Hướng dẫn chi tiết cho Flutter app
│
└── backend/                           # Mã nguồn máy chủ backend (Python FastAPI)
    ├── main.py                        # Entry-point chính khởi chạy FastAPI server
    ├── server.py                      # Logic cấu hình server
    ├── models.py, schemas.py          # Định nghĩa cấu trúc database và Pydantic schemas
    ├── database.py                    # Cấu hình kết nối cơ sở dữ liệu
    ├── crud.py                        # Các hàm thao tác với database (Create, Read, Update, Delete)
    ├── routing.py                     # Thuật toán tìm đường
    ├── dataset.csv, local_db.json     # Dữ liệu mẫu/mock data
    ├── requirements.txt               # Danh sách thư viện Python cần thiết
    └── run_server.bat / run_server.sh # Script khởi chạy server nhanh
```

---

## 2. Cách chạy Backend (FastAPI)

Backend cung cấp các API cho ứng dụng di động và xử lý dữ liệu thuật toán.

**Yêu cầu:** Cài đặt Python 3.8 trở lên.

**Bước 1: Cài đặt thư viện**
Mở terminal tại thư mục `MobileApp/backend` và chạy lệnh:
```bash
pip install -r requirements.txt
```

**Bước 2: Khởi chạy Server**
- **Trên Windows:** Nhấn đúp vào file `run_server.bat` hoặc chạy lệnh:
  ```cmd
  run_server.bat
  ```
- **Trên Linux/Mac:**
  ```bash
  bash run_server.sh
  ```
- **Chạy thủ công:**
  ```bash
  uvicorn main:app --reload --host 0.0.0.0 --port 5001
  ```
Server sẽ chạy tại `http://localhost:5001`. Bạn có thể xem tài liệu API (Swagger UI) tại `http://localhost:5001/docs`.

---

## 3. Cách chạy Mobile App (Flutter)

Ứng dụng di động giúp giám sát và điều phối, nhận dữ liệu qua Firebase và MQTT.

**Yêu cầu:** 
- Đã cài đặt [Flutter SDK](https://docs.flutter.dev/get-started/install).
- Android Studio (có máy ảo Android) hoặc Xcode (đối với iOS) hoặc thiết bị vật lý.
- Trình soạn thảo như VS Code (có extension Flutter/Dart).

**Bước 1: Tải các thư viện phụ thuộc**
Mở terminal tại thư mục `MobileApp/ammo_monitor` và chạy lệnh:
```bash
flutter pub get
```

**Bước 2: Chạy ứng dụng**
Kết nối điện thoại hoặc bật máy ảo, sau đó chạy lệnh:
```bash
flutter run
```
Hoặc sử dụng nút Run/Debug (F5) trực tiếp trong VS Code.
