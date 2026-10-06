import 'package:encrypted_shared_preferences/encrypted_shared_preferences.dart';

/// Small sensitive key/value data (CLAUDE.md §15). Not for large or
/// authoritative data.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
}

class EncryptedSecureStore implements SecureStore {
  EncryptedSecureStore([EncryptedSharedPreferences? prefs])
    : _prefs = prefs ?? EncryptedSharedPreferences();

  final EncryptedSharedPreferences _prefs;

  @override
  Future<String?> read(String key) async {
    final value = await _prefs.getString(key);
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> delete(String key) => _prefs.remove(key);

  @override
  Future<void> clear() => _prefs.clear();
}
