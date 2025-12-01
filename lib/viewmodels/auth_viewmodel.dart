import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

/// Kimlik doğrulama durumunu yöneten ViewModel
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isSignedIn => _authService.isSignedIn;
  UserModel? get currentUser => _authService.currentUser;
  String? get errorMessage => _errorMessage;

  AuthViewModel() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    await _authService.initialize();

    _isLoading = false;
    notifyListeners();
  }

  /// Google ile giriş yap
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();
      return user != null;
    } catch (e) {
      _errorMessage = 'Giriş yapılamadı: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Çıkış yap
  Future<void> signOut() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signOut();
    } catch (e) {
      _errorMessage = 'Çıkış yapılamadı: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Hesap bağlantısını kes
  Future<void> disconnect() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.disconnect();
    } catch (e) {
      _errorMessage = 'Bağlantı kesilemedi: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
