import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Database helper singleton to manage SQLite connection and schema.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _databaseName = 'expense_tracker.db';
  static const int _databaseVersion = 1;

  static const String tableTransactions = 'transactions';

  Database? _database;

  /// Returns active Database instance, creating or opening it if necessary.
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String dbPath = await getDatabasesPath();
    final String path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Schema creation for transactions table
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTransactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        merchant TEXT,
        category TEXT NOT NULL,
        note TEXT,
        thumbnail_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Create index on date for fast chronological and range querying
    await db.execute('''
      CREATE INDEX idx_transactions_date ON $tableTransactions (date)
    ''');
  }

  /// Migration stub for future schema upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // When upgrading schema versions, apply incremental alterations here
    // Example:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE $tableTransactions ADD COLUMN tags TEXT;');
    // }
  }

  /// Closes database connection (useful during testing or reset)
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
