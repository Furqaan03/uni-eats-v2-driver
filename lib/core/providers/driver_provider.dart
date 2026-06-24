import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/firestore_order_service.dart';

enum DeliveryStep { toRestaurant, atRestaurant, enRoute, atCustomer, delivered }

const _kMaxOrders = 3;

// ─── Mock order templates (cycles on each accept) ─────────────────────────────

class _OrderTemplate {
  final String restaurant;
  final String restaurantAddr;
  final String stall;
  final String dropoff;
  final String customerAddr;
  final double payout;
  final double tip;
  final double deliveryFee;
  final double subtotal;
  final List<(String, String, String)> items;
  final String foodType;
  final double distKm;
  final int etaMin;
  const _OrderTemplate({
    required this.restaurant,
    required this.restaurantAddr,
    required this.stall,
    required this.dropoff,
    required this.customerAddr,
    required this.payout,
    required this.tip,
    required this.deliveryFee,
    required this.subtotal,
    required this.items,
    required this.foodType,
    required this.distKm,
    required this.etaMin,
  });
}

const _kTemplates = [
  _OrderTemplate(
    restaurant: 'Campus Kitchen',
    restaurantAddr: 'Campus Kitchen UDST Qatar',
    stall: 'Stall 3',
    dropoff: 'Dorm Block C · Room 204',
    customerAddr: 'Dorm Block C UDST Qatar',
    payout: kDriverPayoutPerDelivery,
    tip: 5.00,
    deliveryFee: 8.50,
    subtotal: 15.00,
    items: [('🍕', '1× Margherita Pizza', 'QAR 12.00'), ('🥤', '1× Cola', 'QAR 3.00')],
    foodType: '🍕 Italian',
    distKm: 2.1,
    etaMin: 12,
  ),
  _OrderTemplate(
    restaurant: 'Burger Hub',
    restaurantAddr: 'Burger Hub UDST Qatar',
    stall: 'Counter 2',
    dropoff: 'Engineering Block A · Lab 101',
    customerAddr: 'Engineering Block A UDST Qatar',
    payout: kDriverPayoutPerDelivery,
    tip: 7.00,
    deliveryFee: 10.00,
    subtotal: 24.00,
    items: [('🍔', '1× Cheese Burger', 'QAR 18.00'), ('🍟', '1× Fries', 'QAR 6.00')],
    foodType: '🍔 American',
    distKm: 1.5,
    etaMin: 9,
  ),
  _OrderTemplate(
    restaurant: 'Sushi Corner',
    restaurantAddr: 'Sushi Corner UDST Qatar',
    stall: 'Window 1',
    dropoff: 'Library · Study Room 3',
    customerAddr: 'Library UDST Qatar',
    payout: kDriverPayoutPerDelivery,
    tip: 6.50,
    deliveryFee: 12.00,
    subtotal: 31.50,
    items: [('🍱', '1× Sushi Box', 'QAR 26.00'), ('🍵', '1× Green Tea', 'QAR 5.50')],
    foodType: '🍱 Japanese',
    distKm: 3.0,
    etaMin: 16,
  ),
];

// ─── Active order model ───────────────────────────────────────────────────────

class ActiveOrder {
  final String id;
  final String restaurant;
  final String restaurantAddr;
  final String stall;
  final String dropoff;
  final String customerAddr;
  final double payout;
  final double tip;
  final double deliveryFee;
  final double subtotal;
  final List<(String, String, String)> items;
  final String foodType;
  final double distKm;
  final int etaMin;
  DeliveryStep step;
  bool pingCustomerSent;
  // True once the vendor marks the kitchen status 'ready'. A driver can
  // mark arrival at the restaurant before this (informational only — see
  // ORDER_LIFECYCLE.md), but can't mark the order picked up until the food
  // actually exists. Mock-mode orders simulate readiness on a timer since
  // there's no vendor app driving them.
  bool isReady;

  ActiveOrder._({
    required this.id,
    required this.restaurant,
    required this.restaurantAddr,
    required this.stall,
    required this.dropoff,
    required this.customerAddr,
    required this.payout,
    required this.tip,
    required this.deliveryFee,
    required this.subtotal,
    required this.items,
    required this.foodType,
    required this.distKm,
    required this.etaMin,
  }) : step = DeliveryStep.toRestaurant,
       pingCustomerSent = false,
       isReady = false;

  factory ActiveOrder.fromTemplate(String id, _OrderTemplate t) => ActiveOrder._(
        id: id,
        restaurant: t.restaurant,
        restaurantAddr: t.restaurantAddr,
        stall: t.stall,
        dropoff: t.dropoff,
        customerAddr: t.customerAddr,
        payout: t.payout,
        tip: t.tip,
        deliveryFee: t.deliveryFee,
        subtotal: t.subtotal,
        items: t.items,
        foodType: t.foodType,
        distKm: t.distKm,
        etaMin: t.etaMin,
      );
}

