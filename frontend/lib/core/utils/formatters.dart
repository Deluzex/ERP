import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  static String formatDate(DateTime date) {
    return _dateFormat.format(date.toLocal());
  }

  static String formatTime(DateTime date) {
    return _timeFormat.format(date.toLocal());
  }

  static String formatDateTime(DateTime date) {
    return _dateTimeFormat.format(date.toLocal());
  }

  static String formatCurrency(double amount) {
    final cleanAmount = amount.abs() < 0.00001 ? 0.0 : amount;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: cleanAmount % 1 == 0 ? 0 : 2,
    );
    return formatter.format(cleanAmount);
  }

  static String formatNumber(double number) {
    if (number % 1 == 0) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(2);
  }

  static String formatQuantity(double qty, String unit) {
    return '${formatNumber(qty)} $unit';
  }
}
