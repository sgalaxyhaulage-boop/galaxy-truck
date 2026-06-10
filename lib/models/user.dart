import 'package:intl/intl.dart';

enum UserRole { admin, driver }

class User {
  final String id;
  final String email;
  final String fullName;
  /// Role is nullable to support accounts that exist in Firebase Auth but
  /// haven't been assigned a role in Firestore yet.
  final UserRole? role;
  final String? phoneNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'role': role?.name,
    'phoneNumber': phoneNumber,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isActive': isActive,
  };

  factory User.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role'];
    UserRole? parsedRole;
    if (rawRole is String && rawRole.trim().isNotEmpty) {
      try {
        parsedRole = UserRole.values.firstWhere((e) => e.name == rawRole);
      } catch (_) {
        parsedRole = null;
      }
    }

    return User(
      id: json['id'],
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      role: parsedRole,
      phoneNumber: json['phoneNumber'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      isActive: json['isActive'] ?? true,
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) => User(
    id: id ?? this.id,
    email: email ?? this.email,
    fullName: fullName ?? this.fullName,
    role: role ?? this.role,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isActive: isActive ?? this.isActive,
  );
}
