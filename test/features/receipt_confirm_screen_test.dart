import 'package:expense_tracker/features/extraction/receipt_parser.dart';
import 'package:expense_tracker/features/scanner/screens/receipt_confirm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ReceiptConfirmScreen renders pre-filled OCR values and latency badge',
      (WidgetTester tester) async {
    final ParsedReceiptResult parsedResult = ParsedReceiptResult(
      amount: 175000,
      date: DateTime(2026, 10, 12),
      merchant: 'Highlands Coffee',
      rawText: 'Highlands Coffee\nTổng cộng: 175.000đ\nNgày 12/10/2026',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReceiptConfirmScreen(
            parsedResult: parsedResult,
            thumbnailPath: null,
            ocrDurationMs: 82,
          ),
        ),
      ),
    );

    // Verify title and latency badge
    expect(find.text('Xác nhận thông tin hóa đơn'), findsOneWidget);
    expect(
      find.text('Thời gian nhận diện OCR: 82 ms (on-device)'),
      findsOneWidget,
    );

    // Verify pre-filled values
    expect(find.textContaining('175'), findsWidgets);
    expect(find.text('Highlands Coffee'), findsOneWidget);
    expect(find.text('12/10/2026'), findsOneWidget);

    // Verify raw OCR expansion tile is present and scroll to it
    final Finder rawTile = find.text('Xem văn bản OCR gốc');
    expect(rawTile, findsOneWidget);
    await tester.ensureVisible(rawTile);
    await tester.pumpAndSettle();

    // Tap raw OCR expansion tile
    await tester.tap(rawTile);
    await tester.pumpAndSettle();
    expect(find.textContaining('Tổng cộng: 175.000đ'), findsOneWidget);
  });
}
