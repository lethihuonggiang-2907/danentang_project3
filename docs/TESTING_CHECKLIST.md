# HƯỚNG DẪN KIỂM THỬ THỰC TẾ TRÊN ĐIỆN THOẠI (MANUAL TESTING CHECKLIST)

Tài liệu này liệt kê các kịch bản kiểm thử trên thiết bị thật (Android) mà sinh viên cần thực hiện để chụp ảnh minh chứng và đo đạc số liệu thực tế cho báo cáo `REPORT.md`.

---

## 1. Kiểm thử Quyền và Camera trực tiếp (Live Camera)
- [ ] **Yêu cầu cấp quyền lần đầu:** Gỡ app hoặc xóa dữ liệu, mở tab "Quét đơn", kiểm tra xem hộp thoại xin quyền Camera của Android có hiển thị đúng không.
- [ ] **Từ chối cấp quyền:** Từ chối quyền và kiểm tra hộp thoại báo lỗi thân thiện hiển thị, nút mở Cài đặt thiết bị hoạt động bình thường.
- [ ] **Toggle Flash:** Chạm vào biểu tượng đèn flash chuyển đổi qua lại giữa `Tắt (Off)` ➔ `Tự động (Auto)` ➔ `Bật sáng (Torch)`.
- [ ] **Chạm để lấy nét (Tap-to-Focus):** Chạm vào các vị trí khác nhau trên màn hình camera, kiểm tra vòng tròn tiêu cự màu vàng có hiển thị hiệu ứng co nhỏ (pulse animation) tại điểm chạm và camera có lấy nét/đo sáng tại điểm đó không.
- [ ] **Khung căn chỉnh (Crop Frame Overlay):** Đặt hóa đơn vào trong khung viền 4 góc màu xanh lá. Chụp ảnh và kiểm tra ảnh lưu lại có được tự động cắt đúng khu vực hóa đơn không.

---

## 2. Kiểm thử Nhận diện OCR & Bóc tách Hóa đơn (10 Hóa đơn thực tế)
Chụp thử ít nhất 10 hóa đơn/phiếu thanh toán thực tế khác nhau (ghi lại thời gian ms đo được từ ứng dụng):

| # | Loại hóa đơn / Nguồn | Tên cửa hàng nhận diện | Số tiền nhận diện (VND) | Ngày nhận diện | Thời gian OCR (ms) | Ghi chú / Độ chính xác |
|---|----------------------|------------------------|-------------------------|----------------|--------------------|------------------------|
| 1 | Cửa hàng tiện lợi (Circle K / 7-Eleven) | [TODO] | [TODO] | [TODO] | [TODO] | [TODO: Đúng/Sai] |
| 2 | Quán cà phê (Highlands / Phúc Long) | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 3 | Siêu thị (Co.opmart / WinMart) | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 4 | Nhà sách (Phương Nam / Fahasa) | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 5 | Quán ăn / Nhà hàng | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 6 | Hóa đơn có tiền khách đưa & tiền thừa | [TODO] | [TODO] | [TODO] | [TODO] | [TODO: Kiểm tra có bỏ qua tiền thừa?] |
| 7 | Hóa đơn có thuế VAT 8% hoặc 10% | [TODO] | [TODO] | [TODO] | [TODO] | [TODO: Kiểm tra có lấy đúng tổng tiền sau VAT?] |
| 8 | Chuyển khoản Vietcombank (Ảnh chụp màn hình) | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 9 | Chuyển khoản MB Bank / Techcombank | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 10| Chuyển khoản Ví điện tử MoMo | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |

---

## 3. Kiểm thử Ngoại lệ & Trường hợp biên
- [ ] **Ảnh mờ / Chụp mặt bàn không có chữ:** Ứng dụng hiển thị cảnh báo "Không nhận diện được chữ", cung cấp tùy chọn "Chụp lại" hoặc "Tiếp tục nhập tay".
- [ ] **Chọn ảnh từ Thư viện:** Nhấn nút chọn ảnh từ thư viện trong màn hình camera và kiểm tra ảnh tải lên thành công.
- [ ] **Xóa giao dịch:** Vuốt sang trái (Swipe-to-delete) một giao dịch có ảnh hóa đơn, kiểm tra hộp thoại xác nhận xóa và kiểm tra file ảnh thumbnail trong máy đã được tự động dọn dẹp sạch sẽ.

---

## 4. Kiểm thử Biểu đồ CustomPainter
- [ ] Chuyển đổi giữa 3 tab: Tròn (Pie) ➔ Donut ➔ Tuần (Bar).
- [ ] Chạm vào từng lát cắt / cột để kiểm tra hiệu ứng làm nổi bật và thẻ thông tin chi tiết bên dưới.
- [ ] Nhấn nút chuyển tuần (`< Tuần trước` / `Tuần sau >`) trên biểu đồ cột.
- [ ] Thêm giao dịch mới và quay lại tab Thống kê để xác nhận biểu đồ cập nhật ngay lập tức.

---

## 5. Kiểm thử Trợ lý Gemini AI
- [ ] **Chế độ Máy bay (Airplane Mode / Mất mạng):** Bật chế độ máy bay, nhấn "Phân tích chi tiêu với AI", kiểm tra thông báo ngoại tuyến thân thiện hiển thị cùng nút "Thử lại".
- [ ] **Không truyền API Key:** Chạy ứng dụng không kèm `--dart-define=GEMINI_API_KEY=...`, kiểm tra màn hình báo rõ ràng "Chưa cấu hình Gemini API Key" mà không bị crash app.
- [ ] **Có API Key hợp lệ:** Kết nối mạng, nhấn phân tích và kiểm tra câu trả lời từ Gemini (`gemini-2.5-flash`) gồm: Mức độ chi tiêu (Thấp/Vừa phải/Cao), nhận xét biến động và 2-3 mục tiêu tuần tới.
