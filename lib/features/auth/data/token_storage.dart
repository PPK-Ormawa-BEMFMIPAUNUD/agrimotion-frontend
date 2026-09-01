import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrimotion/features/auth/domain/user_model.dart';

/// Persistent local storage service for authentication sessions and JWT tokens.
///
/// Uses [SharedPreferences] to store auth tokens, serialized user profiles,
/// and token expiration timestamps securely across app restarts.
class TokenStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _expiresKey = 'auth_expires';

  /// Singleton instance of [TokenStorage].
  static final TokenStorage instance = TokenStorage._();

  TokenStorage._();

  /// Cached [SharedPreferences] instance to avoid redundant initialization calls.
  SharedPreferences? _prefsInstance;

  /// Internal getter to retrieve or initialize [SharedPreferences].
  Future<SharedPreferences> get _prefs async =>
      _prefsInstance ??= await SharedPreferences.getInstance();

  /// Saves the complete [AuthSession] including access token, user profile,
  /// and expiration timestamp to persistent local storage.
  Future<void> saveSession(AuthSession session) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(_tokenKey, session.accessToken);
    await prefs.setString(_userKey, jsonEncode(session.user.toJson()));

    if (session.expiresAt != null) {
      await prefs.setString(_expiresKey, session.expiresAt!.toIso8601String());
    } else {
      await prefs.remove(_expiresKey);
    }
  }

  /// Retrieves the active [AuthSession] from persistent storage.
  ///
  /// Returns `null` if no session is stored, if data is malformed,
  /// or if the stored session has expired. If expired, storage is cleared automatically.
  Future<AuthSession?> getSession() async {
    try {
      final SharedPreferences prefs = await _prefs;
      final String? token = prefs.getString(_tokenKey);
      final String? userJson = prefs.getString(_userKey);

      if (token == null || userJson == null || token.isEmpty) {
        return null;
      }

      final dynamic decoded = jsonDecode(userJson);
      if (decoded is! Map<String, dynamic>) {
        await clearSession();
        return null;
      }

      final UserModel user = UserModel.fromJson(decoded);
      final String? expiresStr = prefs.getString(_expiresKey);
      final DateTime? expiresAt =
          expiresStr != null ? DateTime.tryParse(expiresStr) : null;

      final AuthSession session = AuthSession(
        user: user,
        accessToken: token,
        expiresAt: expiresAt,
      );

      // Invalidate if token is expired
      if (session.isExpired) {
        await clearSession();
        return null;
      }

      return session;
    } catch (_) {
      // In case of any deserialization failure, cleanly purge stored state
      await clearSession();
      return null;
    }
  }

  /// Retrieves the stored access token if valid and not expired.
  ///
  /// Returns `null` if no token is saved or if expired.
  Future<String?> getToken() async {
    final AuthSession? session = await getSession();
    return session?.accessToken;
  }

  /// Retrieves the current stored [UserModel] profile.
  ///
  /// Returns `null` if no user session is present.
  Future<UserModel?> getUser() async {
    final AuthSession? session = await getSession();
    return session?.user;
  }

  /// Clears all authentication data from persistent storage.
  Future<void> clearSession() async {
    try {
      final SharedPreferences prefs = await _prefs;
      await Future.wait<bool>([
        prefs.remove(_tokenKey),
        prefs.remove(_userKey),
        prefs.remove(_expiresKey),
      ]);
    } catch (_) {
      // Ignore cleanup exceptions
    }
  }

  /// Returns `true` if a valid, non-expired authentication token exists.
  Future<bool> hasValidToken() async {
    final AuthSession? session = await getSession();
    return session != null && !session.isExpired;
  }
}
