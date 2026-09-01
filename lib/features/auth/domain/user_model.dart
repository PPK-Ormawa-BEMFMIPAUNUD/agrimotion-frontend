import 'package:flutter/foundation.dart';

/// Model representing a user in the AgriMotion system.
///
/// Supports role-based access control with standard roles:
/// - [roleAdmin]: Full administrative access to farms, devices, and users.
/// - [roleKaderDigital]: Field operator with digital agricultural training access.
/// - [roleOperator]: Device and irrigation controller operator.
/// - [roleUser]: Standard read-only / farmer user.
@immutable
class UserModel {
  /// Unique identifier of the user (UUID or backend ID).
  final String id;

  /// Full name of the user.
  final String name;

  /// Email address used for authentication.
  final String email;

  /// Hashed password (often omitted by backend, so we make it nullable here).
  final String? password;

  /// User role code (e.g. 'ADMIN', 'KADER_DIGITAL', 'OPERATOR', 'USER').
  final String role;

  /// Account creation timestamp.
  final DateTime createdAt;

  /// Optional update timestamp.
  final DateTime? updatedAt;

  // Role constant definitions
  static const String roleAdmin = 'ADMIN';
  static const String roleKaderDigital = 'KADER_DIGITAL';
  static const String roleOperator = 'OPERATOR';
  static const String roleUser = 'USER';

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.password,
    required this.role,
    required this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to deserialize JSON received from backend API or local storage.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreatedAt;
    final dynamic rawCreatedAt = json['createdAt'] ?? json['created_at'];
    if (rawCreatedAt is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
    } else if (rawCreatedAt != null) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt.toString()) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    DateTime? parsedUpdatedAt;
    final dynamic rawUpdatedAt = json['updatedAt'] ?? json['updated_at'];
    if (rawUpdatedAt is int) {
      parsedUpdatedAt = DateTime.fromMillisecondsSinceEpoch(rawUpdatedAt);
    } else if (rawUpdatedAt != null) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt.toString());
    }

    return UserModel(
      id: (json['id'] ?? json['_id'] ?? json['userId'] ?? '').toString(),
      name: (json['name'] ?? json['fullName'] ?? json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      password: json['password']?.toString(),
      role: (json['role'] ?? roleUser).toString().toUpperCase(),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Serializes [UserModel] instance into a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      if (password != null) 'password': password,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  /// Helper getters for role checks
  bool get isAdmin => role.toUpperCase() == roleAdmin;
  bool get isKaderDigital => role.toUpperCase() == roleKaderDigital;
  bool get isOperator => role.toUpperCase() == roleOperator;
  bool get isUser => role.toUpperCase() == roleUser;

  /// User-friendly localized Indonesian role label
  String get roleDisplayName {
    switch (role.toUpperCase()) {
      case roleAdmin:
        return 'Administrator';
      case roleKaderDigital:
        return 'Kader Digital';
      case roleOperator:
        return 'Operator Lapangan';
      case roleUser:
        return 'Petani / Pengguna';
      default:
        return role;
    }
  }

  /// Creates a copy of this [UserModel] with specified attributes updated.
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.password == password &&
        other.role == role &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(id, name, email, password, role, createdAt, updatedAt);

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, role: $role, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// Represents an authenticated user session containing access token and expiry details.
@immutable
class AuthSession {
  /// The authenticated user profile.
  final UserModel user;

  /// JWT access token string for API requests.
  final String accessToken;

  /// Optional expiration date of the access token.
  final DateTime? expiresAt;

  const AuthSession({
    required this.user,
    required this.accessToken,
    this.expiresAt,
  });

  /// Checks if the access token has expired relative to current local time.
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Factory constructor to deserialize JSON into [AuthSession].
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final dynamic userRaw = json['user'];
    final UserModel parsedUser;

    if (userRaw is Map<String, dynamic>) {
      parsedUser = UserModel.fromJson(userRaw);
    } else if (userRaw is Map) {
      parsedUser = UserModel.fromJson(Map<String, dynamic>.from(userRaw));
    } else {
      parsedUser = UserModel.fromJson(json);
    }

    final String token = (json['accessToken'] ??
            json['token'] ??
            json['access_token'] ??
            '')
        .toString();

    DateTime? parsedExpiresAt;
    final dynamic rawExpires = json['expiresAt'] ?? json['expires_at'];
    if (rawExpires is int) {
      parsedExpiresAt = DateTime.fromMillisecondsSinceEpoch(rawExpires);
    } else if (rawExpires != null) {
      parsedExpiresAt = DateTime.tryParse(rawExpires.toString());
    }

    return AuthSession(
      user: parsedUser,
      accessToken: token,
      expiresAt: parsedExpiresAt,
    );
  }

  /// Serializes [AuthSession] to JSON map for local persistent storage.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user': user.toJson(),
      'accessToken': accessToken,
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    };
  }

  /// Creates a copy of this session with specified attributes updated.
  AuthSession copyWith({
    UserModel? user,
    String? accessToken,
    DateTime? expiresAt,
  }) {
    return AuthSession(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthSession &&
        other.user == user &&
        other.accessToken == accessToken &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(user, accessToken, expiresAt);

  @override
  String toString() {
    return 'AuthSession(user: $user, accessToken: ${accessToken.isNotEmpty ? '***' : 'empty'}, expiresAt: $expiresAt, isExpired: $isExpired)';
  }
}
