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
    final String jsonData =
        const JsonEncoder.withIndent('  ').convert(agg.toJson());
    final bool isDataLimited =
        agg.transactionCount < 3 || agg.previousWeekTotal == 0;
    final String dataNote = isDataLimited
        ? '\nLƯU Ý: Dữ liệu tuần này còn ít (dưới 3 giao dịch hoặc chưa có dữ liệu tuần trước để đối chiếu), hãy đưa ra nhận xét ngắn gọn mang tính tham khảo và khích lệ người dùng tiếp tục ghi chép chi tiêu.\n'
        : '';

    return '''
Bạn là chuyên gia tư vấn quản lý tài chính cá nhân. Dưới đây là số liệu chi tiêu tổng hợp của người dùng trong tuần:

$jsonData$dataNote
Hãy phân tích số liệu trên và trả lời hoàn toàn bằng tiếng Việt theo đúng cấu trúc 3 phần sau (không dùng tiếng Anh, không lặp lại lời nhắc hướng dẫn):

1. Nhận xét biến động chi tiêu:
(Nhận xét súc tích về tổng chi tiêu, danh mục tốn kém nhất và thay đổi so với tuần trước)

2. Mức độ chi tiêu: Thấp / Vừa phải / Cao
(Ghi rõ một trong ba từ: Thấp, Vừa phải, hoặc Cao)

3. Mục tiêu tuần tới:
- [Mục tiêu 1]
- [Mục tiêu 2]
- [Mục tiêu 3]

Yêu cầu bắt buộc:
- Toàn bộ câu trả lời bằng tiếng Việt, tuyệt đối không dùng bất kỳ tiêu đề hoặc chú thích tiếng Anh nào.
- Trả lời ngắn gọn, súc tích (dưới 150 từ), thiết thực và mang tính khích lệ.
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

    // Inspect finishReason on the primary candidate
    final Map<String, dynamic> firstCandidate =
        candidates.first as Map<String, dynamic>;
    final String? finishReason = firstCandidate['finishReason'] as String?;
    if (finishReason == 'MAX_TOKENS') {
      throw GeminiException(
        'Câu trả lời bị ngắt quãng do vượt quá hạn mức token (MAX_TOKENS). Vui lòng nhấn Thử lại.',
      );
    }
    if (finishReason == 'SAFETY') {
      throw GeminiException(
        'Nội dung phân tích bị chặn bởi bộ lọc an toàn của AI (SAFETY). Vui lòng nhấn Thử lại.',
      );
    }

    // Concatenate text from ALL parts of ALL candidates (skipping thought summaries)
    final StringBuffer textBuffer = StringBuffer();

    for (final dynamic cand in candidates) {
      if (cand is! Map<String, dynamic>) continue;
      final Map<String, dynamic>? content =
          cand['content'] as Map<String, dynamic>?;
      final List<dynamic>? parts = content?['parts'] as List<dynamic>?;
      if (parts == null) continue;

      for (final dynamic part in parts) {
        if (part is! Map<String, dynamic>) continue;

        // Skip thought parts if present
        final bool isThought = part['thought'] == true ||
            part['isThought'] == true;
        if (isThought) continue;

        final String? partText = part['text'] as String?;
        if (partText != null && partText.isNotEmpty) {
          textBuffer.write(partText);
        }
      }
    }

    final String text = textBuffer.toString().trim();
    if (text.isEmpty) {
      throw GeminiException('Nội dung phản hồi từ AI trống rỗng.');
    }

    // Extract Spending Level: 'Thấp' | 'Vừa phải' | 'Cao'
    String level = 'Vừa phải';
    final RegExp levelRegex = RegExp(
      r'Mức độ chi tiêu[:\s*]+.*?\b(Thấp|Vừa phải|Cao)\b',
      caseSensitive: false,
    );
    final RegExpMatch? levelMatch = levelRegex.firstMatch(text);
    if (levelMatch != null) {
      final String raw = levelMatch.group(1)!.toLowerCase();
      if (raw == 'thấp') {
        level = 'Thấp';
      } else if (raw == 'cao') {
        level = 'Cao';
      } else {
        level = 'Vừa phải';
      }
    } else {
      if (RegExp(r'\b(Thấp)\b', caseSensitive: false).hasMatch(text)) {
        level = 'Thấp';
      } else if (RegExp(r'\b(Cao)\b', caseSensitive: false).hasMatch(text)) {
        level = 'Cao';
      }
    }

    // Extract bullet points for goals
    final List<String> goals = <String>[];
    final RegExp bulletRegex = RegExp(r'^\s*[\-\*\•]\s+(.+)$', multiLine: true);
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
        'maxOutputTokens': 4096,
        'thinkingConfig': <String, dynamic>{
          'thinkingBudget': 1024,
        },
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
