/// Configuration for client-side FCM push (see NOTIFICATIONS_PLAN.md).
///
/// Sending uses the FCM HTTP v1 API authenticated by a Firebase service
/// account. The JSON is fetched at runtime from [serviceAccountJsonUrl] so it
/// can be rotated without a release; set it to a hosted copy of the key.
class PushConfig {
  PushConfig._();

  static const String projectId = 'uni-eats-v2-aabf5';

  /// Bundled Firebase service-account JSON used to authenticate FCM v1 sends.
  /// SECURITY: git-ignored (never committed) — local build only.
  static const String serviceAccountAssetPath = 'assets/push/service_account.json';

  static bool get isConfigured => serviceAccountAssetPath.isNotEmpty;

  static Uri get sendEndpoint =>
      Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

  static const List<String> scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  static const String ordersChannelId = 'orders_channel';
  static const String defaultChannelId = 'default_channel';
  static const String orderSoundResource = 'order_sound';
}
