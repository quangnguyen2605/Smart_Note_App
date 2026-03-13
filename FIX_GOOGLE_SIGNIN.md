# Fix Lỗi Google Sign-In - People API

## Lỗi hiện tại:
```
People API has not been used in project 346353106055 before or it is disabled. 
Enable it by visiting https://console.developers.google.com/apis/api/people.googleapis.com/overview?project=346353106055
```

## Cách khắc phục:

### Cách 1: Enable People API (Nhanh nhất)

1. **Vào link trực tiếp:**
   https://console.developers.google.com/apis/api/people.googleapis.com/overview?project=346353106055

2. **Click "Enable"**
   - Nếu thấy nút "Enable", click vào đó
   - Chờ vài giây để API được enable

3. **Test lại Google Sign-In**

### Cách 2: Sử dụng Firebase Auth (Tốt hơn)

1. **Vào Firebase Console:**
   - https://console.firebase.google.com/u/0/project/ptud-42561/authentication

2. **Cấu hình Google Sign-In:**
   - Tab "Sign-in method" → "Google"
   - Bật "Enable"
   - Copy "Web client ID" từ Firebase

3. **Cập nhật Google Client ID trong code:**
   - Thay thế Client ID hiện tại bằng Client ID từ Firebase

### Cách 3: Dùng email scope chỉ (Đã sửa trong code)

Tôi đã sửa code để chỉ yêu cầu email scope, không cần People API:

```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email'], // Chỉ yêu cầu email
  clientId: '346353106055-9gfidtupf2maibo7um7gil37rug1pitu.apps.googleusercontent.com',
  hostedDomain: '',
);
```

## Test lại:

1. **Chạy ứng dụng:**
   ```bash
   flutter run -d chrome --web-port=8080
   ```

2. **Test Google Sign-In:**
   - Click "Đăng nhập với Google"
   - Kiểm tra console logs

3. **Kiểm tra logs:**
   ```
   🔍 Bắt đầu Google Sign-In...
   ✅ Google User: email@example.com
   ✅ Đăng nhập Google thành công: email@example.com
   ```

## Nếu vẫn lỗi:

- **Lỗi redirect_uri_mismatch:** Kiểm tra port 8080
- **Lỗi invalid_client:** Kiểm tra Client ID
- **Lỗi network:** Kiểm tra kết nối internet

Sau khi enable People API, Google Sign-In sẽ hoạt động bình thường!
