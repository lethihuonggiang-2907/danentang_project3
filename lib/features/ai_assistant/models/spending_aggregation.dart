/// Pure data structure containing strictly aggregated numerical statistics.
/// Guaranteed to contain NO personal data (no images, no merchant names, no notes).
class SpendingAggregation {
  final int totalSpending;
  final int transactionCount;
  final Map<String, int> categoryTotals;
  final Map<String, int> dailyTotals;
  final int previousWeekTotal;
  final double weekOverWeekChangePercent;

  const SpendingAggregation({
    required this.totalSpending,
    required this.transactionCount,
    required this.categoryTotals,
    required this.dailyTotals,
    required this.previousWeekTotal,
    required this.weekOverWeekChangePercent,
  });

  /// Serializes into pure aggregated JSON for the AI assistant prompt.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tong_chi_tieu_vnd': totalSpending,
      'so_giao_dich': transactionCount,
      'chi_tieu_theo_danh_muc': categoryTotals,
      'chi_tieu_theo_ngay_trong_tuan': dailyTotals,
      'tong_tuan_truoc_vnd': previousWeekTotal,
      'phan_tram_thay_doi_so_voi_tuan_truoc':
          double.parse(weekOverWeekChangePercent.toStringAsFixed(1)),
    };
  }

  @override
  String toString() {
    return 'SpendingAggregation(total: $totalSpending, count: $transactionCount, change: ${weekOverWeekChangePercent.toStringAsFixed(1)}%)';
  }
}

/// Structured result returned from Gemini analysis.
class GeminiAnalysisResult {
  final String spendingLevel; // 'Thấp' | 'Vừa phải' | 'Cao'
  final String analysisSummary;
  final List<String> goals;
  final String rawResponse;

  const GeminiAnalysisResult({
    required this.spendingLevel,
    required this.analysisSummary,
    required this.goals,
    required this.rawResponse,
  });
}
