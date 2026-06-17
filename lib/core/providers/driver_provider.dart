import 'package:flutter/material.dart';

enum DeliveryStep { toRestaurant, atRestaurant, enRoute, delivered }

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
    payout: 18.50,
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
    payout: 24.00,
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
    payout: 31.50,
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
       pingCustomerSent = false;

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

  bool _hasIncomingOrder = false;
  bool get hasIncomingOrder => _hasIncomingOrder;

  _OrderTemplate? _incomingTemplate;

  // Expose individual fields so private _OrderTemplate stays internal
  String? get incomingRestaurant => _incomingTemplate?.restaurant;
  String? get incomingStall => _incomingTemplate?.stall;
  String? get incomingDropoff => _incomingTemplate?.dropoff;
  double? get incomingPayout => _incomingTemplate?.payout;
  double? get incomingDistKm => _incomingTemplate?.distKm;
  int? get incomingEtaMin => _incomingTemplate?.etaMin;
  int? get incomingItemCount => _incomingTemplate?.items.length;
  String? get incomingFoodType => _incomingTemplate?.foodType;

  final List<ActiveOrder> _activeOrders = [];
  List<ActiveOrder> get activeOrders => List.unmodifiable(_activeOrders);
  bool get hasActiveDelivery => _activeOrders.isNotEmpty;

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

  double _todayEarnings = 142.0;
  double get todayEarnings => _todayEarnings;

  int _todayTrips = 8;
  int get todayTrips => _todayTrips;

  double _rating = 4.92;
  double get rating => _rating;

  int _acceptanceRate = 98;
  int get acceptanceRate => _acceptanceRate;

  final List<DriverNotification> _notifications = [
    DriverNotification(
      id: '1',
      title: 'Welcome to Uni Eats Driver!',
      body: 'Your account is approved. Go online to start receiving orders.',
      icon: '🎉',
      time: DateTime.now().subtract(const Duration(minutes: 5)),
      read: false,
    ),
    DriverNotification(
      id: '2',
      title: 'Payout Processed',
      body: 'QAR 142.00 has been sent to your Qatar National Bank account.',
      icon: '💰',
      time: DateTime.now().subtract(const Duration(hours: 2)),
      read: true,
    ),
    DriverNotification(
      id: '3',
      title: 'New Bonus Zone Active',
      body: 'Earn 2× on deliveries from Campus Kitchen between 12–2 PM.',
      icon: '⚡',
      time: DateTime.now().subtract(const Duration(hours: 5)),
      read: true,
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
      // Ping the driver about pending orders shortly after going online
      Future.delayed(const Duration(seconds: 2), () {
        if (_isOnline && _activeOrders.length < _kMaxOrders && !_hasIncomingOrder) {
          triggerNewOrder();
        }
      });
    } else {
      notifyListeners();
    }
  }

  void goOffline() {
    _isOnline = false;
    notifyListeners();
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

  void acceptOrder() {
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
    notifyListeners();
    // Ping another order after a delay if there's still capacity
    Future.delayed(const Duration(seconds: 10), () {
      if (_isOnline && _activeOrders.length < _kMaxOrders && !_hasIncomingOrder) {
        triggerNewOrder();
      }
    });
  }

  void rejectOrder() {
    _hasIncomingOrder = false;
    _incomingTemplate = null;
    notifyListeners();
  }

  void declineWithReason(String reason) {
    _hasIncomingOrder = false;
    _incomingTemplate = null;
    // In production: POST reason to admin API
    notifyListeners();
  }

  void pingCustomer(String orderId) {
    final idx = _activeOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) _activeOrders[idx].pingCustomerSent = true;
    notifyListeners();
  }

  void advanceDeliveryStep(String orderId) {
    final idx = _activeOrders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final order = _activeOrders[idx];
    switch (order.step) {
      case DeliveryStep.toRestaurant:
        order.step = DeliveryStep.atRestaurant;
      case DeliveryStep.atRestaurant:
        order.step = DeliveryStep.enRoute;
        order.pingCustomerSent = false;
      case DeliveryStep.enRoute:
        order.step = DeliveryStep.delivered;
      case DeliveryStep.delivered:
        // Remove order and credit earnings
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
    }
    notifyListeners();
  }
}
