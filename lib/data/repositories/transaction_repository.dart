import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/transaction_item.dart';

/// Repository interface and implementation for Transaction persistence.
class TransactionRepository {
  final DatabaseHelper _dbHelper;

  TransactionRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Inserts a new transaction into the database. Returns newly generated id.
  Future<int> insert(TransactionItem item) async {
    final Database db = await _dbHelper.database;
    return await db.insert(
      DatabaseHelper.tableTransactions,
      item.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an existing transaction.
  Future<int> update(TransactionItem item) async {
    final Database db = await _dbHelper.database;
    return await db.update(
      DatabaseHelper.tableTransactions,
      item.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[item.id],
    );
  }

  /// Deletes a transaction by id and removes associated thumbnail file if exists.
  Future<int> delete(int id) async {
    final Database db = await _dbHelper.database;

    // Check if item has a thumbnail and delete the physical file
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseHelper.tableTransactions,
      columns: <String>['thumbnail_path'],
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final String? thumbPath = rows.first['thumbnail_path'] as String?;
      if (thumbPath != null && thumbPath.isNotEmpty) {
        try {
          final File file = File(thumbPath);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {
          // Ignore file cleanup failure if file already removed
        }
      }
    }

    return await db.delete(
      DatabaseHelper.tableTransactions,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Retrieves all transactions ordered by date descending.
  Future<List<TransactionItem>> getAll() async {
    final Database db = await _dbHelper.database;
    final List<Map<String, Object?>> maps = await db.query(
      DatabaseHelper.tableTransactions,
      orderBy: 'date DESC, id DESC',
    );
    return maps.map(TransactionItem.fromMap).toList();
  }

  /// Retrieves a transaction by its id.
  Future<TransactionItem?> getById(int id) async {
    final Database db = await _dbHelper.database;
    final List<Map<String, Object?>> maps = await db.query(
      DatabaseHelper.tableTransactions,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return TransactionItem.fromMap(maps.first);
  }

  /// Retrieves transactions within a specific date range [start, end].
  Future<List<TransactionItem>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final Database db = await _dbHelper.database;
    final List<Map<String, Object?>> maps = await db.query(
      DatabaseHelper.tableTransactions,
      where: 'date >= ? AND date <= ?',
      whereArgs: <Object?>[start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map(TransactionItem.fromMap).toList();
  }

  /// Aggregates total expense sum grouped by category.
  Future<Map<String, int>> sumByCategory({
    DateTime? start,
    DateTime? end,
  }) async {
    final Database db = await _dbHelper.database;
    String? whereClause;
    List<Object?>? whereArgs;

    if (start != null && end != null) {
      whereClause = 'date >= ? AND date <= ?';
      whereArgs = <Object?>[start.toIso8601String(), end.toIso8601String()];
    }

    final List<Map<String, Object?>> results = await db.query(
      DatabaseHelper.tableTransactions,
      columns: <String>['category', 'SUM(amount) as total_amount'],
      where: whereClause,
      whereArgs: whereArgs,
      groupBy: 'category',
      orderBy: 'total_amount DESC',
    );

    final Map<String, int> summary = <String, int>{};
    for (final Map<String, Object?> row in results) {
      final String category = row['category'] as String;
      final int total = (row['total_amount'] as num?)?.toInt() ?? 0;
      summary[category] = total;
    }
    return summary;
  }

  /// Aggregates total expense sum per day for a 7-day week starting at [weekStart].
  /// Returns a map of DateTime (midnight) to sum in VND.
  Future<Map<DateTime, int>> sumByDayForWeek(DateTime weekStart) async {
    // Normalize weekStart to start of day (00:00:00)
    final DateTime normalizedStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    // End of 7-day period (23:59:59.999 of 7th day)
    final DateTime normalizedEnd = normalizedStart.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );

    final List<TransactionItem> items = await getByDateRange(
      normalizedStart,
      normalizedEnd,
    );

    // Initialize 7 days with 0
    final Map<DateTime, int> dailyTotals = <DateTime, int>{};
    for (int i = 0; i < 7; i++) {
      final DateTime day = normalizedStart.add(Duration(days: i));
      dailyTotals[day] = 0;
    }

    for (final TransactionItem item in items) {
      final DateTime itemDay = DateTime(
        item.date.year,
        item.date.month,
        item.date.day,
      );
      if (dailyTotals.containsKey(itemDay)) {
        dailyTotals[itemDay] = (dailyTotals[itemDay] ?? 0) + item.amount;
      }
    }

    return dailyTotals;
  }
}
