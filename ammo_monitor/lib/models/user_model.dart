import 'package:cloud_firestore/cloud_firestore.dart';

/// Vai trò người dùng
enum UserRole { admin, driver, unknown }

/// Model cho user profile (lưu trong Firestore: users/{uid})
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? avatarUrl;
  final String? assignedVehicleId; // Dành cho driver
  final Timestamp createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.assignedVehicleId,
    required this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isDriver => role == UserRole.driver;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['display_name'] ?? data['email'] ?? 'Unknown',
      role: _parseRole(data['role']),
      avatarUrl: data['avatar_url'],
      assignedVehicleId: data['assigned_vehicle_id'],
      createdAt: data['created_at'] ?? Timestamp.now(),
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? json['email'] ?? 'Unknown',
      role: _parseRole(json['role']),
      avatarUrl: json['avatar_url'],
      assignedVehicleId: json['assigned_vehicle_id'],
      createdAt: json['created_at'] != null 
          ? Timestamp.fromDate(DateTime.parse(json['created_at']))
          : Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'email': email,
    'display_name': displayName,
    'role': role.name,
    'avatar_url': avatarUrl,
    'assigned_vehicle_id': assignedVehicleId,
    'created_at': createdAt,
  };

  static UserRole _parseRole(dynamic val) {
    switch (val?.toString().toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'driver':
        return UserRole.driver;
      default:
        return UserRole.unknown;
    }
  }
}
