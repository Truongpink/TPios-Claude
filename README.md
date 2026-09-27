# TPIOS

TPIOS là iOS dylib dùng để thử nghiệm các chức năng UI/runtime injection trên iPhone.

---

## QUY TẮC LÀM VIỆC TRÊN REPO

> Phần này là quy tắc bắt buộc cho bất kỳ AI/người nào đọc và chỉnh sửa repo này. Khi làm việc trong repo, phải đọc phần này trước và làm đúng theo nó.

### 1. Chỉ làm việc trong đúng repo được yêu cầu

- Chỉ chỉnh sửa repo hiện tại khi task yêu cầu.
- Không tự ý kiểm tra, sửa hoặc lấy code từ repo khác nếu chưa được yêu cầu rõ ràng.
- Không tự ý thay đổi các file không liên quan.

### 2. Trước khi sửa phải đọc đúng phần liên quan

- Chỉ đọc các file thực sự liên quan đến lỗi/tính năng đang xử lý.
- Không đọc toàn bộ repo nếu không cần map kiến trúc.
- Xác định đúng file + đúng class/hàm trước khi sửa.

### 3. Khi sửa lỗi từ GitHub Actions

- Đọc log của job bị lỗi.
- Chỉ trích phần `error`, `warning` liên quan trực tiếp và stack trace cần thiết.
- Bỏ qua log build thành công dài dòng.
- Không sửa theo kiểu đoán.

Quy trình:

1. Xác định lỗi.
2. Xác định file/class/hàm gây lỗi.
3. Sửa đúng nguyên nhân.
4. Build lại.
5. Kiểm tra regression.

### 4. Khi chỉnh sửa code

- Ưu tiên diff/patch và thay đổi ít nhất có thể.
- Không viết lại toàn bộ file nếu chỉ cần sửa vài dòng.
- Giữ nguyên code đang chạy tốt.
- Không refactor lớn chỉ để sửa một lỗi nhỏ.
- Không đổi tên class/method/API nếu không cần thiết.

### 5. Mỗi chức năng nên độc lập

- Chức năng mới ưu tiên file riêng.
- Không gom các chức năng không liên quan vào `TPIOSController.swift` hoặc `TPIOSMenu.swift`.
- Chức năng mới phải hạn chế ảnh hưởng đến chức năng cũ.
- Nếu có thể bật/tắt độc lập thì nên thiết kế độc lập.

### 6. Không chạy tác vụ nặng liên tục

Đặc biệt tránh:

- Scanner chạy nền liên tục.
- View traversal liên tục.
- Observer/timer không cần thiết.
- Quét lại mỗi lần mở app nếu không cần.

Tác vụ nặng chỉ chạy khi cần hoặc khi người dùng chủ động yêu cầu.

### 7. Log phải có mục đích

- Log quan trọng dùng `TPIOSLog`.
- Không spam log trong timer/vòng lặp.
- Khi debug phải ghi đủ thông tin để xác định nguyên nhân nhưng không ghi vô hạn.

### 8. Task đơn giản thì xử lý trực tiếp

Các việc như:

- Fix typo.
- Đổi tên biến/file/class theo yêu cầu.
- Sửa path.
- Cập nhật README.

Không cần phân tích dài hoặc thay đổi kiến trúc.

### 9. Giới hạn vòng lặp sửa lỗi

Nếu cùng một lỗi đã sửa và build vẫn fail sau **3 lần thử**:

- Dừng sửa tiếp.
- Tóm tắt lỗi hiện tại.
- Nêu nguyên nhân nghi ngờ dựa trên log.
- Không tiếp tục đoán mò.

### 10. Commit và giải thích

- Commit message ngắn gọn.
- Chỉ mô tả thay đổi mới.
- Không nhắc lại toàn bộ lịch sử project.
- Không tuyên bố "đã hoàn thành/chạy OK" nếu chưa có kết quả build/test xác nhận.

### 11. Không tạo file thừa

- Chỉ tạo file mới khi thực sự cần.
- Không tạo test/log/debug file dư thừa chỉ để thử tạm thời.
- Không để lại file thử nghiệm không dùng.

### 12. Build

Project hiện được build bằng GitHub Actions với:

- Xcode 26.x
- iPhoneOS SDK
- arm64
- iOS 15.0+

Không tự ý thay đổi workflow/build system nếu không liên quan trực tiếp đến task.

### 13. Trước khi xác nhận một thay đổi là OK

Kiểm tra tối thiểu:

- Compile/build.
- Không có lỗi linker.
- Không có selector/method conflict.
- Không có timer/observer chạy vô hạn ngoài ý muốn.
- Không làm thay đổi hành vi của chức năng đang ổn định.
- Nếu có UI/interaction thì kiểm tra cả touch, move, resize và close/back nếu chức năng đó có hỗ trợ.

