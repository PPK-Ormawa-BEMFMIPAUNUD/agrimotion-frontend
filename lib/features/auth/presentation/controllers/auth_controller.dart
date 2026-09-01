import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:agrimotion/core/constants/api_constants.dart';
import 'package:agrimotion/features/auth/data/token_storage.dart';
import 'package:agrimotion/features/auth/domain/user_model.dart';

/// Status enum representing various lifecycle states of authentication.
enum AuthStatus {
  /// Initial uninitialized state before checking persisted credentials.
  initial,

  /// Asynchronous operation (login, checking token, logout) in progress.
  loading,

  /// User is successfully authenticated with a valid session.
  authenticated,

  /// User is not logged in or session has been terminated/expired.
  unauthenticated,

  /// An error occurred during authentication attempt.
  error,
}

/// Immutable state holder for the AgriMotion authentication feature.
@immutable
class AuthState {
  /// Current authentication status.
  final AuthStatus status;

  /// Active authentication session containing user profile and token.
  final AuthSession? session;

  /// Human-readable error message in Indonesian if an error occurred.
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.session,
    this.errorMessage,
  });

  /// Convenience getter to check if the session is fully authenticated.
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && session != null;

  /// Convenience getter to access the authenticated [UserModel].
  UserModel? get user => session?.user;

  /// Alias getter for accessing the authenticated [UserModel].
  UserModel? get currentUser => session?.user;

  /// Convenience getter to check if an auth operation is loading.
  bool get isLoading => status == AuthStatus.loading;

  /// Convenience getter to check if state contains an error.
  bool get hasError => status == AuthStatus.error && errorMessage != null;

  /// Returns a copy of [AuthState] with updated fields.
  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? errorMessage,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.status == status &&
        other.session == session &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(status, session, errorMessage);

  @override
  String toString() {
    return 'AuthState(status: $status, user: ${session?.user.email}, error: $errorMessage)';
  }
}

/// StateNotifier managing user authentication lifecycle, token persistence,
/// and real backend API authentication.
///
/// All mock/demo login logic has been removed. Authentication is exclusively
/// performed against the live NestJS backend at [ApiConstants.baseUrl].
class AuthNotifier extends StateNotifier<AuthState> {
  final TokenStorage _tokenStorage;
  final http.Client _client;

  AuthNotifier({
    TokenStorage? tokenStorage,
    http.Client? httpClient,
  })  : _tokenStorage = tokenStorage ?? TokenStorage.instance,
        _client = httpClient ?? http.Client(),
        super(const AuthState()) {
    checkAuthStatus();
  }

