import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../core/constants/app_config.dart';

class AuthService {
  // Singleton pattern để duy trì trạng thái đăng nhập
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserModel? _currentUser;
  final StreamController<UserModel?> _authStateController = StreamController<UserModel?>.broadcast();

  UserModel? get currentUser => _currentUser;
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  /// Đăng nhập bằng Local API Server
  Future<UserModel?> signIn(String email, String password) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['user'] != null) {
          final user = UserModel.fromJson(data['user']);
          _currentUser = user;
          _authStateController.add(user);
          return user;
        }
      }
      
      throw Exception(response.statusCode == 401 ? 'Email hoặc mật khẩu không đúng.' : 'Không thể đăng nhập.');
    } catch (e) {
      throw Exception('Lỗi kết nối Local Server: $e');
    }
  }

  /// Đăng ký bằng Local API Server
  Future<UserModel?> signUp(String email, String password) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['user'] != null) {
          final user = UserModel.fromJson(data['user']);
          _currentUser = user;
          _authStateController.add(user);
          return user;
        }
      }
      
      final err = jsonDecode(utf8.decode(response.bodyBytes))['error'] ?? 'Không thể đăng ký.';
      throw Exception(err);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Lấy UserModel theo uid (phục vụ check phiên)
  Future<UserModel?> getUserModel(String uid) async {
    if (_currentUser != null && _currentUser!.uid == uid) {
      return _currentUser;
    }
    return null;
  }

  /// Stream của UserModel hiện tại
  Stream<UserModel?> getUserStream(String uid) {
    return authStateChanges.where((user) => user?.uid == uid);
  }

  /// Đăng xuất khỏi hệ thống local
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  /// Khôi phục mật khẩu (Local Mock)
  Future<void> sendPasswordResetEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 800));
  }

  /// Cập nhật tên hiển thị người dùng
  Future<void> updateDisplayName(String name) async {
    if (_currentUser != null) {
      _currentUser = UserModel(
        uid: _currentUser!.uid,
        email: _currentUser!.email,
        displayName: name,
        role: _currentUser!.role,
        avatarUrl: _currentUser!.avatarUrl,
        assignedVehicleId: _currentUser!.assignedVehicleId,
        createdAt: _currentUser!.createdAt,
      );
      _authStateController.add(_currentUser);
    }
  }
}
