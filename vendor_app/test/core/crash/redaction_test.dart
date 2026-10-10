import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_app/core/crash/redaction.dart';

void main() {
  test('removes tokens, emails, phone numbers and query strings', () {
    const input =
        'DioException GET http://h/api/v1/me?token=abc123 '
        'Authorization: Bearer eyJhbGciOi.eyJzdWIiOi.c2lnbmF0dXJl '
        'user a.b+c@example.co.in phone +91 98765 43210';
    final out = redact(input);
    expect(out, isNot(contains('abc123')));
    expect(out, isNot(contains('eyJ')));
    expect(out, isNot(contains('example.co.in')));
    expect(out, isNot(contains('98765')));
    expect(out, contains('Bearer [REDACTED]'));
    expect(out, contains('[EMAIL]'));
    expect(out, contains('[PHONE]'));
    expect(out, contains('/api/v1/me?[QUERY]'));
  });

  test('keeps ordinary text', () {
    expect(
      redact('Start-up step "config" failed'),
      'Start-up step "config" failed',
    );
  });

  test('removes one-time codes and verification ids', () {
    final out = redact(
      'confirm failed code 482913 verificationId AMd2dP_Kq3x9Zr7VtY1sLwQe8NnB4uHcJ0gFiOaE',
    );
    expect(out, isNot(contains('482913')));
    expect(out, isNot(contains('AMd2dP')));
  });
}
