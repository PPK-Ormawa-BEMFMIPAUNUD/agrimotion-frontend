import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:agrimotion/core/constants/api_constants.dart';
import 'package:agrimotion/core/network/api_client.dart';
import 'package:agrimotion/features/auth/domain/user_model.dart';

/// Service managing user CRUD operations against the backend API.
///
/// All requests require a valid JWT Bearer token (injected by [ApiClient]).
class UserService {
  final ApiClient _apiClient;

  UserService(this._apiClient);

  /// Fetches all users from the backend.
  ///
  /// Calls `GET /users` with JWT authentication.
  /// Returns a list of [UserModel] instances parsed from the response.
  Future<List<UserModel>> getUsers() async {
    final Uri url = Uri.parse(ApiConstants.usersEndpoint);
    final http.Response response = await _apiClient.get(url);
    final dynamic json = _apiClient.parseJson(response);

    List<dynamic> usersRaw;
    if (json is Map<String, dynamic>) {
      // Handle wrapped response: { success: true, data: [...] }
      if (json['data'] is List) {
        usersRaw = json['data'] as List<dynamic>;
      } else {
        usersRaw = <dynamic>[];
      }
    } else if (json is List) {
      usersRaw = json;
    } else {
      usersRaw = <dynamic>[];
    }

    return usersRaw
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> u) => UserModel.fromJson(u))
        .toList();
  }

  /// Creates a new user on the backend.
  ///
  /// Calls `POST /users` with the provided user data.
  /// Returns the created [UserModel] parsed from the response.
  Future<UserModel> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final Uri url = Uri.parse(ApiConstants.usersEndpoint);
    final http.Response response = await _apiClient.post(
      url,
      body: <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      },
    );

    final dynamic json = _apiClient.parseJson(response);
    if (json is Map<String, dynamic>) {
      final dynamic userData = json['data'] ?? json;
      if (userData is Map<String, dynamic>) {
        return UserModel.fromJson(userData);
      }
    }

    throw const ApiException('Format respons pembuatan pengguna tidak valid.');
  }

  /// Deletes a user by ID.
  ///
  /// Calls `DELETE /users/:id` with JWT authentication.
  Future<void> deleteUser(String userId) async {
    final Uri url = Uri.parse('${ApiConstants.usersEndpoint}/$userId');
    final http.Response response = await _apiClient.delete(url);
    _apiClient.validateResponse(response);
  }
}

// =============================================================================
// RIVERPOD PROVIDERS
// =============================================================================

/// Riverpod provider for the [UserService] singleton.
final userServiceProvider = Provider<UserService>((ref) {
  final ApiClient apiClient = ref.watch(apiClientProvider);
  return UserService(apiClient);
});

/// FutureProvider that fetches all users from the backend.
/// Auto-disposes when the widget is no longer listening.
final usersListProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final UserService service = ref.watch(userServiceProvider);
  return service.getUsers();
});
