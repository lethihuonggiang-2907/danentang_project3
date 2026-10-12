import 'package:expense_tracker/data/models/transaction_item.dart';
import 'package:expense_tracker/features/charts/screens/charts_screen.dart';
import 'package:expense_tracker/features/transactions/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChartsScreen renders empty state when no transactions exist',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ChartsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thống kê chi tiêu'), findsOneWidget);
    expect(find.text('Chưa có dữ liệu chi tiêu'), findsOneWidget);
  });

  testWidgets(
      'ChartsScreen renders CustomPaint, switches between Pie/Donut/Bar, and interacts with tap',
      (WidgetTester tester) async {
    final List<TransactionItem> mockTransactions = <TransactionItem>[
      TransactionItem(
        id: 1,
        amount: 250000,
        date: DateTime.now(),
        merchant: 'Siêu thị Co.opmart',
        category: 'Thực phẩm',
        createdAt: DateTime.now(),
      ),
      TransactionItem(
        id: 2,
        amount: 100000,
        date: DateTime.now(),
        merchant: 'Nhà sách Phương Nam',
        category: 'Học tập',
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionListProvider.overrideWith(
            () => _MockTransactionListNotifier(mockTransactions),
          ),
        ],
        child: const MaterialApp(
          home: ChartsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify CustomPaint is present for Pie Chart
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Danh mục chi tiêu'), findsOneWidget);
    expect(find.text('Thực phẩm'), findsWidgets);
    expect(find.text('Học tập'), findsWidgets);

    // Tap SegmentedButton to switch to Donut
    await tester.tap(find.text('Donut'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);

    // Tap SegmentedButton to switch to Bar
    await tester.tap(find.text('Tuần (Bar)'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Chạm vào cột để xem chi tiết chi tiêu từng ngày'), findsOneWidget);

    // Tap on the CustomPaint canvas in Bar chart
    final Finder customPaintFinder = find.byType(CustomPaint).first;
    await tester.tap(customPaintFinder);
    await tester.pumpAndSettle();
  });
}

class _MockTransactionListNotifier extends AsyncNotifier<List<TransactionItem>>
    implements TransactionListNotifier {
  final List<TransactionItem> _initialData;

  _MockTransactionListNotifier(this._initialData);

  @override
  Future<List<TransactionItem>> build() async {
    return _initialData;
  }

  @override
  Future<int> addTransaction(TransactionItem item) async => 1;

  @override
  Future<void> updateTransaction(TransactionItem item) async {}

  @override
  Future<void> deleteTransaction(int id) async {}
}
