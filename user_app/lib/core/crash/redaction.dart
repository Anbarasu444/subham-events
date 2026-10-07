/// Removes personal data and credentials from text before it leaves the
/// device (threat-model.md T15, GI-15).
String redact(String input) {
  var out = input;
  out = out.replaceAll(
    RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    'Bearer [REDACTED]',
  );
  // JWTs (Firebase ID tokens) and other long base64url tokens.
  out = out.replaceAll(
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
    '[TOKEN]',
  );
  out = out.replaceAll(
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    '[EMAIL]',
  );
  out = out.replaceAll(RegExp(r'\+?\d[\d\s-]{8,}\d'), '[PHONE]');
  // Firebase verification ids and other long opaque tokens.
  out = out.replaceAll(RegExp(r'[A-Za-z0-9_-]{32,}'), '[TOKEN]');
  // One-time codes.
  out = out.replaceAll(RegExp(r'\b\d{6}\b'), '[CODE]');
  // Query strings may carry tokens (signed URLs, invitation links).
  out = out.replaceAll(RegExp(r'\?[^\s"]+'), '?[QUERY]');
  return out;
}
