import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction_item.dart';
import '../../../data/repositories/transaction_repository.dart';

/// Provider for accessing TransactionRepository instance.
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

/// Notifier managing the list of transactions with reactive state.
class TransactionListNotifier extends AsyncNotifier<List<TransactionItem>> {
  @override
  Future<List<TransactionItem>> build() async {
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    return await repo.getAll();
  }

  /// Adds a new transaction and refreshes list state.
  Future<int> addTransaction(TransactionItem item) async {
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    final int id = await repo.insert(item);
    ref.invalidateSelf();
    await future;
    return id;
  }

  /// Updates an existing transaction and refreshes list state.
  Future<void> updateTransaction(TransactionItem item) async {
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    await repo.update(item);
    ref.invalidateSelf();
    await future;
  }

  /// Deletes a transaction by id and refreshes list state.
  Future<void> deleteTransaction(int id) async {
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
    await future;
  }
}

/// Provider exposing the reactive transactions list state.
final transactionListProvider =
    AsyncNotifierProvider<TransactionListNotifier, List<TransactionItem>>(
  TransactionListNotifier.new,
);
