import 'package:intl/intl.dart';

/// Formatter for Vietnamese Dong (VND)
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _vndFormat = NumberFormat('#,###', 'vi_VN');

  /// Formats an integer amount as VND with thousand separators (e.g. 150.000 ₫)
  static String formatVND(int amount) {
    return '${_vndFormat.format(amount)} ₫';
  }
}
