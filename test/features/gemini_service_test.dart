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

    test('buildSpendingPrompt includes limited data note when transactions < 3 or prev total is 0', () {
      final SpendingAggregation limitedAgg = SpendingAggregation(
        totalSpending: 50000,
        transactionCount: 2,
        categoryTotals: <String, int>{'Ăn uống': 50000},
        dailyTotals: <String, int>{'T2': 50000},
        previousWeekTotal: 0,
        weekOverWeekChangePercent: 0,
      );
      final String prompt = GeminiService.buildSpendingPrompt(limitedAgg);
      expect(prompt, contains('LƯU Ý: Dữ liệu tuần này còn ít'));
    });

    test('parseGeminiResponse successfully extracts Spending Level, summary and goals', () {
      const String fakeApiResponse = '''
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "1. Nhận xét biến động chi tiêu:\\nChi tiêu tuần này tăng 30% so với tuần trước, chủ yếu tập trung vào danh mục Thực phẩm (350.000đ).\\n\\n2. Mức độ chi tiêu: Vừa phải\\n\\n3. Mục tiêu tuần tới:\\n- Nấu ăn tại nhà để giảm chi tiêu thực phẩm.\\n- Hạn chế phát sinh các khoản di chuyển không cần thiết."
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

    test('analyzeSpending handles normal full response with mocked http client', () async {
      final http.Client mockClient = MockClient((http.Request request) async {
        expect(request.url.path, contains('gemini-3.5-flash:generateContent'));
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(request.headers['x-goog-api-key'], 'valid_fake_key');

        const String responseBody = '''
{
  "candidates": [
    {
      "finishReason": "STOP",
      "content": {
        "parts": [
          {
            "text": "1. Nhận xét biến động chi tiêu:\\nTổng chi tiêu tuần này là 650.000đ, tăng 30% so với tuần trước.\\n\\n2. Mức độ chi tiêu: Vừa phải\\n\\n3. Mục tiêu tuần tới:\\n- Nấu ăn tại nhà\\n- Giảm chi tiêu trà sữa"
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
      expect(result.spendingLevel, 'Vừa phải');
      expect(result.analysisSummary, contains('Tổng chi tiêu tuần này là 650.000đ'));
      expect(result.goals, contains('Nấu ăn tại nhà'));
      expect(result.goals, contains('Giảm chi tiêu trà sữa'));
    });

    test('analyzeSpending handles response with several parts and skips thought tokens', () async {
      final http.Client mockClient = MockClient((http.Request request) async {
        const String responseBody = '''
{
  "candidates": [
    {
      "finishReason": "STOP",
      "content": {
        "parts": [
          {
            "thought": true,
            "text": "User spent 650k, 30% increase. Level is Cao. Thinking tokens here."
          },
          {
            "text": "1. Nhận xét biến động chi tiêu:\\nChi tiêu tăng đáng kể 30%.\\n\\n2. Mức độ chi tiêu: "
          },
          {
            "text": "Cao\\n\\n3. Mục tiêu tuần tới:\\n- Cắt giảm chi tiêu không thiết yếu"
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
      expect(result.spendingLevel, 'Cao');
      expect(result.analysisSummary, isNot(contains('Thinking tokens here')));
      expect(result.analysisSummary, contains('Chi tiêu tăng đáng kể 30%'));
      expect(result.goals, contains('Cắt giảm chi tiêu không thiết yếu'));
    });

    test('analyzeSpending handles MAX_TOKENS truncation response with clear Vietnamese error and retry notice', () async {
      final http.Client mockClient = MockClient((http.Request request) async {
        const String responseBody = '''
{
  "candidates": [
    {
      "finishReason": "MAX_TOKENS",
      "content": {
        "parts": [
          {
            "text": "1. Nhận xét biến động chi tiêu:\\nTổng chi..."
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

      expect(
        () => service.analyzeSpending(sampleAgg),
        throwsA(predicate((Object? e) =>
            e is GeminiException &&
            e.message.contains('MAX_TOKENS') &&
            e.message.contains('Thử lại'))),
      );
    });

    test('analyzeSpending handles empty response with helpful Vietnamese exception', () async {
      final http.Client mockClient = MockClient((http.Request request) async {
        const String responseBody = '''
{
  "candidates": [
    {
      "finishReason": "STOP",
      "content": {
        "parts": []
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

      expect(
        () => service.analyzeSpending(sampleAgg),
        throwsA(predicate((Object? e) =>
            e is GeminiException &&
            e.message.contains('trống rỗng'))),
      );
    });

    test('analyzeSpending maps HTTP 404 Model Not Found to specific Vietnamese exception', () async {
      final http.Client mockClient = MockClient((http.Request request) async {
        return http.Response('Model not found', 404);
      });

      final GeminiService service = GeminiService(
        apiKey: 'valid_fake_key',
        connectivity: _MockConnectivity(const <ConnectivityResult>[ConnectivityResult.wifi]),
        client: mockClient,
      );

      expect(
        () => service.analyzeSpending(sampleAgg),
        throwsA(predicate((Object? e) =>
            e is GeminiException &&
            e.message ==
                'Model AI đã ngừng hoạt động hoặc đổi tên, hãy cập nhật tên model trong gemini_service.dart')),
      );
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
