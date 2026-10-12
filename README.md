# Ứng Dụng Quản Lý Chi Tiêu & Quét Hóa Đơn OCR (Expense Tracker + Receipt OCR)

> **Môn học:** Phát triển ứng dụng đa nền tảng (Cross-Platform Mobile App Development) - VKU  
> **Dự án:** Mini-Project 3: Offline Expense Tracker with Receipt OCR & Gemini AI Assistant  
> **Nền tảng:** Flutter 3.x / Dart 3 (Sound Null Safety)  
> **GitHub Repository:** [https://github.com/lethihuonggiang-2907/danentang_project3](https://github.com/lethihuonggiang-2907/danentang_project3)

---

## 1. Giới thiệu dự án (Project Description)

**Expense Tracker + OCR** là ứng dụng di động theo dõi chi tiêu cá nhân hoàn toàn offline, tích hợp công nghệ thị giác máy tính nhận diện ký tự quang học (On-Device OCR) bằng Google ML Kit để tự động trích xuất thông tin hóa đơn mua sắm và ảnh chụp màn hình chuyển khoản ngân hàng Việt Nam. Ứng dụng cung cấp hệ thống biểu đồ trực quan tùy biến hoàn toàn bằng `CustomPainter` (không phụ thuộc thư viện bên thứ ba) cùng trợ lý tài chính thông minh Gemini AI (hoạt động khi có kết nối mạng và đảm bảo bảo mật dữ liệu riêng tư).

---

## 2. Tính năng nổi bật (Key Features)

1. **Quét hóa đơn trực tiếp bằng Camera & Thư viện ảnh:**
   - Xem trước camera trực tiếp (Live Camera Preview) với khung căn chỉnh hóa đơn (Crop Frame Overlay).
   - Chạm để lấy nét và đo sáng (Tap-to-focus & Exposure) có hiệu ứng hoạt họa vòng tròn tiêu cự.
   - Bật/tắt đèn Flash linh hoạt: Tắt (`Off`), Tự động (`Auto`), Bật sáng (`Torch`).
   - Tự động cắt ảnh theo khung ngắm và downscale tối ưu hiệu năng trước khi đưa vào nhận diện.
2. **Nhận diện chữ OCR Offline (On-Device ML Kit):**
   - Chạy 100% trên thiết bị bằng Google ML Kit, không cần kết nối mạng hay gửi ảnh lên đám mây.
   - Đo lường và hiển thị chính xác thời gian nhận diện (`durationMs`).
   - Tự động tạo và lưu trữ ảnh thu nhỏ (Thumbnail, chiều rộng tối đa 300px) vào bộ nhớ cục bộ ứng dụng; cơ sở dữ liệu chỉ lưu đường dẫn tệp.
3. **Bộ phân tích cú pháp Heuristic Regex tiếng Việt (`ReceiptParser`):**
   - Trích xuất số tiền: Nhận dạng mọi định dạng tiền tệ Việt Nam (`150,000 VND`, `150.000đ`, `1.250.000`, `150 000`, v.v.).
   - Xử lý ưu tiên từ khóa: `TỔNG CỘNG`, `TỔNG TIỀN`, `THÀNH TIỀN`, `TỔNG THANH TOÁN`, `SỐ TIỀN`, `TOTAL`, `AMOUNT` (kể cả không dấu).
   - Loại trừ triệt để các dòng gây nhiễu: `VAT`, `THUẾ`, `TIỀN KHÁCH ĐƯA`, `TIỀN THỪA`, `GIẢM GIÁ`, `CHIẾT KHẤU`.
   - Khử nhiễu OCR: Sửa lỗi nhầm lẫn ký tự số/chữ (`O` ➔ `0`, `l`/`I` ➔ `1`, xóa khoảng trắng thừa).
   - Trích xuất ngày giao dịch: Hỗ trợ `DD/MM/YYYY`, `DD-MM-YYYY`, `DD.MM.YYYY`, `DD/MM/YY` và ngày kèm giờ; xác thực lịch chuẩn (loại bỏ ngày phi thực tế như `31/02/2026`).
   - Trích xuất tên người nhận/cửa hàng từ hóa đơn và ảnh chuyển khoản ngân hàng (Vietcombank, MB Bank, Techcombank, MoMo).
4. **Màn hình xác nhận & chỉnh sửa trước khi lưu:**
   - Cho phép người dùng kiểm tra, chỉnh sửa toàn bộ thông tin đã nhận diện trước khi ghi vào CSDL.
   - Định dạng số tiền trực tiếp khi gõ với dấu chấm phân tách hàng nghìn.
   - Xem văn bản nhận diện gốc (Raw OCR Text) phục vụ kiểm chứng độ chính xác.
5. **Lưu trữ cục bộ SQLite (`sqflite`):**
   - Bảng `transactions` lưu trữ: `id`, `amount`, `date`, `merchant`, `category`, `note`, `thumbnail_path`, `created_at`.
   - Truy vấn tham số hóa (Parameterized queries) an toàn.
   - Tự động xóa file ảnh thumbnail trên đĩa khi người dùng xóa giao dịch tương ứng.
   - Hỗ trợ vuốt để xóa (Swipe to delete) và chạm để chỉnh sửa.
   - Lọc nhanh theo 7 danh mục: `Thực phẩm`, `Học tập`, `Du lịch`, `Di chuyển`, `Giải trí`, `Sức khỏe`, `Khác`.
6. **Biểu đồ tài chính tự vẽ với `CustomPainter` (Không dùng thư viện thứ 3):**
   - **Biểu đồ tròn (Pie Chart):** Phân chia chi tiêu theo danh mục.
   - **Biểu đồ Donut (Donut Chart):** Hiển thị tổng chi tiêu ở tâm hình tròn.
   - **Biểu đồ cột tuần (Weekly Bar Chart):** Chi tiêu 7 ngày trong tuần với điều hướng chuyển tuần linh hoạt.
   - Động cơ toán học [ChartGeometry](file:///d:/danentang/project3/lib/features/charts/geometry/chart_geometry.dart) tính toán góc quét đảm bảo tổng bằng $2\pi$ và xử lý hit-testing khi người dùng chạm vào biểu đồ.
7. **Trợ lý AI phân tích tài chính (Google Gemini via REST HTTP):**
   - Kết nối trực tiếp qua `http` tới model `gemini-2.5-flash`.
   - **Bảo mật tuyệt đối:** Chỉ gửi số liệu thống kê tổng hợp (tổng tiền, danh mục, tỷ lệ biến động theo tuần); không bao giờ gửi ảnh, tên quán hoặc ghi chú cá nhân.
   - Đánh giá mức độ chi tiêu (`Thấp` / `Vừa phải` / `Cao`), phân tích xu hướng và đề xuất 2-3 mục tiêu tài chính cho tuần tới.
   - Kiểm tra kết nối mạng trước khi gọi, xử lý đầy đủ các lỗi ngoại lệ (ngoại tuyến, timeout 15s, quota 429, API key không hợp lệ).

---

## 3. Công nghệ sử dụng (Tech Stack)

| Thành phần | Công nghệ / Thư viện | Ghi chú |
|---|---|---|
| **Framework** | Flutter 3.47.2 / Dart 3.13.2 | Sound Null Safety, Strict Analyzer |
| **Kiến trúc** | Feature-First Modular Clean Architecture | Tách biệt tầng dữ liệu, nghiệp vụ và giao diện |
| **Quản lý trạng thái** | Riverpod (`flutter_riverpod: ^3.4.3`) | Compile-time safe, StateNotifier/Notifier |
| **Cơ sở dữ liệu** | SQLite (`sqflite: ^2.4.4`, `path`, `path_provider`) | CSDL quan hệ cục bộ trên thiết bị |
| **Máy ảnh & Hình ảnh** | `camera: ^0.12.1`, `image_picker: ^1.2.4` | Live camera preview & chọn ảnh từ thư viện |
| **Nhận diện chữ (OCR)** | `google_mlkit_text_recognition: ^0.17.1` | On-device offline ML Kit Text Recognition |
| **Biểu đồ** | Flutter Engine Canvas (`CustomPainter`) | Tự cài đặt 100%, không dùng thư viện ngoài |
| **Mạng & AI** | `http: ^1.6.0`, `connectivity_plus: ^7.3.2` | Gọi Gemini REST API, kiểm tra kết nối mạng |
| **Kiểm thử** | `flutter_test` | Unit test & Widget test (hơn 60 test cases) |

---

## 4. Cấu trúc thư mục (Project Architecture)

```
lib/
├── main.dart                                   # Điểm khởi chạy ứng dụng (ProviderScope)
├── core/
│   ├── constants/app_constants.dart           # Hằng số toàn cục, danh mục chi tiêu chuẩn
│   ├── theme/
│   │   ├── app_theme.dart                     # Cấu hình Material 3 Light & Dark mode
│   │   └── theme_provider.dart                # Riverpod quản lý chuyển đổi chế độ giao diện
│   └── utils/
│       ├── currency_formatter.dart            # Định dạng tiền tệ VND (VD: 150.000 ₫)
│       └── thousands_separator_input_formatter.dart # Định dạng phân tách nghìn khi gõ
├── data/
│   ├── database/database_helper.dart          # Quản lý kết nối SQLite, schema & migration
│   ├── models/transaction_item.dart           # Data Model giao dịch (toMap, fromMap)
│   └── repositories/transaction_repository.dart# Thao tác CRUD, tính tổng danh mục, ngày
└── features/
    ├── home/home_screen.dart                  # Navigation Bar chính (4 tabs)
    ├── transactions/                          # Quản lý giao dịch chi tiêu
    │   ├── providers/transaction_provider.dart# Riverpod AsyncNotifier quản lý danh sách
    │   ├── utils/category_helper.dart         # Biểu tượng và màu sắc riêng theo danh mục
    │   └── screens/
    │       ├── transaction_list_screen.dart   # Danh sách giao dịch, bộ lọc, vuốt để xóa
    │       └── add_edit_transaction_screen.dart# Thêm/Sửa giao dịch thủ công
    ├── extraction/                            # Bóc tách thông tin từ OCR (Pure Dart)
    │   └── receipt_parser.dart                # Regex heuristic bóc tách số tiền, ngày, tên quán
    ├── scanner/                               # Quét ảnh & Nhận diện OCR
    │   ├── services/
    │   │   ├── ocr_service.dart               # Dịch vụ ML Kit OCR đo đạc độ trễ (ms)
    │   │   └── thumbnail_service.dart         # Tạo và nén ảnh thumbnail lưu vào máy
    │   ├── utils/
    │   │   ├── crop_geometry.dart             # Toán học ánh xạ khung hình sang pixel ảnh
    │   │   └── image_cropper.dart             # Cắt ảnh trực tiếp bằng Canvas Engine
    │   ├── widgets/
    │   │   ├── camera_crop_overlay.dart       # Lớp phủ khung ngắm và 4 góc bo
    │   │   └── focus_ring_widget.dart         # Vòng tròn hiệu ứng chạm để lấy nét
    │   └── screens/
    │       ├── camera_scanner_screen.dart     # Màn hình Live Camera chính
    │       ├── scanner_screen.dart            # Màn hình chọn ảnh thư viện / chụp ảnh
    │       └── receipt_confirm_screen.dart    # Màn hình xác nhận thông tin sau OCR
    ├── charts/                                # Biểu đồ CustomPainter tự vẽ
    │   ├── geometry/chart_geometry.dart       # Toán học hình học tính góc quét, cột, hit-test
    │   ├── painters/
    │   │   ├── pie_chart_painter.dart         # Vẽ biểu đồ tròn (Pie)
    │   │   ├── donut_chart_painter.dart       # Vẽ biểu đồ Donut có tổng ở tâm
    │   │   └── bar_chart_painter.dart         # Vẽ biểu đồ cột tuần 7 ngày
    │   ├── providers/chart_provider.dart      # Provider tính toán dữ liệu tuần và danh mục
    │   └── screens/charts_screen.dart         # Màn hình tương tác biểu đồ & chuyển tuần
    └── ai_assistant/                          # Trợ lý tài chính Gemini AI
        ├── models/spending_aggregation.dart   # Model số liệu tổng hợp (chỉ số thống kê)
        ├── services/gemini_service.dart       # Gọi Gemini REST API, xử lý lỗi mạng
        └── screens/ai_assistant_screen.dart   # Màn hình phân tích chi tiêu AI & gợi ý mục tiêu
```

---

## 5. Yêu cầu hệ thống (Prerequisites)

* **Flutter SDK:** Phiên bản `>= 3.22.0` (Khuyến nghị: Flutter 3.47.x trở lên).
* **Dart SDK:** Phiên bản `>= 3.4.0` (Kèm Sound Null Safety).
* **Android SDK:**
  * `compileSdkVersion`: 34 hoặc 35.
  * `minSdkVersion`: 21 (Bắt buộc cho Camera và Google ML Kit Text Recognition).
  * `targetSdkVersion`: 34.
* **Hệ điều hành kiểm thử:** Android 7.0 trở lên (Thiết bị thật hoặc Emulator hỗ trợ Google Play Services).

---

## 6. Hướng dẫn cài đặt & Chạy ứng dụng (Step-by-Step Setup)

### Bước 1: Clone mã nguồn
```bash
git clone https://github.com/lethihuonggiang-2907/danentang_project3.git
cd danentang_project3
```

### Bước 2: Tải các thư viện phụ thuộc
```bash
flutter pub get
```

### Bước 3: Lấy khóa API Google Gemini (Tùy chọn cho tính năng AI)
1. Truy cập [Google AI Studio](https://aistudio.google.com/) và tạo API Key miễn phí.
2. Không lưu khóa API trực tiếp vào mã nguồn. Khóa được truyền an toàn qua tham số `--dart-define`.

### Bước 4: Chạy ứng dụng
* **Chạy thông thường (Không dùng trợ lý AI):**
  ```bash
  flutter run
  ```
* **Chạy kèm khóa Gemini API:**
  ```bash
  flutter run --dart-define=GEMINI_API_KEY="AIzaSyYourGeminiApiKeyHere"
  ```

---

## 7. Chạy kiểm thử tự động (Running Automated Tests)

Dự án bao gồm bộ kiểm thử toàn diện với hơn 60 bài kiểm thử (Unit test cho parser, toán hình học, serialization và Widget test cho các màn hình):

```bash
# Chạy toàn bộ các bài kiểm thử:
flutter test

# Kiểm tra phân tích tĩnh mã nguồn (đạt chuẩn 0 warning, 0 error):
flutter analyze
```

---

## 8. Hướng dẫn đóng gói ứng dụng (Release APK Build)

Để đóng gói bản phát hành APK cài đặt trực tiếp lên điện thoại Android:

```bash
flutter build apk --release --dart-define=GEMINI_API_KEY="AIzaSyYourGeminiApiKeyHere"
```

* **Vị trí file APK sau khi build thành công:**
  ```
  build/app/outputs/flutter-apk/app-release.apk
  ```

---

## 9. Giới hạn đã biết (Known Limitations)

1. **Google ML Kit Text Recognition:** Chạy on-device trên nền tảng Android/iOS. Không hỗ trợ trực tiếp trên nền tảng Web.
2. **Chất lượng ảnh chụp:** Độ chính xác nhận diện số tiền và ngày phụ thuộc vào độ sáng, độ nét của bức ảnh và hiện tượng lóa giấy in nhiệt. Để đạt độ chính xác tối ưu, hãy căn chỉnh hóa đơn phẳng trong khung ngắm.
3. **Bảo mật API Key trên Client:** Do ứng dụng không sử dụng máy chủ trung gian (Serverless/Offline-first), nếu build APK phát hành rộng rãi có truyền `--dart-define=GEMINI_API_KEY`, khóa API trong nhị phân client có nguy cơ bị dịch ngược (Reverse Engineering). Trong môi trường sản phẩm thực tế, các yêu cầu gọi AI cần được định tuyến qua Backend Proxy để bảo vệ khóa API.

---

## 10. Kiến thức lý thuyết nền tảng (Theoretical Concepts)

### 10.1. Giao diện khai báo (Declarative UI) và Cây Widget (Widget Tree)
* **Declarative UI:** Trong Flutter, giao diện là hàm của trạng thái: `UI = f(state)`. Khác với mô hình mệnh lệnh (Imperative UI như Android View truyền thống) khi lập trình viên phải tự tìm kiếm và thay đổi từng thuộc tính của view, trong Flutter lập trình viên chỉ cần mô tả giao diện tương ứng với từng trạng thái cụ thể. Khi `state` thay đổi, Flutter sẽ tự động tính toán lại cây widget và vẽ lại giao diện tương ứng.
* **Cơ chế 3 tầng cây của Flutter:**
  1. **Widget Tree:** Bất biến (Immutable), cấu hình giao diện gọn nhẹ được tạo mới thường xuyên.
  2. **Element Tree:** Quản lý vòng đời (Lifecycle) và gắn kết Widget với RenderObject, kiểm tra xem widget có tái sử dụng được không để tối ưu hiệu năng.
  3. **RenderObject Tree:** Đảm nhiệm việc tính toán kích thước (Layout), tọa độ và vẽ trực tiếp lên màn hình (Paint).

### 10.2. JIT (Just-In-Time) vs AOT (Ahead-Of-Time) Compilation
* **Chế độ Debug (JIT):** Dart biên dịch mã nguồn theo cơ chế Just-In-Time trong quá trình chạy. Điều này cho phép tính năng **Hot Reload** và **Hot Restart** hoạt động với tốc độ dưới 1 giây, giúp tăng tốc độ phát triển và thử nghiệm giao diện.
* **Chế độ Release (AOT):** Khi đóng gói sản phẩm, mã nguồn Dart được biên dịch trước (Ahead-Of-Time) trực tiếp thành mã máy nhị phân (ARM64 / x86_64). Điều này giúp ứng dụng khởi động tức thì, loại bỏ độ trễ và đạt tốc độ khung hình mượt mà 60–120 FPS.

### 10.3. Ba tầng kiến trúc của Flutter (Architecture Layers)
1. **Framework Layer (Ngôn ngữ Dart):** Cung cấp các khối xây dựng cấp cao cho lập trình viên bao gồm: Material & Cupertino widgets, Animation, Gestures, Rendering và Foundation.
2. **Engine Layer (Ngôn ngữ C/C++):** Trái tim của Flutter, chịu trách nhiệm kết xuất đồ họa cấp thấp (Impeller / Skia), hệ thống máy ảo Dart (Dart VM), xử lý văn bản (Text layout qua HarfBuzz), và cơ chế đồng bộ khung hình (vsync).
3. **Embedder Layer (Đặc thù nền tảng - Java/Kotlin trên Android, Obj-C/Swift trên iOS):** Tầng cầu nối giữa Flutter Engine và hệ điều hành, chịu trách nhiệm khởi tạo bề mặt vẽ (Surface/Texture), điều phối sự kiện cảm ứng (Touch inputs), và quản lý các dịch vụ nền tảng (Camera, Sensors, CSDL, v.v.).
