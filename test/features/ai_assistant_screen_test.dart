import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:expense_tracker/features/ai_assistant/models/spending_aggregation.dart';
import 'package:expense_tracker/features/ai_assistant/screens/ai_assistant_screen.dart';
import 'package:expense_tracker/features/ai_assistant/services/gemini_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AiAssistantScreen renders summary and handles unconfigured API key gracefully',
      (WidgetTester tester) async {
    final GeminiService mockService = GeminiService(
      apiKey: '', // Empty key to test missing key handling
      connectivity: _FakeConnectivity(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AiAssistantScreen(geminiService: mockService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trợ lý AI Gemini'), findsOneWidget);
    expect(find.text('Dữ liệu tổng hợp tuần này:'), findsOneWidget);
    expect(find.text('Phân tích chi tiêu với AI'), findsOneWidget);

    // Tap analyze
    await tester.tap(find.text('Phân tích chi tiêu với AI'));
    await tester.pumpAndSettle();

    // Verify error card appears with helpful message instead of crashing
    expect(find.text('Không thể kết nối trợ lý AI'), findsOneWidget);
    expect(find.textContaining('Chưa cấu hình Gemini API Key'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('AiAssistantScreen renders analysis result upon successful response',
      (WidgetTester tester) async {
    final GeminiService mockService = _MockSuccessGeminiService();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AiAssistantScreen(geminiService: mockService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap analyze
    await tester.tap(find.text('Phân tích chi tiêu với AI'));
    await tester.pumpAndSettle();

    // Verify rating badge and results appear
    expect(find.text('Đánh giá mức độ chi tiêu:'), findsOneWidget);
    expect(find.text('Vừa phải'), findsOneWidget);
    expect(find.textContaining('Chi tiêu tuần này ổn định'), findsOneWidget);
    expect(find.textContaining('Tiết kiệm 10%'), findsOneWidget);
  });
}

class _FakeConnectivity implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      <ConnectivityResult>[ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream<List<ConnectivityResult>>.value(<ConnectivityResult>[ConnectivityResult.wifi]);
}

class _MockSuccessGeminiService extends GeminiService {
  _MockSuccessGeminiService() : super(apiKey: 'dummy_key');

  @override
  Future<GeminiAnalysisResult> analyzeSpending(SpendingAggregation aggregation) async {
    return const GeminiAnalysisResult(
      spendingLevel: 'Vừa phải',
      analysisSummary: 'Chi tiêu tuần này ổn định so với tuần trước.',
      goals: <String>['Tiết kiệm 10% thu nhập', 'Giảm ăn ngoài'],
      rawResponse: 'Raw text',
    );
  }
}