---

## QUY TẮC BACKUP — RẤT QUAN TRỌNG

Backup dùng để **không bao giờ phải làm lại project từ đầu** nếu repo bị mất, bị khóa hoặc code bị thay đổi ngoài ý muốn.

### Khi người dùng nói: "backup hiện tại"

Phải hiểu là:

> Backup đúng trạng thái mới nhất **đang chạy OK/đã được xác nhận OK tại thời điểm backup**.

Không backup code đang thử nghiệm hoặc chưa build/test thành công.

### Cách đặt backup

Mỗi backup phải có ngày tháng năm:

`BACKUP_YYYY-MM-DD.md`

Ví dụ:

`BACKUP_2026-09-27.md`

Nếu cần nhiều backup trong cùng ngày thì dùng:

`BACKUP_2026-09-27_v2.md`

Không ghi đè backup cũ.

### Nguyên tắc giữ lịch sử backup

- Backup mới phải giữ nguyên toàn bộ nội dung backup trước đó.
- Chỉ **thêm phần trạng thái hiện tại mới đã chạy OK**.
- Không xóa phần lịch sử cũ.
- Không sửa lại lịch sử cũ chỉ vì code hiện tại đã thay đổi.
- Không đưa chức năng đang thử/nghiên cứu nhưng chưa chạy OK vào phần "đã hoàn thành".
- Mỗi backup phải ghi rõ ngày và trạng thái để nhìn vào là biết project đã đi tới đâu.

### Khi khôi phục

Nếu repo bị mất hoặc bị khóa:

1. Đọc backup mới nhất.
2. Xác định trạng thái cuối cùng đã xác nhận OK.
3. Khôi phục theo backup đó.
4. Không quay lại làm lại các chức năng đã có trong backup.
5. Các chức năng mới sau backup được xử lý như phần phát triển tiếp theo.

---

## TRẠNG THÁI HIỆN TẠI

Trạng thái này mô tả **code hiện có trong repo tại thời điểm cập nhật README**.

### UI chính

- Floating Button kiểu AssistiveTouch.
- Có thể kéo nút.
- Chạm nút để mở/đóng menu.
- Menu chính có thể kéo bằng header.
- Menu chính có thể resize bằng góc dưới bên phải.
- Menu được giới hạn trong vùng hiển thị.
- Overlay window cho phép vùng không thuộc UI của TPIOS tiếp tục nhận touch từ app bên dưới.
- Floating Button tự giảm alpha khi không thao tác.

### Menu hiện tại

Menu chính gồm 6 chức năng:

| Nút | Chức năng | File chính |
|---|---|---|
| **Vị trí** | Mở giao diện quản lý vị trí, bản đồ, tọa độ và dữ liệu vị trí đã lưu | `TPIOSLocation.swift` |
| **Quét** | Quét runtime Objective-C để tìm class/selector liên quan quota/usage/limit... | `TPIOSQuotaScanner.swift` |
| **Xem log** | Mở cửa sổ log TPIOS | `TPIOSLog.swift` |
| **Tắt QC** | Mở giao diện AdBlock/profile và cơ chế chặn quảng cáo đã lưu | `TPIOSAdBlock.swift` |
| **Đồng hồ** | Hiển thị đồng hồ HH:MM:SS và phần mười giây; có thể kéo/resize | `TPIOSSaleClock.swift` |
| **Tải lại trang** | Tìm và kích hoạt cơ chế refresh của trang/app hiện tại | `TPIOSReload.swift` |

Menu còn hiển thị:

- Tên **TPIOS**.
- **Design By TRUONGPHONG**.
- Trạng thái bằng chấm xanh.
- Ngày dương và ngày âm tham khảo.
- Resize handle ở góc dưới phải.

---

## FILE HIỆN TẠI VÀ CHỨC NĂNG

### Core / khởi động

| File | Chức năng |
|---|---|
| `TPIOSBootstrap.m` | Constructor khởi động dylib; cài GAD presentation hook, Web diagnostics và gọi `TPIOSStart`. |
| `TPIOSEntry.swift` | Export `TPIOSStart` và `TPIOSStop`. |
| `TPIOSController.swift` | Quản lý overlay window, Floating Button, mở/đóng menu, kéo nút và vòng đời UI chính. |
| `FloatingButton.swift` | UI và style của nút nổi TPIOS. |
| `TPIOSMenu.swift` | Menu chính, các nút chức năng, move/resize và mở các module con. |

### Vị trí

| File | Chức năng |
|---|---|
| `TPIOSLocation.swift` | Giao diện Vị trí: bản đồ, chọn tọa độ, tìm kiếm/reverse geocode, latitude/longitude/altitude/address, lưu nhiều vị trí, chọn/xóa vị trí, move/resize UI và công tắc spoof. |
| `TPIOSLocationSpoofHook.swift` | Module hook Core Location; cung cấp cơ chế hook các lời gọi location manager và trả về location đã chọn khi hook được cài. |

