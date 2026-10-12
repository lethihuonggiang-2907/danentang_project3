/// App-wide constants for Expense Tracker
class AppConstants {
  AppConstants._();

  static const String appName = 'Expense Tracker';

  /// Standard expense categories required by project specifications:
  /// Thực phẩm, Học tập, Du lịch, Di chuyển, Giải trí, Sức khỏe, Khác.
  static const List<String> defaultCategories = <String>[
    'Thực phẩm',
    'Học tập',
    'Du lịch',
    'Di chuyển',
    'Giải trí',
    'Sức khỏe',
    'Khác',
  ];
}
