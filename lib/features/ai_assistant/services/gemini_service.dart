import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../models/spending_aggregation.dart';

/// Service managing communication with the Google Gemini REST API via plain HTTP.
class GeminiService {
  /// Designated Gemini Flash model for real-time financial assessment.
  static const String geminiModel = 'gemini-3.5-flash';

  final String _apiKey;
  final Connectivity _connectivity;
  final http.Client _client;

  GeminiService({
    String? apiKey,
    Connectivity? connectivity,
    http.Client? client,
  })  : _apiKey = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY'),
        _connectivity = connectivity ?? Connectivity(),
        _client = client ?? http.Client();

  /// Returns true if an API key has been injected via --dart-define.
  bool get hasApiKey => _apiKey.trim().isNotEmpty;

  /// Pure function: Builds Vietnamese structured instruction prompt using aggregated data only.
  /// Guaranteed to never contain images, merchant names, or notes.
  static String buildSpendingPrompt(SpendingAggregation agg) {
    final String jsonData = const JsonEncoder.withIndent('  ').convert(agg.toJson());

    return '''
Bạn là chuyên gia tư vấn tài chính cá nhân. Dưới đây là số liệu chi tiêu tổng hợp của người dùng trong tuần:

$jsonData

Hãy phân tích số liệu trên và trả lời bằng tiếng Việt theo định dạng có cấu trúc rõ ràng:
1. MỨC ĐỘ CHI TIÊU: Chọn duy nhất 1 trong 3 mức: [Thấp] hoặc [Vừa phải] hoặc [Cao].
2. NHẬN XÉT: Phân tích ngắn gọn (khoảng 3-4 câu) về biến động chi tiêu, danh mục tốn kém nhất và thay đổi so với tuần trước.
3. MỤC TIÊU TUẦN TỚI: Đưa ra 2-3 mục tiêu tài chính cụ thể, thực tế dưới dạng gạch đầu dòng (- ).

Yêu cầu: Trả lời súc tích, mang tính khích lệ, không lan man.
''';
  }

  /// Pure function: Parses raw Gemini generateContent response JSON into a GeminiAnalysisResult.
  static GeminiAnalysisResult parseGeminiResponse(String responseBody) {
    final Map<String, dynamic> decoded =
        jsonDecode(responseBody) as Map<String, dynamic>;

    final List<dynamic>? candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      final Map<String, dynamic>? promptFeedback =
          decoded['promptFeedback'] as Map<String, dynamic>?;
      if (promptFeedback != null &&
          promptFeedback['blockReason'] != null) {
        throw GeminiException(
          'Yêu cầu bị chặn bởi chính sách an toàn của Gemini: ${promptFeedback['blockReason']}',
        );
      }
      throw GeminiException('Gemini không trả về kết quả nào.');
    }

    final Map<String, dynamic> candidate =
        candidates.first as Map<String, dynamic>;
    final Map<String, dynamic>? content =
        candidate['content'] as Map<String, dynamic>?;
    final List<dynamic>? parts = content?['parts'] as List<dynamic>?;

    if (parts == null || parts.isEmpty) {
      throw GeminiException('Nội dung phản hồi từ AI trống rỗng.');
    }

    final String text = (parts.first as Map<String, dynamic>)['text'] as String? ?? '';
    if (text.trim().isEmpty) {
      throw GeminiException('Nội dung phản hồi từ AI trống rỗng.');
    }

    // Heuristic extraction of Spending Level, Summary, and Goals from structured text
    String level = 'Vừa phải';
    if (RegExp(r'\b(Thấp)\b', caseSensitive: false).hasMatch(text)) {
      level = 'Thấp';
    } else if (RegExp(r'\b(Cao)\b', caseSensitive: false).hasMatch(text)) {
      level = 'Cao';
    }

