# TPIOS

TPIOS là iOS dylib dùng để thử nghiệm các chức năng UI/runtime injection trên iPhone.

## Trạng thái hiện tại

Project đang trong quá trình phát triển. Các chức năng UI cơ bản đã hoạt động ổn định.

### Đã có
- Floating Button kiểu AssistiveTouch.
- Tap → mở/đóng menu.
- Giữ + kéo → di chuyển Floating Button, không mở menu.
- Menu có thể di chuyển và resize.
- Vượt Rào.
- Quét runtime.
- Xem log.
- Tắt quảng cáo.
- Lưu profile cơ chế quảng cáo để dùng lại.

### Đang phát triển
- Hoàn thiện và tăng độ ổn định của AdBlock.
- Hỗ trợ thêm các cơ chế quảng cáo khác.
- Cải thiện UI/UX và hiệu năng.

---

## QUY TẮC PHÁT TRIỂN

### 1. Không phá chức năng đang hoạt động
Trước khi sửa phải kiểm tra code hiện tại và xác định chính xác nguyên nhân.

Không tự ý thay đổi các chức năng khác nếu không liên quan trực tiếp.

### 2. Ưu tiên sửa tối thiểu
- Sửa đúng file cần sửa.
- Không đổi API/tên class/tên method nếu không cần thiết.
- Không tạo kiến trúc mới nếu cấu trúc hiện tại đã đáp ứng được.
- Không refactor lớn chỉ để sửa một lỗi nhỏ.

### 3. Mỗi chức năng nên độc lập
Các chức năng nên được tách thành file riêng khi có thể.

Ví dụ:
- `TPIOSController.swift` → UI chính/Floating Button.
- `TPIOSMenu.swift` → Menu chính.
- `TPIOSBypass.swift` → Vượt Rào.
- `TPIOSQuotaScanner.swift` → Quét.
- `TPIOSLog.swift` → Log.
- `TPIOSAdBlock.swift` → Tắt quảng cáo.

Không gom nhiều chức năng không liên quan vào cùng một file.

### 4. Không tự động chạy tác vụ nặng
Đặc biệt không chạy scanner, view traversal, observation hoặc timer liên tục khi không cần thiết.

Mọi cơ chế có thể gây lag phải được kiểm soát và chỉ chạy khi cần.

Ví dụ:
- Profile AdBlock đã lưu → áp dụng một lần.
- Không tự động quét lại mỗi lần mở app.
- Muốn học lại cơ chế → người dùng chủ động bấm **Quét lại cơ chế**.

### 5. Khi sửa lỗi phải tìm nguyên nhân trước
Không sửa theo kiểu đoán.

Quy trình:
1. Đọc code liên quan.
2. Xác định nguyên nhân.
3. Kiểm tra các thành phần liên quan.
4. Sửa đúng nguyên nhân.
5. Kiểm tra lại các trường hợp có thể gây crash/lag/regression.

### 6. Log phải có mục đích
Các log quan trọng dùng `TPIOSLog`.

Không spam log trong vòng lặp/timer liên tục nếu không cần thiết.

### 7. Khi thêm chức năng mới
Ưu tiên:
- File riêng.
- Không ảnh hưởng chức năng cũ.
- Có thể bật/tắt độc lập.
- Có log rõ ràng nếu cần debug.
- Không chạy nền liên tục nếu không cần.

### 8. Build
Project build bằng GitHub Actions với:
- Xcode 26.x
- iPhoneOS SDK
- arm64
- iOS 15.0+

Không tự ý thay đổi workflow/build system nếu không cần thiết.

### 9. Trước khi commit
Kiểm tra:
- Compile/build.
- Không có lỗi linker.
- Không có selector/method trùng gây conflict.
- Không có timer/observer chạy vô hạn ngoài ý muốn.
- Không làm thay đổi hành vi chức năng đã ổn định.


**Nguyên tắc quan trọng nhất:**
> Sửa đúng nguyên nhân, thay đổi ít nhất có thể, không phá chức năng đang hoạt động.