### Quét / nghiên cứu runtime

| File | Chức năng |
|---|---|
| `TPIOSQuotaScanner.swift` | Quét Objective-C runtime để tìm class và selector có tên liên quan quota, usage, remaining, limit, reset, upload, attachment, image, vision, file... Không hiển thị quota thực tế nếu runtime không cung cấp dữ liệu đó. |

### Log / diagnostics

| File | Chức năng |
|---|---|
| `TPIOSLog.swift` | Hệ thống log nội bộ, hiển thị/xóa log và cửa sổ log có thể di chuyển. |
| `TPIOSNetworkLog.swift` | Module network/runtime logging hook. |
| `TPIOSWebDiagnostics.swift` | Theo dõi WKWebView, URL/frame, native view tree và một số resource/DOM node liên quan quảng cáo để phục vụ nghiên cứu/debug. |

### Quảng cáo

| File | Chức năng |
|---|---|
| `TPIOSAdBlock.swift` | Giao diện và cơ chế học/lưu profile quảng cáo; áp dụng profile đã lưu, rescan khi cần, theo dõi runtime/view tree và các cơ chế quảng cáo liên quan. |
| `TPIOSGADPresentationBlocker.m` | Hook `presentViewController` để chặn các fullscreen controller cụ thể của Google Mobile Ads. |
| `TPIOSModelFilter.m` | Runtime hook cho model/class được cấu hình để loại bỏ object phù hợp với predicate đã xác định. |

### Refresh / đồng hồ

| File | Chức năng |
|---|---|
| `TPIOSReload.swift` | Tìm refresh control/component trong app, WebView, ScrollView hoặc controller phù hợp và kích hoạt refresh trang. |
| `TPIOSSaleClock.swift` | Đồng hồ thời gian thực HH:MM:SS + phần mười giây, có move/resize. |

### Workflow

| File | Chức năng |
|---|---|
| `.github/workflows/build.yml` | GitHub Actions build dylib và tạo artifact. |

---

## KIẾN TRÚC CHỨC NĂNG

Luồng chính:

```
TPIOSBootstrap.m
        ↓
TPIOSEntry.swift
        ↓
TPIOSController
        ↓
FloatingButton
        ↓
TPIOSMenu
   ├── Vị trí       → TPIOSLocation
   │                    └── TPIOSLocationSpoofHook
   ├── Quét         → TPIOSQuotaScanner
   ├── Xem log      → TPIOSLog
   ├── Tắt QC       → TPIOSAdBlock
   │                    ├── TPIOSModelFilter.m
   │                    └── TPIOSGADPresentationBlocker.m
   ├── Đồng hồ      → TPIOSSaleClock
   └── Tải lại trang → TPIOSReload
```

Các module hỗ trợ:

- `TPIOSNetworkLog.swift`
- `TPIOSWebDiagnostics.swift`

---

## NGUYÊN TẮC BẢO TOÀN CHỨC NĂNG

Khi thêm chức năng mới:

1. Không sửa chức năng cũ nếu không liên quan.
2. Không thay đổi UI cũ chỉ để thêm chức năng mới.
3. Ưu tiên tạo module/file riêng.
4. Nếu phải sửa `TPIOSMenu.swift`, chỉ thêm điểm kết nối cần thiết.
5. Nếu phải sửa `TPIOSController.swift`, chỉ sửa phần lifecycle/overlay thật sự liên quan.
6. Sau khi build phải kiểm tra chức năng vừa sửa và các chức năng menu đã hoạt động trước đó.

---

## LỊCH SỬ PHÁT TRIỂN / BACKUP

Phần này dùng để ghi các mốc **đã chạy OK**.

Mỗi lần người dùng yêu cầu **"backup hiện tại"**, thêm một mục mới theo mẫu:

### YYYY-MM-DD — Backup hiện tại

**Trạng thái:** Đã build/test OK.

**Đã có:**
- ...
- ...

**Chức năng mới hoàn thành từ backup trước:**
- ...

**File thay đổi liên quan:**
- ...

**Chưa hoàn thành / đang nghiên cứu:**
- ...

Không sửa hoặc xóa các mục backup cũ.

---

## NGUYÊN TẮC QUAN TRỌNG NHẤT

> **Giữ nguyên cái đang chạy OK. Sửa đúng nguyên nhân. Thay đổi ít nhất có thể. Chức năng mới phải độc lập. Backup phải có ngày tháng và luôn giữ lại lịch sử cũ. Không để việc repo bị khóa/mất làm project phải bắt đầu lại từ đầu.**