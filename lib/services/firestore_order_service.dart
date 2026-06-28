import 'package:cloud_firestore/cloud_firestore.dart';

// Set to true after Firebase setup. See PLAN.md.
const kUseFirebase = true;

/// Set by DriverAuthProvider once a real driver signs in. Falls back to a
/// placeholder only for the brief moment before auth resolves at startup.
String kDriverId = '';
String kDriverName = 'Driver';

// Mirrors the vendor/user apps' own copies of this same capacity check —
// how many concurrent deliveries one driver can realistically carry, and
// which order statuses count as "currently using up a driver's capacity".
const _kMaxOrdersPerDriver = 3;
const _kInFlightDeliveryStatuses = {'ready', 'assigned', 'pickedUp', 'enRoute'};

/// How long an order can sit unclaimed in the available-orders pool before
/// any online driver's app flags it as having no available drivers, so the
/// vendor gets told to call the customer instead of it sitting silently
/// forever. There's no server-side cron in this project, so this is checked
/// client-side off the live `streamAvailableOrders()` snapshot every online
/// driver already receives — whichever driver's app notices first does the
/// (idempotent) write.
const kUnclaimedOrderTimeout = Duration(minutes: 5);

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

/// Why this order shows as urgent on the driver card.
enum OrderUrgencyReason { none, rejectedBefore, longWait, both }

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

  DriverProfile copyWith({String? name, String? phone, String? campus}) => DriverProfile(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        studentId: studentId,
        campus: campus ?? this.campus,
        rating: rating,
        acceptanceRate: acceptanceRate,
        totalEarningsAllTime: totalEarningsAllTime,
        totalTripsAllTime: totalTripsAllTime,
        isSuspended: isSuspended,
      );
}

/// Payout bank info — kept out of DriverProfile/drivers/{uid} entirely
/// since that doc is world-readable to any signed-in user; this lives in a
/// locked-down drivers/{uid}/private/bankDetails subdocument instead.
class BankDetails {
  final String cardName;
  final String iban;
  final String mobile;
  const BankDetails({this.cardName = '', this.iban = '', this.mobile = ''});

  bool get isComplete => cardName.isNotEmpty && iban.isNotEmpty && mobile.isNotEmpty;
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
  final int rejectionCount;
  final DateTime? createdAt;
  final bool noDriversAvailable;

  const FirestoreOrder({
    required this.id,
    required this.restaurant,
    required this.restaurantAddr,
    this.deliveryAddress,
    required this.customerName,
    required this.total,
    required this.deliveryFee,
    required this.items,
    this.rejectionCount = 0,
    this.createdAt,
    this.noDriversAvailable = false,
  });

  int get itemCount => items.fold(0, (sum, i) => sum + ((i['qty'] as int?) ?? 1));
  double get payout => kDriverPayoutPerDelivery;

  Duration get waitingFor => createdAt != null
      ? DateTime.now().difference(createdAt!)
      : Duration.zero;

  OrderUrgencyReason get urgency {
    final longWait = waitingFor.inMinutes >= 3;
    final rejected = rejectionCount >= 2;
    if (rejected && longWait) return OrderUrgencyReason.both;
    if (rejected) return OrderUrgencyReason.rejectedBefore;
    if (longWait) return OrderUrgencyReason.longWait;
    return OrderUrgencyReason.none;
  }
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