// ─── Notification model ───────────────────────────────────────────────────────

class DriverNotification {
  final String id;
  final String title;
  final String body;
  final String icon;
  final DateTime time;
  bool read;

  DriverNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.time,
    this.read = false,
  });
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class DriverProvider extends ChangeNotifier {
  bool _isOnline = false;
  bool get isOnline => _isOnline;

  // Firestore subscription for available delivery orders
  StreamSubscription<List<FirestoreOrder>>? _availableOrdersSub;
  // Firestore order ID for the currently incoming order (null = mock mode)
  String? _incomingFirestoreOrderId;

  bool _hasIncomingOrder = false;
  bool get hasIncomingOrder => _hasIncomingOrder;

  _OrderTemplate? _incomingTemplate;

  // Expose individual fields — pulls from Firestore order if available, else mock template
  String? get incomingRestaurant =>
      _firestoreIncoming?.restaurant ?? _incomingTemplate?.restaurant;
  String? get incomingStall =>
      _incomingTemplate?.stall ?? (_firestoreIncoming != null ? 'Counter' : null);
  String? get incomingDropoff =>
      _firestoreIncoming?.deliveryAddress ?? _incomingTemplate?.dropoff;
  double? get incomingPayout =>
      _firestoreIncoming?.payout ?? _incomingTemplate?.payout;
  double? get incomingDistKm => _incomingTemplate?.distKm ?? 1.5;
  int? get incomingEtaMin => _incomingTemplate?.etaMin ?? 15;
  int? get incomingItemCount =>
      _firestoreIncoming?.itemCount ?? _incomingTemplate?.items.length;
  String? get incomingFoodType =>
      _incomingTemplate?.foodType ?? (_firestoreIncoming != null ? '🍽 Food' : null);

  final List<ActiveOrder> _activeOrders = [];
  List<ActiveOrder> get activeOrders => List.unmodifiable(_activeOrders);
  bool get hasActiveDelivery => _activeOrders.isNotEmpty;

  /// A driver mid-delivery must finish (or have the order cancelled) before
  /// going offline — otherwise a customer's order could be abandoned with
  /// nobody assigned to complete it.
  bool get canGoOffline => !hasActiveDelivery;
  static const String cannotGoOfflineMessage =
      'You still have an order in progress. Please complete this delivery '
      'before going offline.';

  String? _selectedOrderId;
  ActiveOrder? get selectedOrder {
    if (_activeOrders.isEmpty) return null;
    try {
      return _activeOrders.firstWhere((o) => o.id == _selectedOrderId);
    } catch (_) {
      return _activeOrders.first;
    }
  }

  void selectOrder(String id) {
    _selectedOrderId = id;
    notifyListeners();
  }

  int _nextTemplateIndex = 0;

  double _todayEarnings = 0;
  double get todayEarnings => _todayEarnings;

  int _todayTrips = 0;
  int get todayTrips => _todayTrips;

  double _rating = 5.0;
  double get rating => _rating;

  int _acceptanceRate = 100;
  int get acceptanceRate => _acceptanceRate;

  /// Set once after sign-in (see MainNavShell) so the dashboard shows the
  /// driver's real lifetime rating/acceptance rate instead of a placeholder.
  void syncFromProfile({required double rating, required int acceptanceRate}) {
    _rating = rating;
    _acceptanceRate = acceptanceRate;
    notifyListeners();
  }

  /// Replaces the hardcoded launch values with real numbers from today's
  /// completed deliveries. Call once after sign-in.
  Future<void> loadTodayStats(String uid) async {
    if (!kUseFirebase || uid.isEmpty) return;
    try {
      final stats = await FirestoreOrderService.instance.fetchTodayStats(uid);
      _todayEarnings = stats.earnings;
      _todayTrips = stats.trips;
      notifyListeners();
    } catch (e) {
      debugPrint('[DriverProvider] loadTodayStats failed: $e');
    }
  }

  // Surfaced by MainNavShell as a SnackBar — cleared right after showing.
  String? errorMessage;
  void clearError() {
    errorMessage = null;
  }

  // Only a generic onboarding welcome — no fabricated payout amounts or
  // promo claims. This used to also seed a fake "QAR 142.00 sent to your
  // Qatar National Bank account" payout notification and a fake "Bonus
  // Zone" promo every single app session, regardless of whether either was
  // true.
  final List<DriverNotification> _notifications = [
    DriverNotification(
      id: '1',
      title: 'Welcome to Uni Eats Driver!',
      body: 'Your account is approved. Go online to start receiving orders.',
      icon: '🎉',
      time: DateTime.now().subtract(const Duration(minutes: 5)),
      read: false,
    ),
  ];

  List<DriverNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.read).length;

  void markAllRead() {
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) _notifications[idx].read = true;
    notifyListeners();
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  void addNotification(DriverNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void toggleOnline() {
    if (_isOnline && !canGoOffline) return;
    _isOnline = !_isOnline;
    if (_isOnline) {
      addNotification(DriverNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'You are Online',
        body: 'You are now visible to customers and can receive orders.',
        icon: '🟢',
        time: DateTime.now(),
      ));
      notifyListeners();
      if (kUseFirebase) {
        _subscribeToAvailableOrders();
        FirestoreOrderService.instance
            .setDriverOnline(true)
            .catchError((e) => debugPrint('[Firestore] setOnline failed: $e'));
      } else {
        // Mock mode: simulate incoming order after short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (_isOnline && _activeOrders.length < _kMaxOrders && !_hasIncomingOrder) {
            triggerNewOrder();
          }
        });
      }
    } else {
      _availableOrdersSub?.cancel();
      _availableOrdersSub = null;
      if (kUseFirebase) {
        FirestoreOrderService.instance
            .setDriverOnline(false)
            .catchError((e) => debugPrint('[Firestore] setOffline failed: $e'));
      }
      notifyListeners();
    }
  }

  void _subscribeToAvailableOrders() {
    _availableOrdersSub?.cancel();
    _availableOrdersSub = FirestoreOrderService.instance
        .streamAvailableOrders()
        .listen((orders) {
      if (!_isOnline || _hasIncomingOrder || _activeOrders.length >= _kMaxOrders) return;
      if (orders.isEmpty) return;
      final first = orders.first;
      _incomingFirestoreOrderId = first.id;
      _incomingTemplate = null; // clear mock template
      _hasIncomingOrder = true;
      addNotification(DriverNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New Order — ${first.restaurant}',
        body: '${first.restaurant} → ${first.deliveryAddress ?? 'Campus'} • QAR ${first.payout.toStringAsFixed(2)}',
        icon: '🛵',
        time: DateTime.now(),
      ));
      // Expose Firestore order fields for the incoming order screen
      _firestoreIncoming = first;
      notifyListeners();
    }, onError: (Object e) {
      // Most likely cause: the composite index this query needs is still
      // building. The stream dies on error and won't come back on its
      // own once the index finishes — so retry instead of leaving the
      // driver stuck silently offline-feeling while still "online".
      debugPrint('[DriverProvider] streamAvailableOrders failed: $e');
      errorMessage = 'Reconnecting to available orders…';
      notifyListeners();
      Future.delayed(const Duration(seconds: 5), () {
        if (_isOnline) _subscribeToAvailableOrders();
      });
    });
  }

  // Firestore incoming order data (null in mock mode)
  FirestoreOrder? _firestoreIncoming;
  FirestoreOrder? get firestoreIncoming => _firestoreIncoming;

  void goOffline() {
    if (!canGoOffline) return;
    _isOnline = false;
    _availableOrdersSub?.cancel();
    _availableOrdersSub = null;
    if (kUseFirebase) {
      FirestoreOrderService.instance
          .setDriverOnline(false)
          .catchError((e) => debugPrint('[Firestore] setOffline failed: $e'));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _availableOrdersSub?.cancel();
    super.dispose();
  }

  void triggerNewOrder() {
    if (_isOnline && _activeOrders.length < _kMaxOrders && !_hasIncomingOrder) {
      _incomingTemplate = _kTemplates[_nextTemplateIndex % _kTemplates.length];
      _hasIncomingOrder = true;
      addNotification(DriverNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New Order — ${_incomingTemplate!.restaurant}',
        body: '${_incomingTemplate!.restaurant} → ${_incomingTemplate!.dropoff} • QAR ${_incomingTemplate!.payout.toStringAsFixed(2)}',
        icon: '🛵',
        time: DateTime.now(),
      ));
      notifyListeners();
    }
  }

  Future<void> acceptOrder() async {
    if (kUseFirebase && _incomingFirestoreOrderId != null) {
      await _acceptFirestoreOrder();
      return;
    }
    // Mock mode
    final template = _incomingTemplate;
    if (template == null) return;
    final order = ActiveOrder.fromTemplate(
      DateTime.now().millisecondsSinceEpoch.toString(),
      template,
    );
    _activeOrders.add(order);
    _selectedOrderId = order.id;
    _nextTemplateIndex++;
    _hasIncomingOrder = false;
    _incomingTemplate = null;
    _firestoreIncoming = null;
    notifyListeners();
    _simulateKitchenReady(order.id, order.restaurant);
    Future.delayed(const Duration(seconds: 10), () {
      if (_isOnline && _activeOrders.length < _kMaxOrders && !_hasIncomingOrder) {
        triggerNewOrder();
      }
    });
  }

  /// Mock-mode stand-in for the vendor app marking the kitchen 'ready' —
  /// there's no real vendor driving these orders, so simulate the same
  /// delay instead of leaving pickup permanently unlocked.
  void _simulateKitchenReady(String orderId, String restaurant) {
    Future.delayed(const Duration(seconds: 8), () {
      final idx = _activeOrders.indexWhere((o) => o.id == orderId);
      if (idx == -1 || _activeOrders[idx].isReady) return;
      _activeOrders[idx].isReady = true;
      addNotification(DriverNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Order Ready!',
        body: '$restaurant has your order ready — head in to pick it up.',
        icon: '🍽',
        time: DateTime.now(),
      ));
      notifyListeners();
    });
  }

  Future<void> _acceptFirestoreOrder() async {
    final fsOrder = _firestoreIncoming;
    final fsOrderId = _incomingFirestoreOrderId;
    if (fsOrder == null || fsOrderId == null) return;

    // Confirm with Firestore FIRST — a transaction, so if another driver
    // already claimed this order we find out before committing it locally,
    // instead of showing it as accepted and then silently losing it.
    try {
      await FirestoreOrderService.instance.acceptOrder(fsOrderId);
    } catch (e) {
      errorMessage = e is OrderAlreadyTakenException
          ? e.toString()
          : 'Could not accept this order — check your connection and try again.';
      _hasIncomingOrder = false;
      _incomingFirestoreOrderId = null;
      _firestoreIncoming = null;
      notifyListeners();
      return;
    }

    final order = ActiveOrder._(
      id: fsOrderId,
      restaurant: fsOrder.restaurant,
      restaurantAddr: fsOrder.restaurantAddr,
      stall: '',
      dropoff: fsOrder.deliveryAddress ?? 'Campus',
      customerAddr: fsOrder.deliveryAddress ?? 'Campus',
      payout: fsOrder.payout,
      tip: 0,
      deliveryFee: fsOrder.deliveryFee,
      subtotal: fsOrder.total - fsOrder.deliveryFee,
      items: fsOrder.items
          .map((i) => ('📦', '${i['qty']}× ${i['name']}', 'QAR ${i['price']}'))
          .toList(),
      foodType: '🍽 Food',
      distKm: 1.5,
      etaMin: 15,
    );

    _activeOrders.add(order);
    _selectedOrderId = order.id;
    _hasIncomingOrder = false;
    _incomingFirestoreOrderId = null;
    _firestoreIncoming = null;
    notifyListeners();
    _watchForReady(fsOrderId, order.restaurant);
  }

  /// Claiming an order while it's 'awaitingDriver' starts the kitchen, but
  /// the driver still has to wait for the food itself — watch for the
  /// vendor marking it 'ready' and notify the driver instead of leaving
  /// them to keep checking back manually.
  void _watchForReady(String orderId, String restaurant) {
    StreamSubscription<String?>? sub;
    sub = FirestoreOrderService.instance.watchOrderStatus(orderId).listen((status) {
      // 'assigned' is the vendor's fallback mapping for "ready, driver
      // matched but not yet there" (see firestore_order_service.dart) — the
      // kitchen is done either way, so either status string unlocks pickup.
      if (status == 'ready' || status == 'assigned') {
        final idx = _activeOrders.indexWhere((o) => o.id == orderId);
        if (idx != -1 && !_activeOrders[idx].isReady) {
          _activeOrders[idx].isReady = true;
          addNotification(DriverNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Order Ready!',
            body: '$restaurant has your order ready — head in to pick it up.',
            icon: '🍽',
            time: DateTime.now(),
          ));
          notifyListeners();
        }
        sub?.cancel();
      } else if (status == null || status == 'cancelled' || status == 'delivered') {
        // Order resolved some other way (cancelled, or somehow already
        // past this point) — nothing left to watch for.
        sub?.cancel();
      }
    }, onError: (Object e) {
      debugPrint('[DriverProvider] watchForReady failed: $e');
      sub?.cancel();
    });
  }

  void rejectOrder() {
    _hasIncomingOrder = false;
    _incomingTemplate = null;
    _incomingFirestoreOrderId = null;
    _firestoreIncoming = null;
    notifyListeners();
  }

  void declineWithReason(String reason) {
    final declinedOrderId = _incomingFirestoreOrderId;
    _hasIncomingOrder = false;
    _incomingTemplate = null;
    _incomingFirestoreOrderId = null;
    _firestoreIncoming = null;
    notifyListeners();
    if (kUseFirebase && declinedOrderId != null) {
      FirestoreOrderService.instance
          .recordDecline(declinedOrderId, reason)
          .catchError((e) => debugPrint('[Firestore] recordDecline failed: $e'));
    }
  }

  void pingCustomer(String orderId) {
    final idx = _activeOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) _activeOrders[idx].pingCustomerSent = true;
    notifyListeners();
  }

  // Guards against any UI surface calling this twice for the same order in
  // quick succession (e.g. a duplicate control, or a double-tap before the
  // button's label updates) — without it, a double-call silently skips a
  // delivery step and desyncs the driver app from what actually happened.
  final Set<String> _advancingOrderIds = {};

  Future<void> advanceDeliveryStep(String orderId) async {
    if (_advancingOrderIds.contains(orderId)) return;
    final idx = _activeOrders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    _advancingOrderIds.add(orderId);
    final order = _activeOrders[idx];

    String? firestoreStatus;
    switch (order.step) {
      case DeliveryStep.toRestaurant:
        // Arrived at the restaurant — not picked up yet. Written as a
        // separate flag, NOT the order's `status`, because the driver can
        // physically get here before the kitchen finishes — overwriting
        // `status` here would wrongly jump the vendor's dashboard out of
        // "Preparing"/"Ready" before the food is actually done.
        order.step = DeliveryStep.atRestaurant;
        if (kUseFirebase) {
          FirestoreOrderService.instance
              .markArrivedAtRestaurant(orderId)
              .catchError((e) => debugPrint('[Firestore] markArrived failed: $e'));
        }
      case DeliveryStep.atRestaurant:
        // The driver can mark arrival before the kitchen is done (that's
        // informational only, see the toRestaurant case above) — but they
        // physically can't pick up food that doesn't exist yet. Block the
        // actual pickup until the vendor has marked the order ready.
        if (!order.isReady) {
          _advancingOrderIds.remove(orderId);
          errorMessage = "${order.restaurant} hasn't marked this order ready yet — "
              "wait for it before picking up.";
          notifyListeners();
          return;
        }
        // This is the actual pickup moment — the order leaves the restaurant
        // and is on the way in the same instant. A previous version of this
        // wrote a follow-up 'enRoute' status a few seconds later to give
        // "out for delivery" its own state, but that delayed write could
        // land AFTER the driver had already reached the customer and tapped
        // "Arrived" — silently regressing the status back to 'enRoute'.
        // 'pickedUp' alone now represents this whole leg.
        order.step = DeliveryStep.enRoute;
        order.pingCustomerSent = false;
        firestoreStatus = 'pickedUp';
      case DeliveryStep.enRoute:
        // Arrived at the customer — not handed off yet. Distinct from
        // "delivered" so the user/vendor know the driver is right there.
        order.step = DeliveryStep.atCustomer;
        firestoreStatus = 'arrivedAtCustomer';
      case DeliveryStep.atCustomer:
        order.step = DeliveryStep.delivered;
        firestoreStatus = 'delivered';
      case DeliveryStep.delivered:
        _todayEarnings += order.payout;
        _todayTrips += 1;
        _activeOrders.removeAt(idx);
        _selectedOrderId = _activeOrders.isNotEmpty ? _activeOrders.first.id : null;
        addNotification(DriverNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Delivery Complete!',
          body: 'You earned QAR ${order.payout.toStringAsFixed(2)} from ${order.restaurant}. 🎉',
          icon: '✅',
          time: DateTime.now(),
        ));
        if (kUseFirebase && kDriverId.isNotEmpty) {
          FirestoreOrderService.instance
              .recordCompletedDelivery(kDriverId, order.payout)
              .catchError((e) => debugPrint('[Firestore] recordCompletedDelivery failed: $e'));
        }
    }
    notifyListeners();
    if (kUseFirebase && firestoreStatus != null) {
      FirestoreOrderService.instance
          .updateDeliveryStatus(orderId, firestoreStatus)
          .catchError((e) => debugPrint('[Firestore] updateDelivery failed: $e'));
    }
    // Released after a short debounce window rather than immediately, so a
    // human double-tap (two separate gesture events, not a true race) can't
    // slip through and double-advance the step.
    Future.delayed(const Duration(milliseconds: 800), () => _advancingOrderIds.remove(orderId));
  }
}
