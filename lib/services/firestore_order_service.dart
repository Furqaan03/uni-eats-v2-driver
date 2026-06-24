import 'package:cloud_firestore/cloud_firestore.dart';

// Set to true after Firebase setup. See PLAN.md.
const kUseFirebase = true;

/// Set by DriverAuthProvider once a real driver signs in. Falls back to a
/// placeholder only for the brief moment before auth resolves at startup.
String kDriverId = '';
String kDriverName = 'Driver';

/// Flat payout per delivery — confirmed fixed business rule, not derived
/// from the order's delivery fee or total. Previously this was computed as
/// `deliveryFee > 0 ? deliveryFee : total * 0.15`, which paid drivers a
/// variable amount depending on order size instead of the actual agreed
/// flat rate.
const kDriverPayoutPerDelivery = 5.0;

/// Thrown by [FirestoreOrderService.acceptOrder] when another driver
/// (or the vendor pulling the order back) already claimed it first.
class OrderAlreadyTakenException implements Exception {
  @override
  String toString() => 'This order was just taken by another driver.';
}

/// One real completed delivery, for the Earnings screen's trip history.
class DeliveredTrip {
  final String orderNumber;
  final String restaurant;
  final String customerName;
  final String dropoff;
  final double amount;
  final double orderTotal;
  final int itemCount;
  final bool isPickup;
  final DateTime placedAt;
  final DateTime deliveredAt;

  const DeliveredTrip({
    required this.orderNumber,
    required this.restaurant,
    required this.customerName,
    required this.dropoff,
    required this.amount,
    required this.orderTotal,
    required this.itemCount,
    required this.isPickup,
    required this.placedAt,
    required this.deliveredAt,
  });

  Duration get tripDuration => deliveredAt.difference(placedAt);
}

/// A driver's Firestore profile.
class DriverProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String studentId;
  final String campus;
  final double rating;
  final int acceptanceRate;
  final double totalEarningsAllTime;
  final int totalTripsAllTime;
  final bool isSuspended;

  const DriverProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.studentId,
    this.campus = 'UDST',
    this.rating = 5.0,
    this.acceptanceRate = 100,
    this.totalEarningsAllTime = 0,
    this.totalTripsAllTime = 0,
    this.isSuspended = false,
  });
}

/// Firestore order data as a plain map the driver provider can use.
class FirestoreOrder {
  final String id;
  final String restaurant;
  final String restaurantAddr;
  final String? deliveryAddress;
  final String customerName;
  final double total;
  final double deliveryFee;
  final List<Map<String, dynamic>> items;

  const FirestoreOrder({
    required this.id,
    required this.restaurant,
    required this.restaurantAddr,
    this.deliveryAddress,
    required this.customerName,
    required this.total,
    required this.deliveryFee,
    required this.items,
  });

  int get itemCount => items.fold(0, (sum, i) => sum + ((i['qty'] as int?) ?? 1));
  double get payout => kDriverPayoutPerDelivery;
}

class FirestoreOrderService {
  FirestoreOrderService._();
  static final FirestoreOrderService instance = FirestoreOrderService._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('orders');

  CollectionReference<Map<String, dynamic>> get _driversCol =>
      FirebaseFirestore.instance.collection('drivers');

  Future<DriverProfile?> fetchDriverProfile(String uid) async {
    final snap = await _driversCol.doc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    return DriverProfile(
      id: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      campus: data['campus'] as String? ?? 'UDST',
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      acceptanceRate: (data['acceptanceRate'] as num?)?.toInt() ?? 100,
      totalEarningsAllTime: (data['totalEarningsAllTime'] as num?)?.toDouble() ?? 0,
      totalTripsAllTime: (data['totalTripsAllTime'] as num?)?.toInt() ?? 0,
      isSuspended: data['isSuspended'] as bool? ?? false,
    );
  }

