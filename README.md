# 📔 Smart Note - [Nguyễn Văn Quang] - [2351160542]

**Smart Note** là ứng dụng ghi chú hiện đại, tối giản và tiện lợi, được xây dựng trên nền tảng **Flutter**. Ứng dụng tập trung vào trải nghiệm người dùng với giao diện màu sắc bắt mắt, hỗ trợ lưu trữ dữ liệu an toàn và tính năng tự động lưu thông minh.

## 🚀 LUỒNG ỨNG DỤNG (APP FLOW)
1. **Khởi động**: Ứng dụng tự động đọc dữ liệu ghi chú đã lưu từ thiết bị.
2. **Kiểm tra dữ liệu**: 
   - Nếu chưa có ghi chú: Hiển thị màn hình thông báo trống với hình ảnh minh họa sinh động.
   - Nếu đã có: Hiển thị danh sách ghi chú dưới dạng lưới 2 cột hiện đại.
3. **Màn hình chính**: 
   - Tìm kiếm ghi chú theo tiêu đề trong thời gian thực.
   - Bấm nút **(+) Thêm mới** để tạo ghi chú.
   - Bấm vào ghi chú cũ để xem hoặc chỉnh sửa.
   - **Vuốt để xóa**: Hỗ trợ thao tác vuốt ngang để xóa ghi chú (có hộp thoại xác nhận).
4. **Màn hình soạn thảo**: Tự động lưu (Auto-save) dữ liệu ngay khi người dùng nhấn nút Back hoặc thoát màn hình.
5. **Đồng bộ**: Danh sách ở màn hình chính luôn tự động cập nhật dữ liệu mới nhất.

## ✨ YÊU CẦU GIAO DIỆN & TÍNH NĂNG (UI/UX)
### A. Màn hình chính (Home Screen)
- **Định danh**: AppBar hiển thị rõ ràng: `Smart Note - [Nguyễn Văn Quang] - [2351160542]`.
- **Thanh tìm kiếm**: Thiết kế bo tròn, nằm ngay dưới AppBar, hỗ trợ lọc kết quả Real-time.
- **Danh sách Ghi chú**: 
  - Hiển thị dạng lưới 2 cột (**Masonry Layout**) với các thẻ có độ cao khác nhau.
  - Mỗi thẻ ghi chú có màu sắc riêng biệt (7 màu Pastel), đổ bóng nhẹ và bo góc 15px.
  - Hiển thị Tiêu đề (in đậm, 1 dòng), Nội dung tóm tắt (3 dòng) và Thời gian sửa đổi (dd/MM/yyyy HH:mm).
- **Trạng thái trống**: Hình ảnh minh họa mờ kèm thông điệp khích lệ tạo mới.

### B. Màn hình Soạn thảo (Detail / Edit Screen)
- **Giao diện tối giản**: Thiết kế như một trang giấy trắng, không viền ô nhập liệu.
- **Nhập liệu đa dòng**: Ô nội dung tự động giãn chiều cao theo văn bản.
- **Auto-save (Trọng tâm)**: Không có nút "Lưu". Dữ liệu được tự động mã hóa JSON và lưu xuống thiết bị khi người dùng Back.
- **Tùy biến**: Cho phép chọn màu sắc cho từng ghi chú thông qua bảng màu (Palette).

### C. Thao tác Xóa (Delete)
- Hỗ trợ **Swipe to delete** với nền màu đỏ và icon thùng rác.
- **Ràng buộc**: Luôn hiển thị hộp thoại xác nhận trước khi xóa vĩnh viễn khỏi Storage.

## 🛠 YÊU CẦU KỸ THUẬT
- **Hoạt động Offline**: Không cần kết nối mạng.
- **Data Model**: Dữ liệu được đóng gói vào Model class, chuyển đổi qua lại giữa Object và JSON.
- **Storage**: Sử dụng `SharedPreferences` để lưu trữ chuỗi JSON bền vững.
- **Bảo toàn dữ liệu**: Dữ liệu vẫn còn nguyên vẹn ngay cả khi tắt hoàn toàn ứng dụng hoặc khởi động lại máy.

## 📦 Cài đặt & Khởi chạy
1. Đảm bảo đã cài đặt Flutter SDK (^3.10.7).
2. Chạy lệnh cài đặt thư viện:
   ```sh
   flutter pub get
   ```
3. Chạy ứng dụng:
   ```sh
   flutter run
   ```

---
*Phát triển bởi: **Nguyễn Văn Quang** - MSV: **2351160542***