  /// Persist profile-field edits (name/phone/campus) — only the fields
  /// passed are written.
  Future<void> updateDriverProfile(String uid, {String? name, String? phone, String? campus}) async {
    await _driversCol.doc(uid).set({
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (campus != null) 'campus': campus,
    }, SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> _bankDetailsDoc(String uid) =>
      _driversCol.doc(uid).collection('private').doc('bankDetails');

  Future<BankDetails> fetchBankDetails(String uid) async {
    final snap = await _bankDetailsDoc(uid).get();
    final data = snap.data();
    if (data == null) return const BankDetails();
    return BankDetails(
      cardName: data['cardName'] as String? ?? '',
      iban: data['iban'] as String? ?? '',
      mobile: data['mobile'] as String? ?? '',
    );
  }

  Future<void> updateBankDetails(String uid, BankDetails details) async {
    await _bankDetailsDoc(uid).set({
      'cardName': details.cardName,
      'iban': details.iban,
      'mobile': details.mobile,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of delivery orders the driver can claim — the vendor has
  /// accepted but the kitchen hasn't started ('awaitingDriver'). Accepting
  /// one is what actually starts the kitchen — the vendor deliberately
  /// doesn't cook until a driver has committed.
  Stream<List<FirestoreOrder>> streamAvailableOrders() {
    // Two-field filter: status + orderType. Requires a composite index on
    // (status ASC, orderType ASC) — create it in Firebase Console →
    // Firestore → Indexes → Composite → Add index.
    //
    // Why two fields instead of status-only + client filter:
    // The security rule for orders allows a driver to read a doc only if
    // status=='awaitingDriver' && orderType=='delivery'. If any pickup order
    // sits in awaitingDriver state and the query returns it, Firestore
    // evaluates the rule for that doc and denies it — which kills the ENTIRE
    // query stream for that driver (PERMISSION_DENIED, not just that doc).
    // Filtering server-side ensures every returned doc satisfies the rule.
    return _col
        .where('status', isEqualTo: 'awaitingDriver')
        .where('orderType', isEqualTo: 'delivery')
        .snapshots()
        .map((snap) {
      final docs = snap.docs.where((d) {
        final data = d.data();
        // Skip orders already claimed (non-null, non-empty driverId)
        final driverId = data['driverId'];
        if (driverId != null && (driverId as String).isNotEmpty) return false;
        return true;
      }).toList();
      // Sort by createdAt ascending (oldest first) client-side.
      // Uses Timestamp.compareTo which is safe; falls back to 0 for non-Timestamp types.
      docs.sort((a, b) {
        final at = a.data()['createdAt'];
        final bt = b.data()['createdAt'];
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        if (at is Timestamp && bt is Timestamp) return at.compareTo(bt);
        return 0;
      });
      // Pass the Firestore document ID explicitly — d.data() does NOT contain
      // the document ID, so d.data()['id'] is null if the vendor app didn't
      // write an 'id' field. That null cast was the root cause of the stream
      // error → "Reconnecting" loop on the Nothing Phone.
      return docs.map((d) => _fromFirestore(d.id, d.data())).toList();
    });
  }

  /// Flips `noDriversAvailable` for an order that's sat unclaimed past
  /// [kUnclaimedOrderTimeout] with nobody free to take it — reuses the same
  /// flag and capacity check `abandonDelivery` already uses when a driver
  /// gives up an order, just triggered by elapsed time instead of a give-up
  /// action. The vendor app already has a push notification wired to this
  /// flag ("No Drivers Available — consider calling the customer"), and the
  /// customer app already shows a Pick-Up-Myself/Cancel banner off it — both
  /// built for the driver-abandons-mid-delivery case, reused here as-is.
  Future<void> flagIfUnclaimedTooLong(FirestoreOrder order) async {
    // Already flagged — skip entirely, including the capacity check below.
    // `noDriversAvailableAt` uses serverTimestamp(), which is a genuinely
    // new value on every write, so re-writing it on every snapshot tick
    // would re-trigger this same listener for every online driver in a
    // feedback loop (write -> new snapshot -> re-check -> write again),
    // forever, for as long as the order sits stale. This check is what
    // makes the whole thing a one-time flip instead of an unbounded loop.
    if (order.noDriversAvailable) return;

    final createdAt = order.createdAt;
    if (createdAt == null) return;
    if (DateTime.now().difference(createdAt) < kUnclaimedOrderTimeout) return;

    final hasCapacity = await hasDeliveryCapacity();
    if (hasCapacity) return;

    await _col.doc(order.id).update({
      'noDriversAvailable': true,
      'noDriversAvailableAt': FieldValue.serverTimestamp(),
    });
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
    if (kDriverId.isEmpty) {
      throw Exception('Driver account is not fully loaded yet. Please try again.');
    }
    final docRef = _col.doc(orderId);
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      final data = snap.data();
      if (data == null) throw OrderAlreadyTakenException();
      final status = data['status'] as String?;
      final existingDriverId = data['driverId'];
      // Treat empty-string driverId the same as null — it means a previous
      // accept attempt wrote an empty ID (e.g. auth hadn't resolved yet) and
      // the order is effectively still unclaimed.
      final alreadyClaimed =
          existingDriverId != null && (existingDriverId as String).isNotEmpty;
      final claimable = status == 'awaitingDriver' || status == 'ready';
      if (alreadyClaimed) throw OrderAlreadyTakenException();
      if (!claimable) throw OrderStatusChangedException(status);
      txn.update(docRef, {
        if (status == 'awaitingDriver') 'status': 'preparing',
        if (status == 'ready') 'status': 'assigned',
        'driverId': kDriverId,
        'driverName': kDriverName,
        // Clears a stale flag from flagIfUnclaimedTooLong/abandonDelivery —
        // without this, an order that sat flagged "no drivers available"
        // and then got claimed normally (a driver came back online) would
        // leave the customer's tracking screen stuck showing the "pick up
        // yourself or cancel" banner forever, since nothing else clears it.
        'noDriversAvailable': false,
      });
    });
  }

  /// Live (status, cancelReason) for a single order — watched for the whole
  /// time a driver has it active, both to wait for the vendor marking it
  /// 'ready' and to catch the vendor cancelling it out from under the driver
  /// after it's already been accepted. cancelReason is only ever non-null
  /// when status is 'cancelled'.
  Stream<(String?, String?)> watchOrderStatus(String orderId) {
    return _col.doc(orderId).snapshots().map((snap) {
      final d = snap.data();
      return (d?['status'] as String?, d?['cancelReason'] as String?);
    });
  }

  /// Watches for the incoming order being cancelled by the vendor while the
  /// driver is still deciding (within the 30-second window). Emits true when
  /// the order is no longer claimable so the driver card can be auto-dismissed.
  Stream<bool> watchOrderCancelled(String orderId) {
    return _col.doc(orderId).snapshots().map((snap) {
      if (!snap.exists) return true;
      final status = snap.data()?['status'] as String?;
      return status == 'cancelled' || status == 'delivered';
    });
  }

  /// Increments the rejection counter on an order doc when the driver's timer
  /// expires (auto-decline). Used by the vendor app / escalation logic to
  /// decide when to alert the customer that no driver is available.
  Future<void> recordAutoRejection(String orderId) async {
    await _col.doc(orderId).set({
      'rejectionCount': FieldValue.increment(1),
      'lastRejectedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Escalates an order that has exhausted available drivers.
  ///
  /// Sets `noDriversAvailable: true` — the same flag `flagIfUnclaimedTooLong`
  /// and `abandonDelivery` use — so the vendor and customer apps' existing
  /// "No Drivers Available" banners and push-notification hooks fire without
  /// any new consumers. Also records `escalatedReason` as metadata for
  /// analytics; does NOT change `status` to 'escalated' since no consumer
  /// in vendor/customer apps handles that status yet.
  Future<void> escalateOrder(String orderId) async {
    await _col.doc(orderId).set({
      'noDriversAvailable': true,
      'noDriversAvailableAt': FieldValue.serverTimestamp(),
      'escalatedReason': 'noDriverAvailable',
    }, SetOptions(merge: true));
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

  /// Driver gives up an order before pickup — puts it back in the
  /// available-orders pool (status -> 'awaitingDriver', driverId cleared)
  /// instead of leaving the vendor and customer stuck with an assigned
  /// driver who's gone quiet. If no other driver is online to pick it up,
  /// immediately flags noDriversAvailable so the vendor/customer find out
  /// right away instead of only after some other driver eventually declines.
  Future<void> abandonDelivery(String orderId, {required String reason}) async {
    await _col.doc(orderId).update({
      'status': 'awaitingDriver',
      'driverId': null,
      'driverName': null,
      'driverAtRestaurant': false,
      'driverCancelReason': reason,
    });

    final hasReplacement = await hasDeliveryCapacity();
    if (!hasReplacement) {
      await _col.doc(orderId).update({
        'noDriversAvailable': true,
        'noDriversAvailableAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Mirrors the vendor app's own capacity check — true if any online
  /// driver has a free delivery slot right now.
  Future<bool> hasDeliveryCapacity() async {
    final driversSnap = await _driversCol.where('isOnline', isEqualTo: true).get();
    final onlineDrivers = driversSnap.docs.length;
    if (onlineDrivers == 0) return false;

    final ordersSnap = await _col.where('orderType', isEqualTo: 'delivery').get();
    final inFlight = ordersSnap.docs
        .where((d) => _kInFlightDeliveryStatuses.contains(d.data()['status'] as String?))
        .length;
    return (onlineDrivers * _kMaxOrdersPerDriver) - inFlight > 0;
  }

  /// Fetches trip history for an arbitrary date range (used by the custom
  /// date picker on the Earnings screen). Mirrors [fetchTripHistory] but
  /// accepts an explicit [end] bound instead of always reading to now.
  Future<List<DeliveredTrip>> fetchTripHistoryForRange(
    String uid,
    DateTime start,
    DateTime end,
  ) async {
    final snap = await _col
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'delivered')
        .where('deliveredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('deliveredAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
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

  static FirestoreOrder _fromFirestore(String docId, Map<String, dynamic> d) {
    final rawItems = d['items'] as List<dynamic>? ?? [];
    return FirestoreOrder(
      // Firestore document ID is authoritative — d['id'] is a best-effort
      // fallback for vendor apps that mirror the ID into the document body.
      id: docId.isNotEmpty ? docId : (d['id'] as String? ?? docId),
      restaurant: d['restaurantName'] as String? ?? 'Restaurant',
      restaurantAddr: '${d['restaurantName'] ?? 'Restaurant'} UDST Qatar',
      deliveryAddress: d['deliveryAddress'] as String?,
      customerName: d['customerName'] as String? ?? 'Customer',
      total: (d['total'] as num?)?.toDouble() ?? 0,
      deliveryFee: (d['deliveryFee'] as num?)?.toDouble() ?? 0,
      items: rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      rejectionCount: (d['rejectionCount'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      noDriversAvailable: d['noDriversAvailable'] as bool? ?? false,
    );
  }
}

/// Thrown when the order's status changed to something non-claimable (e.g.
/// cancelled by the vendor) while the driver was deciding — distinct from
/// [OrderAlreadyTakenException] so the UI can show a more accurate message.
class OrderStatusChangedException implements Exception {
  final String? status;
  const OrderStatusChangedException(this.status);

  @override
  String toString() => status == 'cancelled'
      ? 'This order was cancelled by the vendor.'
      : 'This order is no longer available.';
}
