import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:expense_tracker/features/ai_assistant/models/spending_aggregation.dart';
import 'package:expense_tracker/features/ai_assistant/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GeminiService Pure Functions & Logic Tests', () {
    final SpendingAggregation sampleAgg = SpendingAggregation(
      totalSpending: 650000,
      transactionCount: 8,
      categoryTotals: <String, int>{
        'Thực phẩm': 350000,
        'Học tập': 200000,
        'Di chuyển': 100000,
      },
      dailyTotals: <String, int>{
        'T2': 150000,
        'T3': 100000,
        'T4': 50000,
        'T5': 200000,
        'T6': 150000,
        'T7': 0,
        'CN': 0,
      },
      previousWeekTotal: 500000,
      weekOverWeekChangePercent: 30.0,
    );

    test('buildSpendingPrompt produces structured Vietnamese prompt with aggregated stats only', () {
      final String prompt = GeminiService.buildSpendingPrompt(sampleAgg);

      // Verify aggregated stats are present
      expect(prompt, contains('650000'));
      expect(prompt, contains('Thực phẩm'));
      expect(prompt, contains('350000'));
      expect(prompt, contains('30.0'));

      // Verify prompt NEVER contains personal fields
      expect(prompt, isNot(contains('merchant')));
      expect(prompt, isNot(contains('thumbnail')));
      expect(prompt, isNot(contains('Circle K')));
      expect(prompt, isNot(contains('Highlands')));
    });

    test('parseGeminiResponse successfully extracts Spending Level, summary and goals', () {
      const String fakeApiResponse = '''
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "1. MỨC ĐỘ CHI TIÊU: Vừa phải\\n2. NHẬN XÉT: Chi tiêu tuần này tăng 30% so với tuần trước, chủ yếu tập trung vào danh mục Thực phẩm (350.000đ).\\n3. MỤC TIÊU TUẦN TỚI:\\n- Nấu ăn tại nhà để giảm chi tiêu thực phẩm.\\n- Hạn chế phát sinh các khoản di chuyển không cần thiết."
          }
        ]
      }
    }
  ]
}
''';

      final GeminiAnalysisResult res = GeminiService.parseGeminiResponse(fakeApiResponse);

      expect(res.spendingLevel, 'Vừa phải');
      expect(res.analysisSummary, contains('Chi tiêu tuần này tăng 30%'));
      expect(res.goals.length, 2);
      expect(res.goals[0], contains('Nấu ăn tại nhà'));
      expect(res.goals[1], contains('Hạn chế phát sinh'));
    });

    test('parseGeminiResponse throws on empty candidates', () {
      const String emptyResponse = '{"candidates": []}';
      expect(
        () => GeminiService.parseGeminiResponse(emptyResponse),
        throwsA(isA<GeminiException>()),
      );
    });

    test('parseGeminiResponse throws on safety blocked response', () {
      const String blockedResponse = '''
{
  "promptFeedback": {
    "blockReason": "SAFETY"
  }
}
''';
      expect(
        () => GeminiService.parseGeminiResponse(blockedResponse),
        throwsA(isA<GeminiException>()),
      );
    });

    test('analyzeSpending throws GeminiApiKeyMissingException when key is empty', () async {
      final GeminiService service = GeminiService(
        apiKey: '',
        connectivity: _MockConnectivity(const <ConnectivityResult>[ConnectivityResult.wifi]),
      );

      expect(
        () => service.analyzeSpending(sampleAgg),
        throwsA(isA<GeminiApiKeyMissingException>()),
      );
    });

    test('analyzeSpending throws GeminiOfflineException when device is offline', () async {
      final GeminiService service = GeminiService(
        apiKey: 'fake_api_key_123',
        connectivity: _MockConnectivity(const <ConnectivityResult>[ConnectivityResult.none]),
      );

      expect(
        () => service.analyzeSpending(sampleAgg),
        throwsA(isA<GeminiOfflineException>()),
      );
    });

    test('analyzeSpending handles 200 OK HTTP response with mock client', () async {
      final http.Client mockClient = MockClient((http.Request request) async {
        expect(request.url.path, contains('gemini-1.5-flash:generateContent'));
        expect(request.headers['Content-Type'], contains('application/json'));

        const String responseBody = '''
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "1. MỨC ĐỘ CHI TIÊU: Thấp\\n2. NHẬN XÉT: Chi tiêu được kiểm soát rất tốt.\\n3. MỤC TIÊU TUẦN TỚI:\\n- Tiếp tục duy trì thói quen tiết kiệm."
          }
        ]
      }
    }
  ]
}
''';
        return http.Response(responseBody, 200, headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final GeminiService service = GeminiService(
        apiKey: 'valid_fake_key',
        connectivity: _MockConnectivity(const <ConnectivityResult>[ConnectivityResult.wifi]),
        client: mockClient,
      );

      final GeminiAnalysisResult result = await service.analyzeSpending(sampleAgg);
      expect(result.spendingLevel, 'Thấp');
      expect(result.goals.length, 1);
    });

    test('analyzeSpending maps HTTP 429 Quota Exceeded to user-friendly exception', () async {
      final http.Client mockClient = MockClient((http.Request request) async {
        return http.Response('Quota Exceeded', 429);
      });

      final GeminiService service = GeminiService(
        apiKey: 'valid_fake_key',
        connectivity: _MockConnectivity(const <ConnectivityResult>[ConnectivityResult.wifi]),
        client: mockClient,
      );

      expect(
        () => service.analyzeSpending(sampleAgg),
        throwsA(predicate((Object? e) => e is GeminiException && e.message.contains('429'))),
      );
    });

    test('analyzeSpending maps HTTP 401 Unauthorized to user-friendly exception', () async {
      final http.Client mockClient = MockClient((http.Request request) async {
        return http.Response('Invalid API Key', 401);
      });

      final GeminiService service = GeminiService(
        apiKey: 'invalid_key',
        connectivity: _MockConnectivity(const <ConnectivityResult>[ConnectivityResult.wifi]),
        client: mockClient,
      );

      expect(
        () => service.analyzeSpending(sampleAgg),
        throwsA(predicate((Object? e) => e is GeminiException && e.message.contains('401'))),
      );
    });
  });
}

class _MockConnectivity implements Connectivity {
  final List<ConnectivityResult> _results;
  _MockConnectivity(this._results);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _results;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream<List<ConnectivityResult>>.value(_results);
}
