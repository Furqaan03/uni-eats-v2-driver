import '../firestore_order_service.dart';
import 'send_notification.dart';

/// High-level order push events fired by the driver app — delivery-status
/// updates sent to the customer. Fire-and-forget.
class OrderPush {
  OrderPush._();

  /// Push a delivery-status update to the order's customer (default channel).
  static Future<void> notifyCustomer({
    required String orderId,
    required String title,
    required String body,
  }) async {
    final token = await FirestoreOrderService.instance.fetchCustomerFcmTokenForOrder(orderId);
    if (token == null) return;
    await SendNotification.toToken(
      token: token,
      title: title,
      body: body,
      data: {'orderId': orderId, 'type': 'order_status'},
    );
  }

  /// Push an update to the order's vendor (default channel) — e.g. picked up.
  static Future<void> notifyVendor({
    required String orderId,
    required String title,
    required String body,
  }) async {
    final token = await FirestoreOrderService.instance.fetchVendorFcmTokenForOrder(orderId);
    if (token == null) return;
    await SendNotification.toToken(
      token: token,
      title: title,
      body: body,
      data: {'orderId': orderId, 'type': 'order_status'},
    );
  }
}
