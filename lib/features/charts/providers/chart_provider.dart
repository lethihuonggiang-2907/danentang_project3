import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction_item.dart';
import '../../transactions/providers/transaction_provider.dart';

/// Notifier managing the selected week start date.
class SelectedWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime now = DateTime.now();
    // Monday of current week
    final int daysFromMonday = (now.weekday - 1);
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: daysFromMonday));
  }

  void setWeek(DateTime week) {
    state = week;
  }

  void previousWeek() {
    state = state.subtract(const Duration(days: 7));
  }

  void nextWeek() {
    state = state.add(const Duration(days: 7));
  }
}

/// Provider returning the start of the currently selected week (Monday 00:00:00).
final selectedWeekStartProvider =
    NotifierProvider<SelectedWeekNotifier, DateTime>(
  SelectedWeekNotifier.new,
);

/// Reactive category spending map derived directly from the transaction list.
/// Updates automatically on every insert/update/delete.
final categorySpendingProvider = Provider<Map<String, int>>((ref) {
  final AsyncValue<List<TransactionItem>> txState = ref.watch(transactionListProvider);
  final List<TransactionItem> items = txState.value ?? <TransactionItem>[];

  final Map<String, int> summary = <String, int>{};
  for (final TransactionItem item in items) {
    summary[item.category] = (summary[item.category] ?? 0) + item.amount;
  }
  return summary;
});

/// Reactive daily spending map for the selected 7-day week (Monday to Sunday).
final weeklySpendingProvider = Provider<Map<DateTime, int>>((ref) {
  final DateTime weekStart = ref.watch(selectedWeekStartProvider);
  final AsyncValue<List<TransactionItem>> txState = ref.watch(transactionListProvider);
  final List<TransactionItem> items = txState.value ?? <TransactionItem>[];

  final Map<DateTime, int> daily = <DateTime, int>{};
  for (int i = 0; i < 7; i++) {
    final DateTime day = weekStart.add(Duration(days: i));
    daily[day] = 0;
  }

  for (final TransactionItem item in items) {
    final DateTime itemDay = DateTime(item.date.year, item.date.month, item.date.day);
    if (daily.containsKey(itemDay)) {
      daily[itemDay] = (daily[itemDay] ?? 0) + item.amount;
    }
  }

  return daily;
});
