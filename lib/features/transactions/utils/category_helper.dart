import 'package:flutter/material.dart';

/// Helper mapping categories to distinctive icons and curated colors.
class CategoryHelper {
  CategoryHelper._();

  static IconData getIcon(String category) {
    switch (category) {
      case 'Thực phẩm':
        return Icons.restaurant_rounded;
      case 'Học tập':
        return Icons.menu_book_rounded;
      case 'Du lịch':
        return Icons.flight_takeoff_rounded;
      case 'Di chuyển':
        return Icons.directions_car_rounded;
      case 'Giải trí':
        return Icons.sports_esports_rounded;
      case 'Sức khỏe':
        return Icons.favorite_rounded;
      case 'Khác':
      default:
        return Icons.category_rounded;
    }
  }

  static Color getColor(String category) {
    switch (category) {
      case 'Thực phẩm':
        return const Color(0xFFFF7043); // Warm orange
      case 'Học tập':
        return const Color(0xFF42A5F5); // Blue
      case 'Du lịch':
        return const Color(0xFF26A69A); // Teal
      case 'Di chuyển':
        return const Color(0xFFFFA726); // Amber
      case 'Giải trí':
        return const Color(0xFFAB47BC); // Purple
      case 'Sức khỏe':
        return const Color(0xFFEF5350); // Coral red
      case 'Khác':
      default:
        return const Color(0xFF78909C); // Slate grey
    }
  }
}
