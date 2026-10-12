/// Data model representing a single expense transaction.
class TransactionItem {
  final int? id;
  final int amount; // Amount in VND (integer, no decimals)
  final DateTime date;
  final String? merchant;
  final String category;
  final String? note;
  final String? thumbnailPath;
  final DateTime createdAt;

  const TransactionItem({
    this.id,
    required this.amount,
    required this.date,
    this.merchant,
    required this.category,
    this.note,
    this.thumbnailPath,
    required this.createdAt,
  });

  /// Creates a copy with optionally replaced properties.
  TransactionItem copyWith({
    int? id,
    int? amount,
    DateTime? date,
    String? merchant,
    String? category,
    String? note,
    String? thumbnailPath,
    DateTime? createdAt,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      note: note ?? this.note,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Converts model to Map for SQLite storage.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'merchant': merchant,
      'category': category,
      'note': note,
      'thumbnail_path': thumbnailPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates model from SQLite Map row.
  factory TransactionItem.fromMap(Map<String, Object?> map) {
    return TransactionItem(
      id: map['id'] as int?,
      amount: map['amount'] as int,
      date: DateTime.parse(map['date'] as String),
      merchant: map['merchant'] as String?,
      category: map['category'] as String,
      note: map['note'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'TransactionItem(id: $id, amount: $amount, date: $date, merchant: $merchant, category: $category)';
  }
}
