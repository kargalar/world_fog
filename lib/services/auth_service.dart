import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Kullanıcı modeli
class UserModel {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  const UserModel({required this.id, this.email, this.displayName, this.photoUrl});

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'displayName': displayName, 'photoUrl': photoUrl};

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(id: json['id'] as String, email: json['email'] as String?, displayName: json['displayName'] as String?, photoUrl: json['photoUrl'] as String?);

  factory UserModel.fromGoogleUser(GoogleSignInAccount user) => UserModel(id: user.id, email: user.email, displayName: user.displayName, photoUrl: user.photoUrl);
}

/// Kimlik doğrulama işlemlerini yöneten servis
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _userKey = 'current_user';

  // Google Sign-In instance (singleton)
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  UserModel? _currentUser;
  bool _isInitialized = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  UserModel? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  /// Servisi başlat ve önceki oturumu kontrol et
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Önce kaydedilmiş kullanıcıyı kontrol et
      final savedUser = await _loadSavedUser();
      if (savedUser != null) {
        _currentUser = savedUser;
        debugPrint('✅ Kaydedilmiş kullanıcı yüklendi: ${savedUser.email}');
      }

      // Auth events'i dinle
      _authSubscription = _googleSignIn.authenticationEvents.listen(
        (event) async {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            _currentUser = UserModel.fromGoogleUser(event.user);
            await _saveUser(_currentUser!);
            debugPrint('✅ Google auth event: ${event.user.email}');
          } else if (event is GoogleSignInAuthenticationEventSignOut) {
            _currentUser = null;
            await _clearSavedUser();
          }
        },
        onError: (error) {
          debugPrint('❌ Google auth error: $error');
        },
      );

      // Google Sign-In'ı başlat
      await _googleSignIn.initialize();

      // Sessiz giriş dene
      _googleSignIn.attemptLightweightAuthentication();

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Auth service başlatılamadı: $e');
      _isInitialized = true;
    }
  }

  /// Google ile giriş yap
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Yeni API ile authenticate kullan
      if (_googleSignIn.supportsAuthenticate()) {
        final account = await _googleSignIn.authenticate();
        _currentUser = UserModel.fromGoogleUser(account);
        await _saveUser(_currentUser!);
        debugPrint('✅ Google giriş başarılı: ${account.email}');
        return _currentUser;
      } else {
        debugPrint('⚠️ Bu platformda authenticate desteklenmiyor');
        return null;
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('⚠️ Google giriş iptal edildi');
      } else {
        debugPrint('❌ Google giriş hatası: ${e.code} - ${e.description}');
      }
      return null;
    } catch (e) {
      debugPrint('❌ Google giriş hatası: $e');
      return null;
    }
  }

  /// Çıkış yap
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      await _clearSavedUser();
      debugPrint('✅ Çıkış yapıldı');
    } catch (e) {
      debugPrint('❌ Çıkış hatası: $e');
    }
  }

  /// Google hesabının bağlantısını tamamen kes
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      _currentUser = null;
      await _clearSavedUser();
      debugPrint('✅ Hesap bağlantısı kesildi');
    } catch (e) {
      debugPrint('❌ Bağlantı kesme hatası: $e');
    }
  }

  /// Kullanıcıyı SharedPreferences'a kaydet
  Future<void> _saveUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = json.encode(user.toJson());
      await prefs.setString(_userKey, userJson);
    } catch (e) {
      debugPrint('❌ Kullanıcı kaydedilemedi: $e');
    }
  }

  /// Kaydedilmiş kullanıcıyı yükle
  Future<UserModel?> _loadSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson == null) return null;

      final userMap = json.decode(userJson) as Map<String, dynamic>;
      return UserModel.fromJson(userMap);
    } catch (e) {
      debugPrint('❌ Kaydedilmiş kullanıcı yüklenemedi: $e');
      return null;
    }
  }

  /// Kaydedilmiş kullanıcıyı temizle
  Future<void> _clearSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    } catch (e) {
      debugPrint('❌ Kullanıcı temizlenemedi: $e');
    }
  }

  void dispose() {
    _authSubscription?.cancel();
  }
}
