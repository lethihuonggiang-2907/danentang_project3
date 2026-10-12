import 'package:expense_tracker/features/transactions/screens/add_edit_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AddEditTransactionScreen validates required amount', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AddEditTransactionScreen(),
        ),
      ),
    );

    // Initial render
    expect(find.text('Thêm giao dịch'), findsOneWidget);
    expect(find.text('Số tiền (VND) *'), findsOneWidget);

    // Tap Save button without entering amount
    final Finder saveButton = find.widgetWithText(FilledButton, 'Lưu giao dịch');
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify validation error
    expect(find.text('Vui lòng nhập số tiền'), findsOneWidget);

    // Enter invalid 0 amount
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Số tiền phải lớn hơn 0'), findsOneWidget);

    // Enter valid amount
    await tester.enterText(find.byType(TextFormField).first, '150000');
    await tester.pumpAndSettle();
    expect(find.text('150000'), findsOneWidget);
  });
}
