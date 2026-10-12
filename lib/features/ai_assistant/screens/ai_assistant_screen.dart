import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_item.dart';
import '../../charts/providers/chart_provider.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../models/spending_aggregation.dart';
import '../services/gemini_service.dart';

/// Screen for the Gemini AI Financial Assistant.
class AiAssistantScreen extends ConsumerStatefulWidget {
  final GeminiService? geminiService;

  const AiAssistantScreen({
    super.key,
    this.geminiService,
  });

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  late final GeminiService _service;
  bool _isLoading = false;
  GeminiAnalysisResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.geminiService ?? GeminiService();
  }

  Future<void> _analyze(SpendingAggregation aggregation) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GeminiAnalysisResult res = await _service.analyzeSpending(aggregation);
      setState(() {
        _result = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  SpendingAggregation _computeAggregation(
    List<TransactionItem> allItems,
    DateTime weekStart,
  ) {
    final DateTime weekEnd = weekStart.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );

    // Current week items
    final List<TransactionItem> currentWeekItems = allItems.where((TransactionItem item) {
      return item.date.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
          item.date.isBefore(weekEnd.add(const Duration(seconds: 1)));
    }).toList();

    // Previous week items (for week-over-week comparison)
    final DateTime prevWeekStart = weekStart.subtract(const Duration(days: 7));
    final DateTime prevWeekEnd = weekStart.subtract(const Duration(seconds: 1));
    final List<TransactionItem> prevWeekItems = allItems.where((TransactionItem item) {
      return item.date.isAfter(prevWeekStart.subtract(const Duration(seconds: 1))) &&
          item.date.isBefore(prevWeekEnd.add(const Duration(seconds: 1)));
    }).toList();

    final int currentTotal = currentWeekItems.fold<int>(
      0,
      (int sum, TransactionItem item) => sum + item.amount,
    );

    final int prevTotal = prevWeekItems.fold<int>(
      0,
      (int sum, TransactionItem item) => sum + item.amount,
    );

    final double wowChange;
    if (prevTotal > 0) {
      wowChange = ((currentTotal - prevTotal) / prevTotal) * 100.0;
    } else {
      wowChange = currentTotal > 0 ? 100.0 : 0.0;
    }

    final Map<String, int> catTotals = <String, int>{};
    for (final TransactionItem item in currentWeekItems) {
      catTotals[item.category] = (catTotals[item.category] ?? 0) + item.amount;
    }

    final Map<String, int> dailyTotals = <String, int>{};
    const List<String> dayNames = <String>['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    for (int i = 0; i < 7; i++) {
      dailyTotals[dayNames[i]] = 0;
    }
    for (final TransactionItem item in currentWeekItems) {
      final int dayIdx = item.date.weekday - 1;
      if (dayIdx >= 0 && dayIdx < 7) {
        final String dayName = dayNames[dayIdx];
        dailyTotals[dayName] = (dailyTotals[dayName] ?? 0) + item.amount;
      }
    }

    return SpendingAggregation(
      totalSpending: currentTotal,
      transactionCount: currentWeekItems.length,
      categoryTotals: catTotals,
      dailyTotals: dailyTotals,
      previousWeekTotal: prevTotal,
      weekOverWeekChangePercent: wowChange,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime currentWeekStart = ref.watch(selectedWeekStartProvider);
    final AsyncValue<List<TransactionItem>> txAsync = ref.watch(transactionListProvider);
    final List<TransactionItem> allItems = txAsync.value ?? <TransactionItem>[];

    final SpendingAggregation agg = _computeAggregation(allItems, currentWeekStart);

    final DateFormat dateFmt = DateFormat('dd/MM');
    final String rangeText =
        '${dateFmt.format(currentWeekStart)} - ${dateFmt.format(currentWeekStart.add(const Duration(days: 6)))}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ lý AI Gemini'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Week Selector Bar
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () {
                        ref.read(selectedWeekStartProvider.notifier).previousWeek();
                        setState(() {
                          _result = null;
                          _errorMessage = null;
                        });
                      },
                    ),
                    Row(
                      children: <Widget>[
                        Icon(Icons.calendar_month_rounded,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Tuần: $rangeText',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () {
                        ref.read(selectedWeekStartProvider.notifier).nextWeek();
                        setState(() {
                          _result = null;
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Summary Stats Pill
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Dữ liệu tổng hợp tuần này:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _buildStatItem('Tổng chi tiêu', CurrencyFormatter.formatVND(agg.totalSpending)),
                      _buildStatItem('Số giao dịch', '${agg.transactionCount} đơn'),
                      _buildStatItem(
                        'So tuần trước',
                        agg.previousWeekTotal == 0
                            ? '--'
                            : '${agg.weekOverWeekChangePercent >= 0 ? '+' : ''}${agg.weekOverWeekChangePercent.toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Privacy Disclosure
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.shield_outlined, size: 18, color: Colors.blue.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bảo mật: Chỉ gửi số liệu thống kê tổng hợp (tổng tiền, danh mục, ngày). Tuyệt đối không gửi ảnh, tên quán hoặc ghi chú.',
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Analyze Action Button
            FilledButton.icon(
              onPressed: _isLoading ? null : () => _analyze(agg),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                _isLoading ? 'Đang phân tích cùng Gemini...' : 'Phân tích chi tiêu với AI',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),

            // Error Display Card
            if (_errorMessage != null) ...<Widget>[
              Card(
                color: Colors.red.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.red.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Không thể kết nối trợ lý AI',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonal(
                        onPressed: () => _analyze(agg),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Analysis Result Display Card
            if (_result != null) ...<Widget>[
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Spending Rating Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text(
                            'Đánh giá mức độ chi tiêu:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          _buildLevelBadge(_result!.spendingLevel),
                        ],
                      ),
                      const Divider(height: 28),

                      // AI Remarks
                      Text(
                        'Nhận xét từ Gemini (${GeminiService.geminiModel}):',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _result!.analysisSummary,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 20),

                      // Financial Goals
                      if (_result!.goals.isNotEmpty) ...<Widget>[
                        Text(
                          'Mục tiêu gợi ý cho tuần tới:',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._result!.goals.map(
                          (String goal) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text('🎯 ', style: TextStyle(fontSize: 14)),
                                Expanded(
                                  child: Text(
                                    goal,
                                    style: const TextStyle(fontSize: 13, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildLevelBadge(String level) {
    Color bg;
    Color fg;
    switch (level) {
      case 'Thấp':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case 'Cao':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        break;
      case 'Vừa phải':
      default:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        level,
        style: TextStyle(fontWeight: FontWeight.bold, color: fg, fontSize: 13),
      ),
    );
  }
}