    // Extract bullet points for goals
    final List<String> goals = <String>[];
    final RegExp bulletRegex = RegExp(r'^[\-\*\•]\s+(.+)$', multiLine: true);
    for (final RegExpMatch m in bulletRegex.allMatches(text)) {
      final String g = m.group(1)?.trim() ?? '';
      if (g.isNotEmpty && !goals.contains(g)) {
        goals.add(g);
      }
    }

    return GeminiAnalysisResult(
      spendingLevel: level,
      analysisSummary: text,
      goals: goals,
      rawResponse: text,
    );
  }

  /// Calls the Gemini REST endpoint with aggregated data.
  Future<GeminiAnalysisResult> analyzeSpending(
    SpendingAggregation aggregation,
  ) async {
    // 1. Verify API Key presence
    if (!hasApiKey) {
      throw GeminiApiKeyMissingException(
        'Chưa cấu hình Gemini API Key.\n\nVui lòng chạy ứng dụng với cờ:\n--dart-define=GEMINI_API_KEY=YOUR_KEY_HERE',
      );
    }

    // 2. Check network connectivity
    final List<ConnectivityResult> connectivityResults =
        await _connectivity.checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none) ||
        connectivityResults.isEmpty) {
      throw GeminiOfflineException(
        'Thiết bị đang ngoại tuyến. Vui lòng kết nối Wi-Fi hoặc 4G/5G để sử dụng trợ lý AI.',
      );
    }

    final String prompt = buildSpendingPrompt(aggregation);
    final Uri url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent?key=$_apiKey',
    );

    final Map<String, dynamic> requestBody = <String, dynamic>{
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'parts': <Map<String, String>>[
            <String, String>{'text': prompt},
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.4,
        'maxOutputTokens': 800,
      },
    };

    try {
      final http.Response response = await _client
          .post(
            url,
            headers: <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return parseGeminiResponse(utf8.decode(response.bodyBytes));
      } else if (response.statusCode == 400) {
        throw GeminiException('Yêu cầu không hợp lệ (HTTP 400). Hãy kiểm tra lại dữ liệu.');
      } else if (response.statusCode == 404) {
        throw GeminiException(
          'Model AI đã ngừng hoạt động hoặc đổi tên, hãy cập nhật tên model trong gemini_service.dart',
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw GeminiException(
          'API Key không hợp lệ hoặc không có quyền truy cập (HTTP ${response.statusCode}).',
        );
      } else if (response.statusCode == 429) {
        throw GeminiException(
          'Đã vượt quá hạn mức yêu cầu miễn phí (HTTP 429 Quota Exceeded). Vui lòng thử lại sau vài phút.',
        );
      } else if (response.statusCode >= 500) {
        throw GeminiException(
          'Máy chủ Google Gemini đang bận hoặc gặp lỗi (HTTP ${response.statusCode}). Vui lòng thử lại sau.',
        );
      } else {
        throw GeminiException(
          'Lỗi kết nối Gemini (Mã lỗi HTTP: ${response.statusCode}).',
        );
      }
    } on TimeoutException {
      throw GeminiTimeoutException(
        'Yêu cầu phản hồi từ AI quá thời gian (15 giây). Vui lòng thử lại.',
      );
    } on SocketException {
      throw GeminiOfflineException(
        'Không thể kết nối đến máy chủ Google Gemini. Vui lòng kiểm tra lại mạng Internet.',
      );
    } catch (e) {
      if (e is GeminiException) rethrow;
      throw GeminiException('Lỗi khi gọi trợ lý AI: $e');
    }
  }
}

/// Base class for Gemini assistant exceptions.
class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);

  @override
  String toString() => message;
}

class GeminiOfflineException extends GeminiException {
  GeminiOfflineException(super.message);
}

class GeminiApiKeyMissingException extends GeminiException {
  GeminiApiKeyMissingException(super.message);
}

class GeminiTimeoutException extends GeminiException {
  GeminiTimeoutException(super.message);
}
