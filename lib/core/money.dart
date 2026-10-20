import 'package:intl/intl.dart';

/// Prices are kept as whole centavos so totals never drift with doubles.
class Money {
  Money._();

  static final NumberFormat _grouped = NumberFormat('#,##0.00');

  /// 123456 -> "1,234.56"
  static String format(int centavos) => _grouped.format(centavos / 100);

  /// 123456 -> "₱1,234.56"
  static String peso(int centavos) => '₱${format(centavos)}';

  /// "12", "12.5" or "1,250.75" -> centavos. Null when empty or not a number.
  static int? parse(String input) {
    final cleaned = input.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  /// 1500 -> "15.00", for text fields (no grouping so it parses back).
  static String field(int centavos) => (centavos / 100).toStringAsFixed(2);
}
