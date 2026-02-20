import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String compactNumber(int value) {
    if (value < 1000) return value.toString();
    if (value < 1000000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    if (value < 1000000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    return '${(value / 1000000000).toStringAsFixed(1)}B';
  }

  static String formatCurrency(
    num value, {
    String locale = 'en_US',
    String symbol = '\$',
  }) {
    final formatter =
        NumberFormat.currency(locale: locale, symbol: symbol);
    return formatter.format(value);
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  static String trimAndNormalize(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
