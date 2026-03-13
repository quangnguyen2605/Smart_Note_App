# Hướng dẫn cấu hình Google Sign-In cho Smart Note App

## Lỗi "Access blocked: Authorization Error. The OAuth client was not found" 

Lỗi này xảy ra khi Google không tìm thấy OAuth Client ID đã cấu hình trong ứng dụng.

## Cách khắc phục:

### Bước 1: Lấy Google Client ID từ Google Cloud Console

1. **Truy cập Google Cloud Console:**
   - Vào: https://console.cloud.google.com/
   - Chọn project: `ptud-42561`

2. **Tạo OAuth 2.0 Client ID:**
   - Menu ☰ → APIs & Services → Library
   - Tìm "Google Sign-In API"
   - Nếu chưa enable, click "Enable"
   - Sau khi enable, click "Credentials" tab
   - Click "Create Credentials" → "OAuth client ID"
   - Chọn "Web application"
   - Điền thông tin:
     ```
     Name: Smart Note Web
     Authorized JavaScript origins: http://localhost:8080
     Authorized redirect URIs: http://localhost:8080
     ```
   - Click "Create"

3. **Copy Client ID:**
   - Sau khi tạo, bạn sẽ thấy Client ID dạng: `123456789-xxxxxxxx.apps.googleusercontent.com`

### Lỗi "redirect_uri_mismatch" - CÁCH KHẮC PHỤC:

Lỗi này xảy ra khi redirect URI trong Google Cloud Console không khớp với URI ứng dụng đang sử dụng.

**🔧 Sửa ngay:**

1. **Vào Google Cloud Console:**
   - https://console.cloud.google.com/
   - Chọn project: ptud-42561
   - APIs & Services → Credentials

2. **Tìm OAuth Client ID của bạn:**
   - Tìm Client ID: `346353106055-9gfidtupf2maibo7um7gil37rug1pitu.apps.googleusercontent.com`
   - Click vào để chỉnh sửa

3. **Cập nhật Authorized redirect URIs:**
   Trong "Authorized redirect URIs", thêm:
   ```
   http://localhost:8080
   http://127.0.0.1:8080
   https://localhost:8080
   https://127.0.0.1:8080
   http://localhost:3000
   http://127.0.0.1:3000
   ```

4. **Cập nhật Authorized JavaScript origins:**
   Trong "Authorized JavaScript origins", thêm:
   ```
   http://localhost:8080
   http://127.0.0.1:8080
   https://localhost:8080
   https://127.0.0.1:8080
   http://localhost:3000
   http://127.0.0.1:3000
   ```

5. **Click "Save"**

6. **Chạy ứng dụng với port 8080:**
   ```bash
   flutter run -d chrome --web-port=8080
   ```

**🔍 Kiểm tra redirect URI thực tế:**
- Mở Chrome DevTools (F12)
- Tab Network
- Thử Google Sign-In
- Tìm request đến Google OAuth
- Xem "redirect_uri" trong request parameters

**📝 Lưu ý quan trọng:**
- Phải chạy trên port 8080 (không phải port khác)
- Phải dùng http://localhost:8080 (không phải https)
- Sau khi cập nhật Google Cloud Console, cần restart ứng dụng

### Bước 2: Cấu hình trong Firebase Console

1. **Truy cập Firebase Console:**
   - Vào: https://console.firebase.google.com/u/0/project/ptud-42561/authentication

2. **Bật Google Sign-In:**
   - Tab "Sign-in method"
   - Click "Google"
   - Bật "Enable"

3. **Cấu hình OAuth Client:**
   - Trong cùng trang, click "Web SDK Configuration"
   - Copy "Web client ID" (nếu có) hoặc dán Client ID từ Google Cloud vào
   - Copy "Web client secret" (nếu cần)

### Bước 3: Cập nhật file index.html

Mở file `web/index.html` và cập nhật:

```html
<!-- Google Sign-In -->
<meta name="google-signin-client_id" content="GOOGLE_CLIENT_ID_CỦA_BẠN_VÀO_ĐÂY">
```

Thay thế `GOOGLE_CLIENT_ID_CỦA_BẠN_VÀO_ĐÂY` bằng Client ID thật của bạn.

### Bước 4: Cấu hình Google Cloud Console

1. **Quay lại Google Cloud Console**
2. **Chọn project:** ptud-42561
3. **Vào APIs & Services → Library**
4. **Tìm Google Sign-In API**
5. **Click "Manage Credentials"**
6. **Chọn OAuth Client ID vừa tạo**
7. **Trong "Authorized JavaScript origins", thêm:**
   ```
   http://localhost:8080
   http://127.0.0.1:8080
   ```
8. **Trong "Authorized redirect URIs", thêm:**
   ```
   http://localhost:8080
   http://127.0.0.1:8080
   ```

### Bước 5: Khởi động lại ứng dụng

```bash
flutter run -d chrome --web-port=8080
```

### Lưu ý quan trọng:

1. **Client ID và Secret phải khớp nhau** giữa Google Cloud và Firebase
2. **Domain phải chính xác:** localhost:8080 cho development
3. **Sau khi cấu hình xong, cần restart** ứng dụng
4. **Kiểm tra console logs** để xem lỗi chi tiết

### Kiểm tra cấu hình:

- Vào Firebase Console → Authentication → Settings → Web SDK Configuration
- Đảm bảo "Web client ID" khớp với Client ID từ Google Cloud

### Nếu vẫn lỗi:

1. Kiểm tra xem Client ID có chính xác không
2. Kiểm tra xem domain có đúng không (localhost:8080)
3. Xóa cache trình duyệt
4. Kiểm tra console logs để xem lỗi chi tiết

Sau khi cấu hình xong, Google Sign-In sẽ hoạt động bình thường!
