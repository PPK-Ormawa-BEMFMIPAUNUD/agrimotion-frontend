class UserLoginModel {
  final String id;
  final String userId;
  final DateTime loginAt;

  const UserLoginModel({
    required this.id,
    required this.userId,
    required this.loginAt,
  });

  factory UserLoginModel.fromJson(Map<String, dynamic> json) {
    return UserLoginModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      loginAt: json['loginAt'] != null
          ? (DateTime.tryParse(json['loginAt'].toString())?.toLocal() ?? DateTime.now())
          : (DateTime.tryParse(json['login_at']?.toString() ?? '')?.toLocal() ?? DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'loginAt': loginAt.toIso8601String(),
    };
  }
}
