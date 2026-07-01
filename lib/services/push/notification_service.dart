import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import 'push_config.dart';

/// Background isolate handler — must be top-level. Our payloads are data-only
/// (see [SendNotification]), so the OS does NOT auto-display anything; this
/// isolate has its own Flutter/Firebase instance, so we re-init both and show
/// the notification ourselves via flutter_local_notifications.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  developer.log('[push] background message ${message.messageId}');
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  // Do NOT request the runtime permission here — the background isolate has no
  // Activity/Context, so requestNotificationsPermission() throws an NPE and
  // aborts display. Permission was already granted when the app ran foreground.
  await NotificationService.instance._initLocalPlugin(requestPermission: false);
  await NotificationService.instance._display(message);
}

/// Receives FCM messages and renders them as real Android system notifications,
/// in both foreground and background — payloads are deliberately data-only.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialised = false;
  bool _localPluginInitialised = false;

  Map<String, dynamic>? _launchPayload;
  void Function(Map<String, dynamic> data)? onNotificationTap;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      developer.log('[push] notifications permission denied');
    }

    await _initLocalPlugin();

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && initial.data.isNotEmpty) {
      _launchPayload = Map<String, dynamic>.from(initial.data);
    }

    // Payloads are data-only (see SendNotification), so every message lands
    // here regardless of `m.notification`.
    FirebaseMessaging.onMessage.listen(_display);
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      if (m.data.isNotEmpty) onNotificationTap?.call(Map<String, dynamic>.from(m.data));
    });
  }

  /// Sets up the local-notifications plugin and Android channels. Split out
  /// from [init] so the background isolate handler can call it too — that
  /// isolate gets a fresh [NotificationService] instance that never ran [init].
  Future<void> _initLocalPlugin({bool requestPermission = true}) async {
    if (_localPluginInitialised) return;
    _localPluginInitialised = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (resp) => _handleTapPayload(resp.payload),
    );

    final androidPlugin =
        _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      PushConfig.ordersChannelId,
      'Orders',
      description: 'New delivery alerts',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(PushConfig.orderSoundResource),
    ));
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      PushConfig.defaultChannelId,
      'General',
      description: 'Order updates',
      importance: Importance.high,
      playSound: true,
    ));
    if (Platform.isAndroid && requestPermission) {
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  Map<String, dynamic>? takeLaunchPayload() {
    final p = _launchPayload;
    _launchPayload = null;
    return p;
  }

  Future<String?> currentToken() => FirebaseMessaging.instance.getToken();

  void onTokenRefresh(void Function(String token) onChange) {
    FirebaseMessaging.instance.onTokenRefresh.listen(onChange);
  }

  void _handleTapPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) onNotificationTap?.call(Map<String, dynamic>.from(decoded));
    } catch (e) {
      developer.log('[push] bad tap payload', error: e);
    }
  }

  Future<void> _display(RemoteMessage message) async {
    final loud = message.data['isNewOrder'] == 'true';
    final android = AndroidNotificationDetails(
      loud ? PushConfig.ordersChannelId : PushConfig.defaultChannelId,
      loud ? 'Orders' : 'General',
      channelDescription: 'Order notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: loud ? const RawResourceAndroidNotificationSound(PushConfig.orderSoundResource) : null,
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.data['title'] as String?,
      message.data['body'] as String?,
      NotificationDetails(android: android),
      payload: jsonEncode(message.data),
    );
  }
}
