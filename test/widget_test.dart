import 'package:expense_tracker/features/home/home_screen.dart';
import 'package:expense_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders HomeScreen and allows tab navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ExpenseTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify HomeScreen is rendered with Title
    expect(find.text('Expense Tracker'), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);

    // Verify bottom navigation items and app bars
    expect(find.text('Giao dịch'), findsOneWidget);
    expect(find.text('Giao dịch chi tiêu'), findsOneWidget);
    expect(find.text('Thống kê'), findsOneWidget);
    expect(find.text('Quét đơn'), findsOneWidget);
    expect(find.text('Trợ lý AI'), findsOneWidget);

    // Tap on "Thống kê"
    await tester.tap(find.text('Thống kê'));
    await tester.pumpAndSettle();
    expect(find.text('Tròn (Pie)'), findsOneWidget);

    // Tap on "Quét đơn"
    await tester.tap(find.text('Quét đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn ảnh từ thư viện'), findsOneWidget);

    // Tap on "Trợ lý AI"
    await tester.tap(find.text('Trợ lý AI'));
    await tester.pumpAndSettle();
    expect(find.text('Trợ lý Gemini AI'), findsOneWidget);

    // Tap theme toggle button
    final Finder themeToggle = find.byType(IconButton);
    expect(themeToggle, findsOneWidget);
    await tester.tap(themeToggle);
    await tester.pumpAndSettle();
  });
}