  Future<void> createDriverProfile(DriverProfile profile) async {
    await _driversCol.doc(profile.id).set({
      'name': profile.name,
      'email': profile.email,
      'phone': profile.phone,
      'studentId': profile.studentId,
      'campus': profile.campus,
      'rating': profile.rating,
      'acceptanceRate': profile.acceptanceRate,
      'totalEarningsAllTime': profile.totalEarningsAllTime,
      'totalTripsAllTime': profile.totalTripsAllTime,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Increments lifetime earnings/trips after a delivery completes.
  Future<void> recordCompletedDelivery(String uid, double payout) async {
    await _driversCol.doc(uid).set({
      'totalEarningsAllTime': FieldValue.increment(payout),
      'totalTripsAllTime': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Stream of delivery orders the driver can claim — the vendor has
  /// accepted but the kitchen hasn't started ('awaitingDriver'). Accepting
  /// one is what actually starts the kitchen — the vendor deliberately
  /// doesn't cook until a driver has committed.
  Stream<List<FirestoreOrder>> streamAvailableOrders() {
    return _col
        .where('status', isEqualTo: 'awaitingDriver')
        .where('orderType', isEqualTo: 'delivery')
        .where('driverId', isNull: true)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => _fromFirestore(d.data())).toList());
  }

  /// Assign this driver to an order (accept). Uses a transaction so two
  /// drivers racing to accept the same order can't both succeed — whichever
  /// transaction commits first wins; the loser sees [OrderAlreadyTakenException].
  ///
  /// Claiming an 'awaitingDriver' order is what starts the kitchen — status
  /// flips straight to 'preparing'. (A defensive fallback also allows
  /// claiming an already-'ready' order with no driver attached, though that
  /// shouldn't happen under the normal flow.)
  Future<void> acceptOrder(String orderId) async {
    final docRef = _col.doc(orderId);
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      final data = snap.data();
      final status = data?['status'] as String?;
      final claimable = status == 'awaitingDriver' || status == 'ready';
      if (data == null || data['driverId'] != null || !claimable) {
        throw OrderAlreadyTakenException();
      }
      txn.update(docRef, {
        if (status == 'awaitingDriver') 'status': 'preparing',
        if (status == 'ready') 'status': 'assigned',
        'driverId': kDriverId,
        'driverName': kDriverName,
      });
    });
  }

  /// Live status string for a single order — used after accepting to wait
  /// for the vendor to mark it 'ready' without polling.
  Stream<String?> watchOrderStatus(String orderId) {
    return _col.doc(orderId).snapshots().map((snap) => snap.data()?['status'] as String?);
  }

  /// Records that a driver declined an offered order, for later analysis —
  /// doesn't change the order itself (it stays available for other drivers).
  Future<void> recordDecline(String orderId, String reason) async {
    await FirebaseFirestore.instance.collection('orderDeclines').add({
      'orderId': orderId,
      'driverId': kDriverId,
      'driverName': kDriverName,
      'reason': reason,
      'declinedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update delivery step status.
  Future<void> updateDeliveryStatus(String orderId, String status) async {
    await _col.doc(orderId).update({
      'status': status,
      if (status == 'delivered') 'deliveredAt': FieldValue.serverTimestamp(),
    });
  }

  /// Flags that the driver is physically at the restaurant — kept separate
  /// from `status` so an early arrival (before the kitchen marks the order
  /// ready) never overwrites the vendor's own preparing/ready progress.
  Future<void> markArrivedAtRestaurant(String orderId) async {
    await _col.doc(orderId).update({'driverAtRestaurant': true});
  }

  /// Real earnings/trip count for [uid]'s deliveries completed since
  /// midnight today — replaces the old hardcoded dashboard seed values.
  Future<({double earnings, int trips})> fetchTodayStats(String uid) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snap = await _col
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'delivered')
        .where('deliveredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    final earnings = snap.docs.length * kDriverPayoutPerDelivery;
    return (earnings: earnings, trips: snap.docs.length);
  }

  /// Real completed-delivery history since [since] — backs the Earnings
  /// screen's Trip History list (previously hardcoded mock trips).
  Future<List<DeliveredTrip>> fetchTripHistory(String uid, DateTime since) async {
    final snap = await _col
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'delivered')
        .where('deliveredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();

    final trips = snap.docs.map((doc) {
      final d = doc.data();
      final total = (d['total'] as num?)?.toDouble() ?? 0;
      final deliveredAt = (d['deliveredAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final placedAt = (d['createdAt'] as Timestamp?)?.toDate() ?? deliveredAt;
      final items = d['items'] as List<dynamic>? ?? const [];
      return DeliveredTrip(
        orderNumber: d['orderNumber'] as String? ?? '#${doc.id}',
        restaurant: d['restaurantName'] as String? ?? 'Restaurant',
        customerName: d['customerName'] as String? ?? 'Customer',
        dropoff: d['deliveryAddress'] as String? ?? 'Campus',
        amount: kDriverPayoutPerDelivery,
        orderTotal: total,
        itemCount: items.fold<int>(0, (sum, i) => sum + ((i['qty'] as num?)?.toInt() ?? 1)),
        isPickup: (d['orderType'] as String?) == 'pickup',
        placedAt: placedAt,
        deliveredAt: deliveredAt,
      );
    }).toList()
      ..sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));
    return trips;
  }

  /// Update the driver's online status in /drivers collection.
  Future<void> setDriverOnline(bool isOnline) async {
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(kDriverId)
        .set({'isOnline': isOnline, 'name': kDriverName}, SetOptions(merge: true));
  }

  static FirestoreOrder _fromFirestore(Map<String, dynamic> d) {
    final rawItems = d['items'] as List<dynamic>? ?? [];
    return FirestoreOrder(
      id: d['id'] as String,
      restaurant: d['restaurantName'] as String? ?? 'Restaurant',
      restaurantAddr: '${d['restaurantName'] ?? 'Restaurant'} UDST Qatar',
      deliveryAddress: d['deliveryAddress'] as String?,
      customerName: d['customerName'] as String? ?? 'Customer',
      total: (d['total'] as num?)?.toDouble() ?? 0,
      deliveryFee: (d['deliveryFee'] as num?)?.toDouble() ?? 0,
      items: rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }
}
