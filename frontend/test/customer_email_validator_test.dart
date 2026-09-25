import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/validators.dart';

void main() {
  const msg = 'Please enter a valid email address.';

  test('accepts emails from any provider/domain', () {
    for (final e in [
      'kamal@gmail.com',
      'KAMAL@GMAIL.COM',
      'kamal.patel@gmail.com',
      'kamal.patel+erp@gmail.com',
      'accounts@company.com',
      'accounts@company.co.in',
      'user123@outlook.com',
      'info@my-company.com',
      '  kamal@gmail.com  ',
      'a@corp.technology',
    ]) {
      expect(Validators.requiredEmailAddress(e), isNull, reason: e);
    }
  });

  test('rejects malformed emails', () {
    for (final e in [
      '',
      '   ',
      null,
      'kamalgmail.com',
      'kamal@@gmail.com',
      '@gmail.com',
      'kamal@',
      'kamal @gmail.com',
      'kamal@gmail',
      'kamal@-gmail.com',
      'kamal@gmail..com',
      'kamal..x@gmail.com',
    ]) {
      expect(Validators.requiredEmailAddress(e), msg, reason: '$e');
    }
  });

  test('enforces 254 char maximum', () {
    final domain = '${'x' * 60}.${'y' * 60}.${'z' * 60}.com';
    final ok = '${'l' * (254 - domain.length - 1)}@$domain';
    expect(ok.length, 254);
    expect(Validators.requiredEmailAddress(ok), isNull);
    expect(Validators.requiredEmailAddress('l$ok'), msg);
  });
}
