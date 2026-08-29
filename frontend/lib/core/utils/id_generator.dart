import 'dart:math';

class IdGenerator {
  IdGenerator._();

  static final Random _random = Random();

  static String generateId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final randomSuffix = _random.nextInt(900) + 100;
    return '$prefix-$timestamp-$randomSuffix';
  }

  static String generateDocNumber(String prefix, int counter) {
    final year = DateTime.now().year;
    return '$prefix-$year-${counter.toString().padLeft(4, '0')}';
  }
}
