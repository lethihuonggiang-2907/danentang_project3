import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../transactions/utils/category_helper.dart';
import '../geometry/chart_geometry.dart';
import '../painters/bar_chart_painter.dart';
import '../painters/donut_chart_painter.dart';
import '../painters/pie_chart_painter.dart';
import '../providers/chart_provider.dart';

enum ChartType { pie, donut, bar }

/// Interactive Charts screen offering Pie, Donut, and Weekly Bar charts rendered via CustomPainter.
class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key});

  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen>
    with SingleTickerProviderStateMixin {
  ChartType _selectedType = ChartType.pie;
  int? _selectedSliceIndex;
  int? _selectedBarIndex;

  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _switchChartType(ChartType type) {
    if (_selectedType != type) {
      setState(() {
        _selectedType = type;
        _selectedSliceIndex = null;
        _selectedBarIndex = null;
      });
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, int> categoryTotals = ref.watch(categorySpendingProvider);
    final Map<DateTime, int> dailyTotals = ref.watch(weeklySpendingProvider);
    final DateTime currentWeekStart = ref.watch(selectedWeekStartProvider);

    final int totalSpending = categoryTotals.values.fold<int>(
      0,
      (int sum, int val) => sum + val,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê chi tiêu'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Segmented Button to switch between 3 chart types
            SegmentedButton<ChartType>(
              segments: const <ButtonSegment<ChartType>>[
                ButtonSegment<ChartType>(
                  value: ChartType.pie,
                  label: Text('Tròn (Pie)'),
                  icon: Icon(Icons.pie_chart_outline),
                ),
                ButtonSegment<ChartType>(
                  value: ChartType.donut,
                  label: Text('Donut'),
                  icon: Icon(Icons.donut_large_rounded),
                ),
                ButtonSegment<ChartType>(
                  value: ChartType.bar,
                  label: Text('Tuần (Bar)'),
                  icon: Icon(Icons.bar_chart_rounded),
                ),
              ],
              selected: <ChartType>{_selectedType},
              onSelectionChanged: (Set<ChartType> newSelection) {
                _switchChartType(newSelection.first);
              },
            ),
            const SizedBox(height: 20),

            // When there is no data at all
            if (totalSpending == 0) ...<Widget>[
              Container(
                height: 280,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.insights_rounded,
                      size: 56,
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có dữ liệu chi tiêu',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hãy ghi nhận giao dịch để xem biểu đồ thống kê',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...<Widget>[
              // Chart Canvas Container
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: <Widget>[
                      if (_selectedType == ChartType.bar) ...<Widget>[
                        _buildWeekNavigator(currentWeekStart, theme),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        height: 260,
                        width: double.infinity,
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (BuildContext context, Widget? child) {
                            if (_selectedType == ChartType.pie) {
                              return _buildInteractivePieChart(categoryTotals);
                            } else if (_selectedType == ChartType.donut) {
                              return _buildInteractiveDonutChart(
                                categoryTotals,
                                totalSpending,
                                theme,
                              );
                            } else {
                              return _buildInteractiveBarChart(
                                dailyTotals,
                                theme,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedType == ChartType.bar
                            ? 'Chạm vào cột để xem chi tiết chi tiêu từng ngày'
                            : 'Chạm vào phần biểu đồ để làm nổi bật danh mục',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Selected detail card
              if (_selectedType != ChartType.bar &&
                  _selectedSliceIndex != null) ...<Widget>[
                _buildSelectedSliceCard(categoryTotals, totalSpending, theme),
                const SizedBox(height: 16),
              ],
              if (_selectedType == ChartType.bar &&
                  _selectedBarIndex != null) ...<Widget>[
                _buildSelectedBarCard(dailyTotals, theme),
                const SizedBox(height: 16),
              ],

              // Category Legend (for Pie & Donut charts)
              if (_selectedType != ChartType.bar) ...<Widget>[
                _buildCategoryLegend(categoryTotals, totalSpending, theme),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // --- Week Navigator Bar ---
  Widget _buildWeekNavigator(DateTime weekStart, ThemeData theme) {
    final DateFormat formatter = DateFormat('dd/MM');
    final DateTime weekEnd = weekStart.add(const Duration(days: 6));
    final String rangeText = '${formatter.format(weekStart)} - ${formatter.format(weekEnd)}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        IconButton(
          tooltip: 'Tuần trước',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            ref.read(selectedWeekStartProvider.notifier).previousWeek();
            _animController.reset();
            _animController.forward();
          },
        ),
        Row(
          children: <Widget>[
            Icon(Icons.date_range_rounded, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              rangeText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        IconButton(
          tooltip: 'Tuần sau',
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            ref.read(selectedWeekStartProvider.notifier).nextWeek();
            _animController.reset();
            _animController.forward();
          },
        ),
      ],
    );
  }

  // --- Interactive Pie Chart Widget ---
  Widget _buildInteractivePieChart(Map<String, int> totals) {
    final List<PieSliceGeometry> slices = ChartGeometry.computePieSlices(
      categoryTotals: totals,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        final Offset center = Offset(size.width / 2, size.height / 2);
        final double radius = min(size.width, size.height) / 2 * 0.85;

        return GestureDetector(
          onTapUp: (TapUpDetails details) {
            final int? tappedIndex = ChartGeometry.hitTestPieSlice(
              touchPoint: details.localPosition,
              center: center,
              outerRadius: radius + 10,
              slices: slices,
            );
            setState(() {
              _selectedSliceIndex = tappedIndex;
            });
          },
          child: CustomPaint(
            size: size,
            painter: PieChartPainter(
              slices: slices,
              selectedIndex: _selectedSliceIndex,
              animationProgress: _animation.value,
            ),
          ),
        );
      },
    );
  }

  // --- Interactive Donut Chart Widget ---
  Widget _buildInteractiveDonutChart(
    Map<String, int> totals,
    int totalSpending,
    ThemeData theme,
  ) {
    final List<PieSliceGeometry> slices = ChartGeometry.computePieSlices(
      categoryTotals: totals,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        final Offset center = Offset(size.width / 2, size.height / 2);
        final double radius = min(size.width, size.height) / 2 * 0.85;

        return GestureDetector(
          onTapUp: (TapUpDetails details) {
            final int? tappedIndex = ChartGeometry.hitTestPieSlice(
              touchPoint: details.localPosition,
              center: center,
              outerRadius: radius + 10,
              innerRadius: radius * 0.5,
              slices: slices,
            );
            setState(() {
              _selectedSliceIndex = tappedIndex;
            });
          },
          child: CustomPaint(
            size: size,
            painter: DonutChartPainter(
              slices: slices,
              selectedIndex: _selectedSliceIndex,
              animationProgress: _animation.value,
              totalAmount: totalSpending,
              textColor: theme.colorScheme.onSurface,
            ),
          ),
        );
      },
    );
  }

  // --- Interactive Bar Chart Widget ---
  Widget _buildInteractiveBarChart(Map<DateTime, int> daily, ThemeData theme) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        final List<BarGeometry> bars = ChartGeometry.computeBars(
          dailyTotals: daily,
          canvasSize: size,
        );

        return GestureDetector(
          onTapUp: (TapUpDetails details) {
            final int? tappedIndex = ChartGeometry.hitTestBar(
              touchPoint: details.localPosition,
              bars: bars,
            );
            setState(() {
              _selectedBarIndex = tappedIndex;
            });
          },
          child: CustomPaint(
            size: size,
            painter: BarChartPainter(
              bars: bars,
              selectedIndex: _selectedBarIndex,
              animationProgress: _animation.value,
              primaryColor: theme.colorScheme.primary,
              highlightColor: theme.colorScheme.tertiary,
              textColor: theme.colorScheme.onSurface,
            ),
          ),
        );
      },
    );
  }

  // --- Selected Slice Info Banner ---
  Widget _buildSelectedSliceCard(
    Map<String, int> totals,
    int totalSpending,
    ThemeData theme,
  ) {
    final List<PieSliceGeometry> slices = ChartGeometry.computePieSlices(
      categoryTotals: totals,
    );
    if (_selectedSliceIndex == null || _selectedSliceIndex! >= slices.length) {
      return const SizedBox.shrink();
    }

    final PieSliceGeometry slice = slices[_selectedSliceIndex!];
    final Color color = CategoryHelper.getColor(slice.label);
    final String pct = '${(slice.percentage * 100).toStringAsFixed(1)}%';

    return Card(
      color: color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CategoryHelper.getIcon(slice.label),
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    slice.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Chiếm $pct tổng chi tiêu',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.formatVND(slice.value),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Selected Bar Info Banner ---
  Widget _buildSelectedBarCard(Map<DateTime, int> daily, ThemeData theme) {
    final List<MapEntry<DateTime, int>> entries = daily.entries.toList();
    if (_selectedBarIndex == null || _selectedBarIndex! >= entries.length) {
      return const SizedBox.shrink();
    }

    final MapEntry<DateTime, int> entry = entries[_selectedBarIndex!];
    final String dateString = '${_getDayFullName(entry.key.weekday)}, ${DateFormat('dd/MM/yyyy').format(entry.key)}';

    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(Icons.calendar_today_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    dateString,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Text('Tổng chi tiêu trong ngày', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.formatVND(entry.value),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDayFullName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }

  // --- Category Legend List ---
  Widget _buildCategoryLegend(
    Map<String, int> totals,
    int totalSpending,
    ThemeData theme,
  ) {
    final List<PieSliceGeometry> slices = ChartGeometry.computePieSlices(
      categoryTotals: totals,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Danh mục chi tiêu',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slices.length,
          separatorBuilder: (BuildContext context, int index) => const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            final PieSliceGeometry slice = slices[index];
            final Color color = CategoryHelper.getColor(slice.label);
            final bool isSelected = _selectedSliceIndex == index;
            final String pct = '${(slice.percentage * 100).toStringAsFixed(1)}%';

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedSliceIndex = isSelected ? null : index;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        slice.label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      pct,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      CurrencyFormatter.formatVND(slice.value),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
