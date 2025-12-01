import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Bildirim işlemlerini yöneten servis sınıfı
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const int _notificationId = 1001;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isNotificationActive = false;
  bool _isInitialized = false;

  bool get isNotificationActive => _isNotificationActive;

  /// Bildirim servisini başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _flutterLocalNotificationsPlugin.initialize(initSettings);
    _isInitialized = true;
    debugPrint('📢 Bildirim servisi başlatıldı');
  }

  /// Bildirim izni iste
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.notification.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      debugPrint('⚠️ Bildirim izni kalıcı olarak reddedildi');
      return false;
    }

    return false;
  }

  /// Rota bildirimi başlat
  Future<void> startRouteNotification() async {
    if (_isNotificationActive) return;

    // Başlatılmamışsa başlat
    await initialize();

    // Önce izin kontrolü yap
    final hasPermission = await requestNotificationPermission();
    if (!hasPermission) {
      debugPrint('⚠️ Bildirim izni yok, bildirim gösterilmeyecek');
      return;
    }

    try {
      await _showNotification(Duration.zero, isPaused: false);
      _isNotificationActive = true;
      debugPrint('📢 Rota bildirimi başlatıldı');
    } catch (e) {
      debugPrint('❌ Bildirim başlatılamadı: $e');
    }
  }

  /// Rota bildirimi güncelle
  Future<void> updateRouteNotification(Duration duration) async {
    if (!_isNotificationActive) return;
    // Chronometer kullandığımız için güncelleme gerekmiyor
  }

  /// Rota bildirimini duraklat
  Future<void> pauseRouteNotification() async {
    if (!_isNotificationActive) return;

    try {
      await _flutterLocalNotificationsPlugin.cancel(_notificationId);
      debugPrint('⏸️ Rota bildirimi duraklatıldı');
    } catch (e) {
      debugPrint('❌ Bildirim duraklatılamadı: $e');
    }
  }

  /// Rota bildirimini devam ettir
  Future<void> resumeRouteNotification(Duration elapsedDuration) async {
    if (!_isNotificationActive) return;

    try {
      await _showNotification(elapsedDuration, isPaused: false);
      debugPrint('▶️ Rota bildirimi devam ediyor');
    } catch (e) {
      debugPrint('❌ Bildirim devam ettirilemedi: $e');
    }
  }

  /// Rota bildirimi durdur
  Future<void> stopRouteNotification() async {
    if (!_isNotificationActive) return;

    try {
      await _flutterLocalNotificationsPlugin.cancel(_notificationId);
      _isNotificationActive = false;
      debugPrint('📢 Rota bildirimi durduruldu');
    } catch (e) {
      debugPrint('❌ Bildirim durdurulamadı: $e');
    }
  }

  /// Bildirim göster
  Future<void> _showNotification(Duration currentDuration, {required bool isPaused}) async {
    final androidDetails = AndroidNotificationDetails(
      'route_tracking',
      'Rota Takibi',
      channelDescription: 'Rota takibi sırasında gösterilen bildirim',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
      playSound: false,
      ongoing: true, // Kaydırarak kapatılamaz
      autoCancel: false,
      usesChronometer: true, // Canlı sayaç
      chronometerCountDown: false, // Yukarı sayar
      when: DateTime.now().millisecondsSinceEpoch - currentDuration.inMilliseconds,
      visibility: NotificationVisibility.public,
      onlyAlertOnce: true,
      category: AndroidNotificationCategory.service,
      silent: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(_notificationId, 'Rota Kaydediliyor', 'Rota aktif', notificationDetails);
  }

  /// Konum servisi kapatıldı bildirimi göster
  Future<void> showLocationDisabledNotification() async {
    await initialize();

    final hasPermission = await requestNotificationPermission();
    if (!hasPermission) return;

    const androidDetails = AndroidNotificationDetails(
      'location_warning',
      'Konum Uyarıları',
      channelDescription: 'Konum servisi kapatıldığında gösterilen uyarı bildirimi',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      ongoing: false,
      autoCancel: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(1002, '⚠️ Konum Servisi Kapatıldı', 'Rota takibi durdu! Konumu açmak için dokunun.', notificationDetails);
    debugPrint('📢 Konum kapatıldı bildirimi gösterildi');
  }

  /// Konum uyarı bildirimini kapat
  Future<void> cancelLocationWarningNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(1002);
  }

  void dispose() {
    stopRouteNotification();
  }
}