  /// Checks persistent storage for an active, valid [AuthSession].
  ///
  /// Invoked automatically on startup to restore logged-in state across app restarts.
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final AuthSession? session = await _tokenStorage.getSession();
      if (session != null && !session.isExpired) {
        // Verify the stored user has ADMIN role
        if (!session.user.isAdmin) {
          await _tokenStorage.clearSession();
          state = const AuthState(
            status: AuthStatus.unauthenticated,
            errorMessage:
                'Akses ditolak. Hanya pengguna dengan role Administrator yang diizinkan.',
          );
          return;
        }
        state = AuthState(
          status: AuthStatus.authenticated,
          session: session,
        );
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Gagal memuat sesi autentikasi: ${e.toString()}',
      );
    }
  }

  /// Performs user login with [email] and [password] against the real backend API.
  ///
  /// Workflow:
  /// 1. Validates non-empty input.
  /// 2. POST request to `${ApiConstants.baseUrl}/auth/login`.
  /// 3. Parses response and extracts JWT token and user profile.
  /// 4. Verifies user role is `ADMIN` — rejects non-admin users.
  /// 5. Persists session and marks authenticated.
  Future<bool> login(String email, String password) async {
    final String cleanEmail = email.trim();
    final String cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Email dan kata sandi tidak boleh kosong.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final Uri loginUri = Uri.parse(ApiConstants.loginEndpoint);
      final http.Response response = await _client
          .post(
            loginUri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'email': cleanEmail,
              'password': cleanPassword,
            }),
          )
          .timeout(ApiConstants.requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic body = jsonDecode(response.body);
        final AuthSession session =
            _extractSessionFromResponse(body, cleanEmail);

        // Strict role verification: only ADMIN users can access the admin portal
        if (!session.user.isAdmin) {
          state = const AuthState(
            status: AuthStatus.error,
            errorMessage:
                'Akses ditolak. Hanya pengguna dengan role Administrator yang diizinkan masuk ke portal admin.',
          );
          return false;
        }

        await _tokenStorage.saveSession(session);
        state = AuthState(
          status: AuthStatus.authenticated,
          session: session,
        );
        return true;
      } else {
        // Extract error message from backend response
        String message =
            'Email atau kata sandi salah. Silakan periksa kembali.';
        try {
          final dynamic body = jsonDecode(response.body);
          if (body is Map<String, dynamic>) {
            if (body['message'] is String) {
              final String backendMsg = body['message'] as String;
              if (backendMsg.toLowerCase().contains('invalid') ||
                  backendMsg.toLowerCase().contains('unauthorized') ||
                  backendMsg.toLowerCase().contains('not found')) {
                message = 'Email atau password salah';
              } else {
                message = backendMsg;
              }
            } else if (body['message'] is List &&
                (body['message'] as List).isNotEmpty) {
              message = (body['message'] as List).first.toString();
            } else if (body['error'] is String) {
              message = body['error'] as String;
            }
          }
        } catch (_) {}

        state = AuthState(
          status: AuthStatus.error,
          errorMessage: message,
        );
        return false;
      }
    } on TimeoutException catch (_) {
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Koneksi ke server timeout. Silakan coba kembali.',
      );
      return false;
    } on http.ClientException catch (_) {
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage:
            'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
      return false;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Terjadi kesalahan saat masuk: ${e.toString()}',
      );
      return false;
    }
  }

  /// Helper to extract [AuthSession] from various backend JSON response formats.
  AuthSession _extractSessionFromResponse(
      dynamic body, String fallbackEmail) {
    if (body is Map<String, dynamic>) {
      // Check for nested data payload: { success: true, data: { token, user } }
      final dynamic dataPayload = body['data'] is Map<String, dynamic>
          ? body['data']
          : body;

      final String token = (dataPayload['accessToken'] ??
              dataPayload['token'] ??
              dataPayload['access_token'] ??
              body['accessToken'] ??
              body['token'] ??
              '')
          .toString();

      final dynamic userRaw = dataPayload['user'] ?? body['user'];
      final UserModel user;

      if (userRaw is Map<String, dynamic>) {
        user = UserModel.fromJson(userRaw);
      } else {
        // Fallback user object constructed from top-level response properties
        user = UserModel(
          id: (dataPayload['id'] ?? dataPayload['userId'] ?? 'usr-001')
              .toString(),
          name: (dataPayload['name'] ?? fallbackEmail.split('@').first)
              .toString(),
          email: (dataPayload['email'] ?? fallbackEmail).toString(),
          role: (dataPayload['role'] ?? UserModel.roleUser).toString(),
          createdAt: DateTime.now(),
        );
      }

      final dynamic expiresRaw =
          dataPayload['expiresAt'] ?? dataPayload['expires_at'];
      DateTime? expiresAt;
      if (expiresRaw is int) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresRaw);
      } else if (expiresRaw != null) {
        expiresAt = DateTime.tryParse(expiresRaw.toString());
      }

      return AuthSession(
        user: user,
        accessToken: token,
        expiresAt: expiresAt,
      );
    }

    throw const FormatException('Format respons login tidak valid.');
  }

  /// Clears stored authentication session and signs user out.
  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _tokenStorage.clearSession();
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Force logout triggered externally (e.g., by ApiClient on 401 response).
  Future<void> forceLogout() async {
    await _tokenStorage.clearSession();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage:
          'Sesi Anda telah berakhir. Silakan login kembali.',
    );
  }

  /// Clears active error message without altering session state.
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(
        clearError: true,
        status: state.session != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
      );
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

// =============================================================================
// RIVERPOD PROVIDERS
// =============================================================================

/// Global Riverpod StateNotifierProvider for [AuthNotifier] and [AuthState].
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Boolean provider that yields `true` when user is actively authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});

/// Convenience provider yielding the current logged-in [UserModel], or `null`.
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).session?.user;
});

/// Convenience provider yielding the current [AuthSession], or `null`.
final authSessionProvider = Provider<AuthSession?>((ref) {
  return ref.watch(authProvider).session;
});

/// Convenience provider yielding the active [AuthStatus].
final authStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(authProvider).status;
});
