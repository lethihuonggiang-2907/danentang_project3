import 'package:expense_tracker/features/extraction/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiptParser Heuristic Regex Extraction (Simulated OCR Strings)', () {
    // --- 1 to 6: Amount formats ---
    test('Case 1: Parse amount with comma separator and VND suffix (150,000 VND)', () {
      const String text = '''
HÓA ĐƠN BÁN LẺ
TỔNG CỘNG: 150,000 VND
Cảm ơn quý khách!
''';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.amount, 150000);
    });

    test('Case 2: Parse amount with dot separator and đ suffix (150.000đ)', () {
      const String text = '''
Highlands Coffee
THÀNH TIỀN: 150.000đ
Ngày 15/05/2026
''';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.amount, 150000);
    });

    test('Case 3: Parse amount with dot separator and VNĐ suffix (1.250.000 VNĐ)', () {
      const String text = '''
Siêu thị Co.opmart
TỔNG THANH TOÁN: 1.250.000 VNĐ
''';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.amount, 1250000);
    });

    test('Case 4: Parse amount with space separator (150 000)', () {
      const String text = '''
Cửa hàng tiện lợi
Tổng tiền: 150 000 đ
''';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.amount, 150000);
    });

    test('Case 5: Parse continuous digits without separator (150000)', () {
      const String text = '''
Circle K
SỐ TIỀN: 150000
''';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.amount, 150000);
    });

    test('Case 6: Parse amount with currency prefix (VND 150,000)', () {
      const String text = '''
Nhà hàng Sen Vàng
TOTAL: VND 150,000
''';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.amount, 150000);
    });

    // --- 7 to 14: Keyword variations & Accent normalization ---
    test('Case 7: Keyword TỔNG CỘNG in lowercase and uppercase', () {
      const String text = 'tổng cộng: 75.000 đ';
      expect(ReceiptParser.parse(text).amount, 75000);
    });

    test('Case 8: Keyword TỔNG TIỀN', () {
      const String text = 'Tổng tiền: 85,000 VND';
      expect(ReceiptParser.parse(text).amount, 85000);
    });

    test('Case 9: Keyword THÀNH TIỀN', () {
      const String text = 'Thành tiền: 230.000';
      expect(ReceiptParser.parse(text).amount, 230000);
    });

    test('Case 10: Keyword TỔNG THANH TOÁN', () {
      const String text = 'Tổng thanh toán: 350.000 đ';
      expect(ReceiptParser.parse(text).amount, 350000);
    });

    test('Case 11: Keyword SỐ TIỀN', () {
      const String text = 'Số tiền: 500,000 VND';
      expect(ReceiptParser.parse(text).amount, 500000);
    });

    test('Case 12: Keyword TOTAL in English', () {
      const String text = 'TOTAL AMOUNT: 99.000';
      expect(ReceiptParser.parse(text).amount, 99000);
    });

    test('Case 13: Keyword AMOUNT in English', () {
      const String text = 'Amount: 120,000 VND';
      expect(ReceiptParser.parse(text).amount, 120000);
    });

    test('Case 14: Accent-less keywords (TONG CONG, THANH TIEN)', () {
      const String text = 'TONG CONG: 180.000 VND';
      expect(ReceiptParser.parse(text).amount, 180000);
    });

    // --- 15 to 17: Ignore misleading lines (VAT, Tiền khách đưa, Tiền thừa, Giảm giá) ---
    test('Case 15: Ignore VAT and THUẾ lines and pick correct total', () {
      const String text = '''
Cơm tấm Cali
Tạm tính: 100.000
VAT (10%): 10.000
Thuế GTGT: 10.000
TỔNG CỘNG: 110.000 đ
''';
      expect(ReceiptParser.parse(text).amount, 110000);
    });

    test('Case 16: Ignore TIỀN KHÁCH ĐƯA and TIỀN THỪA lines', () {
      const String text = '''
Bách Hóa Xanh
Tổng cộng: 80.000
Tiền khách đưa: 100.000
Tiền thừa trả lại: 20.000
''';
      expect(ReceiptParser.parse(text).amount, 80000);
    });

    test('Case 17: Ignore GIẢM GIÁ, CHIẾT KHẤU, and PHÍ lines', () {
      const String text = '''
Trà sữa Phúc Long
Tạm tính: 90.000
Giảm giá voucher: 20.000
Chiết khấu: 5.000
Phí dịch vụ: 5.000
Thành tiền: 70.000
''';
      expect(ReceiptParser.parse(text).amount, 70000);
    });

    // --- 18: Fallback to largest plausible amount when no keyword matches ---
    test('Case 18: Fallback to largest plausible amount without keyword line', () {
      const String text = '''
Cà phê sữa đá   35.000
Bánh croissant  45.000
80.000
''';
      expect(ReceiptParser.parse(text).amount, 80000);
    });

    // --- 19 to 21: OCR Noise Tolerance ---
    test('Case 19: Tolerate OCR noise with letter O instead of zero 0', () {
      const String text = 'TỔNG CỘNG: 15O.OOO đ';
      expect(ReceiptParser.parse(text).amount, 150000);
    });

    test('Case 20: Tolerate OCR noise with letter l or I instead of digit 1', () {
      const String text1 = 'TỔNG TIỀN: l50.000 VND';
      const String text2 = 'TỔNG TIỀN: I20.000 VND';
      expect(ReceiptParser.parse(text1).amount, 150000);
      expect(ReceiptParser.parse(text2).amount, 120000);
    });

    test('Case 21: Tolerate OCR noise with stray spaces inside digits', () {
      const String text = 'TỔNG CỘNG: 1 50. 000 đ';
      expect(ReceiptParser.parse(text).amount, 150000);
    });

    // --- 22 to 26: Date Extraction and Validation ---
    test('Case 22: Parse date DD/MM/YYYY format', () {
      const String text = 'Ngày: 25/12/2025\nTổng: 50.000';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.date, DateTime(2025, 12, 25));
    });

    test('Case 23: Parse date DD-MM-YYYY and DD.MM.YYYY formats', () {
      const String text1 = 'Ngày giao dịch: 15-08-2025';
      const String text2 = 'Ngày xuất: 10.04.2025';
      expect(ReceiptParser.parse(text1).date, DateTime(2025, 8, 15));
      expect(ReceiptParser.parse(text2).date, DateTime(2025, 4, 10));
    });

    test('Case 24: Parse date followed by time (12/10/2026 14:20)', () {
      const String text = 'Thời gian: 12/10/2026 14:20:00';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.date, DateTime(2026, 10, 12, 14, 20));
    });

    test('Case 25: Parse 2-digit year format DD/MM/YY (12/10/26)', () {
      const String text = 'Ngày: 12/10/26';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.date, DateTime(2026, 10, 12));
    });

    test('Case 26: Reject invalid calendar date (31/02/2026)', () {
      const String text = 'Ngày: 31/02/2026\nTổng cộng: 50.000';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      // Feb 31 does not exist, parser must return null rather than an erroneous date
      expect(res.date, isNull);
      expect(res.amount, 50000);
    });

    // --- 27 to 30: Vietnamese Banking Apps Transfer Texts ---
    test('Case 27: Vietcombank transfer screenshot simulated text', () {
      const String text = '''
VIETCOMBANK
Chuyển tiền thành công
Số tiền: 250,000 VND
Người nhận: NGUYEN VAN A
Ngân hàng: MB Bank
Ngày chuyển: 10/11/2025 09:30
''';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.amount, 250000);
      expect(res.merchant, 'NGUYEN VAN A');
      expect(res.date, DateTime(2025, 11, 10, 9, 30));
    });

    test('Case 28: MB Bank transfer screenshot simulated text', () {
      const String text = '''
MB BANK
Giao dịch thành công
Số tiền
180.000 VND
Tên người thụ hưởng
TRAN THI B
Thời gian
20/10/2025 15:45
''';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.amount, 180000);
      expect(res.merchant, 'TRAN THI B');
      expect(res.date, DateTime(2025, 10, 20, 15, 45));
    });

    test('Case 29: Techcombank transfer screenshot simulated text', () {
      const String text = '''
TECHCOMBANK
Chuyển nhanh Napas 247
Đến: LE HOANG C
Số tiền: 500,000 VND
Ngày thực hiện: 05/09/2025
''';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.amount, 500000);
      expect(res.merchant, 'LE HOANG C');
      expect(res.date, DateTime(2025, 9, 5));
    });

    test('Case 30: MoMo transfer simulated text', () {
      const String text = '''
MOMO
Chuyển tiền đến ví MoMo thành công
Số tiền
65.000đ
Người nhận: PHAM THI D
Thời gian: 01/08/2025 18:20
''';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.amount, 65000);
      expect(res.merchant, 'PHAM THI D');
      expect(res.date, DateTime(2025, 8, 1, 18, 20));
    });

    // --- 31 to 33: Merchant heuristics and edge cases ---
    test('Case 31: Merchant name heuristic skips HÓA ĐƠN and tax code', () {
      const String text = '''
HÓA ĐƠN BÁN HÀNG
CÔNG TY TNHH PHÚC LONG COFFEE & TEA
Địa chỉ: 123 Lê Duẩn, Đà Nẵng
Mã số thuế: 0102030405
Điện thoại: 02363123456
Tổng tiền: 65.000 đ
''';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.merchant, 'CÔNG TY TNHH PHÚC LONG COFFEE & TEA');
      expect(res.amount, 65000);
    });

    test('Case 32: Return null when amount is completely missing', () {
      const String text = '''
Highlands Coffee
Xin cảm ơn quý khách!
Hẹn gặp lại!
''';
      final ParsedReceiptResult res = ReceiptParser.parse(text);
      expect(res.amount, isNull);
    });

    test('Case 33: Empty input string returns all nulls without exception', () {
      final ParsedReceiptResult res = ReceiptParser.parse('');
      expect(res.amount, isNull);
      expect(res.date, isNull);
      expect(res.merchant, isNull);
    });
  });
}
