import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/data/models/transaction_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransactionItem Model Tests', () {
    test('toMap and fromMap preserves all fields correctly', () {
      final DateTime testDate = DateTime(2026, 10, 12, 14, 30);
      final DateTime createdDate = DateTime(2026, 10, 12, 14, 0);

      final TransactionItem item = TransactionItem(
        id: 1,
        amount: 150000,
        date: testDate,
        merchant: 'Circle K',
        category: 'Thực phẩm',
        note: 'Bánh mì & cà phê',
        thumbnailPath: '/path/to/thumb.jpg',
        createdAt: createdDate,
      );

      final Map<String, Object?> map = item.toMap();
      expect(map['id'], 1);
      expect(map['amount'], 150000);
      expect(map['merchant'], 'Circle K');
      expect(map['category'], 'Thực phẩm');
      expect(map['note'], 'Bánh mì & cà phê');
      expect(map['thumbnail_path'], '/path/to/thumb.jpg');
      expect(map['date'], testDate.toIso8601String());
      expect(map['created_at'], createdDate.toIso8601String());

      final TransactionItem restored = TransactionItem.fromMap(map);
      expect(restored.id, 1);
      expect(restored.amount, 150000);
      expect(restored.date, testDate);
      expect(restored.merchant, 'Circle K');
      expect(restored.category, 'Thực phẩm');
      expect(restored.note, 'Bánh mì & cà phê');
      expect(restored.thumbnailPath, '/path/to/thumb.jpg');
      expect(restored.createdAt, createdDate);
    });

    test('copyWith updates specified fields only', () {
      final TransactionItem original = TransactionItem(
        id: 1,
        amount: 50000,
        date: DateTime(2026, 10, 10),
        merchant: 'Highlands Coffee',
        category: 'Thực phẩm',
        createdAt: DateTime(2026, 10, 10),
      );

      final TransactionItem updated = original.copyWith(
        amount: 65000,
        merchant: 'Highlands Coffee Vincom',
      );

      expect(updated.id, 1);
      expect(updated.amount, 65000);
      expect(updated.merchant, 'Highlands Coffee Vincom');
      expect(updated.category, 'Thực phẩm');
    });

    test('CurrencyFormatter formats VND correctly with thousand separators', () {
      expect(CurrencyFormatter.formatVND(0), '0 ₫');
      expect(CurrencyFormatter.formatVND(150000), '150.000 ₫');
      expect(CurrencyFormatter.formatVND(1250000), '1.250.000 ₫');
      expect(CurrencyFormatter.formatVND(99000000), '99.000.000 ₫');
    });
  });
}
