# Danh Mục Mã Lỗi Backend (Error_Code_Catalog.md)

Tài liệu này định nghĩa cấu trúc phản hồi lỗi tiêu chuẩn của hệ thống Local Backend và danh mục các mã lỗi cụ thể phục vụ quá trình debug và hiển thị thông báo trên Dashboard/Flutter App.

---

## 🛑 1. Định Dạng Phản Hồi Lỗi Chuẩn (Standard Error Format)

Khi xảy ra lỗi (HTTP status code >= 400), backend sẽ luôn trả về một body JSON có cấu trúc thống nhất như sau:

```json
{
  "error": {
    "code": "MÃ_LỖI_HỆ_THỐNG",
    "message": "Thông điệp mô tả lỗi chi tiết cho lập trình viên hoặc người dùng.",
    "details": {}
  }
}
```

---

## 🗂️ 2. Danh Mục Các Mã Lỗi Hệ Thống (Error Codes)

| HTTP Status | Mã Lỗi (Code) | Ý nghĩa kỹ thuật | Cách xử lý gợi ý |
| :--- | :--- | :--- | :--- |
| **400** | `BAD_REQUEST` | Yêu cầu không hợp lệ hoặc thiếu dữ liệu bắt buộc. | Kiểm tra lại cấu trúc body hoặc tham số truyền đi. |
| **400** | `INVALID_QUERY_PARAM` | Giá trị tham số query hoặc tọa độ truyền lên bị sai định dạng. | Kiểm tra lại kiểu dữ liệu của query (ví dụ: `limit` phải là số). |
| **400** | `TELEMETRY_INVALID_PAYLOAD`| Dữ liệu telemetry gửi từ Gateway bị thiếu `node_id` hoặc thông số cảm biến. | Kiểm tra lại hàm parsing dữ liệu JSON trên Gateway nhúng. |
| **401** | `UNAUTHORIZED` | Không có quyền truy cập vào endpoint yêu cầu bảo mật. | Thực hiện đăng nhập để lấy token/session. |
| **401** | `AUTH_FAIL` | Email hoặc mật khẩu đăng nhập bị sai. | Kiểm tra lại thông tin đăng nhập trên giao diện đăng nhập. |
| **403** | `FORBIDDEN` | Tài khoản không có đủ quyền thực hiện hành động này. | Kiểm tra vai trò tài khoản (`driver` vs `admin`). |
| **404** | `NOT_FOUND` | Không tìm thấy endpoint hoặc tài nguyên yêu cầu. | Kiểm tra lại URL của request. |
| **404** | `NODE_NOT_FOUND` | Không tìm thấy node hoặc phương tiện có ID tương ứng. | Tạo mới node trước hoặc kiểm tra lại chuỗi `node_id`. |
| **404** | `ALERT_NOT_FOUND` | Không tìm thấy bản ghi cảnh báo an ninh yêu cầu resolve. | Kiểm tra lại `alert_id` gửi lên. |
| **404** | `MISSION_NOT_FOUND` | Không tìm thấy nhiệm vụ tương ứng với `mission_id` gửi lên. | Kiểm tra lại `mission_id`. |
| **422** | `VALIDATION_ERROR` | Dữ liệu đầu vào không vượt qua bộ kiểm tra Pydantic schema. | Đối chiếu dữ liệu gửi lên với cấu trúc model định nghĩa trong `schemas.py`. |
| **500** | `INTERNAL_SERVER_ERROR` | Lỗi không mong đợi phát sinh trên Server. | Kiểm tra console server log hoặc bảng `system_logs` để biết chi tiết lỗi. |
| **500** | `DATABASE_ERROR` | Lỗi kết nối hoặc thực thi truy vấn tới file SQLite. | Kiểm tra quyền ghi file `iot_transport.db` hoặc lỗi khóa luồng. |

---

## 🛠️ 3. Cơ Chế Xử Lý Lỗi Trên Frontend / Dashboard
1. **Kiểm tra success flag**: Đối với các API cũ, kiểm tra trường `"success": false` và lấy lỗi từ trường `"error"`.
2. **Đọc mã lỗi**: Khi tích hợp Dashboard mới (Tuần 10), lập trình viên nên đọc trường `response.data.error.code` để đưa ra các thông báo lỗi phù hợp trên UI (ví dụ: Đỏ/vàng cảnh báo).
3. **Log lỗi tự động**: Tất cả các mã lỗi nghiêm trọng (như `AUTH_FAIL`, `DEVIATION_ALERT`) đều tự động được ghi nhận vào bảng `system_logs` trên SQLite để phục vụ kiểm tra vận hành sau này.
