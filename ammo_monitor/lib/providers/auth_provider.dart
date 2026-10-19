import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isDriver => _user?.isDriver ?? false;

  AuthProvider() {
    _authService.authStateChanges.listen(_onAuthStateChanged);
    _onAuthStateChanged(_authService.currentUser);
  }

  Future<void> _onAuthStateChanged(UserModel? user) async {
    _status = AuthStatus.loading;
    notifyListeners();

    _user = user;
    _status = _user != null
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.signIn(email, password);
      if (_user == null) {
        _errorMessage = 'Tài khoản không có trong hệ thống.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.signUp(email, password);
      if (_user == null) {
        _errorMessage = 'Đăng ký thất bại.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }
}
