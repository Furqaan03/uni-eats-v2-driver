import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'push/order_push.dart';

// Set to true after Firebase setup. See PLAN.md.
const kUseFirebase = true;

/// Data environment (mirrors the admin dashboard's Live/Test switch).
///   test → unprefixed collections (all current data). Default.
///   live → `live_`-prefixed collections (real launch data), kept fully separate.
/// Flip [current] to [DataEnv.live] at real launch. Only TOP-LEVEL collection
/// names are prefixed — subcollections inherit their parent's namespace.
enum DataEnv { test, live }

class AppEnv {
  AppEnv._();
  static const DataEnv current = DataEnv.test;
  static String get _prefix => current == DataEnv.live ? 'live_' : '';
  static String col(String name) => '$_prefix$name';
}

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

/// How a trip ended, from the driver's point of view.
///   • delivered — completed normally (the only kind that pays out).
///   • cancelled — the vendor cancelled it after this driver was assigned.
///   • abandoned — the driver gave it up before pickup (logged separately,
///     since clearing driverId on abandon removes the order from read scope).
enum TripOutcome { delivered, cancelled, abandoned }

/// One trip in the driver's history. Named [DeliveredTrip] for back-compat
/// (the Earnings screen consumes it), but now also carries non-delivered
/// outcomes for the History screen. The Earnings queries only ever fetch
/// `status == 'delivered'`, so they continue to see delivered trips only.
class DeliveredTrip {
  final String orderNumber;
  final String restaurant;
  final String customerName;
  final String dropoff;
  final double amount;
  final double orderTotal;
  final int itemCount;
  final List<Map<String, dynamic>> items;
  final bool isPickup;
  final DateTime placedAt;

  /// When the trip concluded — delivery time for delivered trips, cancel/
  /// abandon time otherwise. Kept named `deliveredAt` so existing Earnings
  /// grouping/bucketing keeps working unchanged.
  final DateTime deliveredAt;

  final TripOutcome outcome;
  final String? cancelReason;
  final bool customerUnreachable;
  final bool runningLate;
  final bool driverIncident;
  final String? driverIncidentReason;

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
    this.items = const [],
    this.outcome = TripOutcome.delivered,
    this.cancelReason,
    this.customerUnreachable = false,
    this.runningLate = false,
    this.driverIncident = false,
    this.driverIncidentReason,
  });

  Duration get tripDuration => deliveredAt.difference(placedAt);

  bool get isDelivered => outcome == TripOutcome.delivered;
  bool get isCancelled => outcome != TripOutcome.delivered;
  bool get hasIncidentFlags =>
      customerUnreachable || runningLate || driverIncident;
}

/// A driver's Firestore profile.
/// The documents a driver must have on file. Stored as a map on the
/// drivers/{uid} doc: { 'qid': 'verified', 'studentId': 'pending', ... }.
/// A missing key means the document hasn't been submitted yet.
const List<({String key, String label})> kDriverDocuments = [
  (key: 'qid', label: 'QID'),
  (key: 'studentId', label: 'Student ID'),
  (key: 'classSchedule', label: 'Class Schedule'),
  (key: 'cv', label: 'CV / Resume'),
];

class DriverProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String studentId;
  final String campus;
  final String? photoUrl;
  final double rating;
  final int acceptanceRate;
  final double totalEarningsAllTime;
  final int totalTripsAllTime;
  final bool isSuspended;

  /// Per-document review status keyed by [kDriverDocuments] key.
  /// Values: 'verified' | 'pending' | 'rejected' (or absent = not submitted).
  final Map<String, String> documents;

  /// Star → count of ratings received, e.g. { 5: 182, 4: 20, ... }.
  final Map<int, int> ratingBreakdown;

  const DriverProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.studentId,
    this.campus = 'UDST',
    this.photoUrl,
    this.rating = 5.0,
    this.acceptanceRate = 100,
    this.totalEarningsAllTime = 0,
    this.totalTripsAllTime = 0,
    this.isSuspended = false,
    this.documents = const {},
    this.ratingBreakdown = const {},
  });

  /// A driver is verified once their identity documents (QID + Student ID)
  /// are both verified and the account isn't suspended. Drives the avatar
  /// badge — previously shown unconditionally.
  bool get isVerified =>
      !isSuspended &&
      documents['qid'] == 'verified' &&
      documents['studentId'] == 'verified';

  /// Total number of ratings counted in [ratingBreakdown].
  int get totalRatingCount =>
      ratingBreakdown.values.fold(0, (sum, c) => sum + c);

  DriverProfile copyWith({
    String? name,
    String? phone,
    String? campus,
    String? photoUrl,
    Map<String, String>? documents,
  }) =>
      DriverProfile(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        studentId: studentId,
        campus: campus ?? this.campus,
        photoUrl: photoUrl ?? this.photoUrl,
        rating: rating,
        acceptanceRate: acceptanceRate,
        totalEarningsAllTime: totalEarningsAllTime,
        totalTripsAllTime: totalTripsAllTime,
        isSuspended: isSuspended,
        documents: documents ?? this.documents,
        ratingBreakdown: ratingBreakdown,
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
      FirebaseFirestore.instance.collection(AppEnv.col('orders'));

  CollectionReference<Map<String, dynamic>> get _driversCol =>
      FirebaseFirestore.instance.collection(AppEnv.col('drivers'));

  /// Save/refresh this driver's FCM token so the vendor app can alert them to
  /// new deliveries. Uses arrayUnion so the driver's multiple devices coexist
  /// (a single `fcmToken` field meant a new device / token rotation overwrote
  /// the previous one). Merge leaves isOnline / isSuspended untouched,
  /// satisfying the drivers update rule.
  Future<void> saveFcmToken(String token) async {
    if (kDriverId.isEmpty || token.isEmpty) return;
    await _driversCol.doc(kDriverId).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  /// Swap a rotated-away token for the new one so the driver's `fcmTokens`
  /// array doesn't grow unbounded as FCM rotates this device's token.
  /// (arrayUnion + arrayRemove can't touch the same field in one write.)
  Future<void> replaceFcmToken({String? oldToken, required String newToken}) async {
    if (kDriverId.isEmpty || newToken.isEmpty) return;
    final doc = _driversCol.doc(kDriverId);
    if (oldToken != null && oldToken.isNotEmpty && oldToken != newToken) {
      await doc.set({'fcmTokens': FieldValue.arrayRemove([oldToken])}, SetOptions(merge: true));
    }
    await doc.set({'fcmTokens': FieldValue.arrayUnion([newToken])}, SetOptions(merge: true));
  }

  /// The customer's FCM tokens for [orderId] — read from the token set the
  /// customer app snapshots onto the ORDER doc at creation. Reading users/{uid}
  /// directly is denied for the driver (that collection is self/admin-read
  /// only — see firestore.rules), so the order doc carries the tokens instead.
  Future<List<String>> fetchCustomerFcmTokensForOrder(String orderId) async {
    final orderSnap = await _col.doc(orderId).get();
    final embedded = orderSnap.data()?['customerFcmTokens'];
    final set = <String>{};
    if (embedded is List) {
      for (final t in embedded) {
        if (t is String && t.isNotEmpty) set.add(t);
      }
    }
    return set.toList();
  }

  /// The vendor's FCM tokens for [orderId] — reads the order's vendorId then the
  /// restaurant doc's token set, so the driver can tell the vendor "picked up"
  /// on every device the restaurant is signed in on.
  Future<List<String>> fetchVendorFcmTokensForOrder(String orderId) async {
    final orderSnap = await _col.doc(orderId).get();
    final vendorId = orderSnap.data()?['vendorId'];
    if (vendorId is! String || vendorId.isEmpty) return const [];
    final restSnap =
        await FirebaseFirestore.instance.collection(AppEnv.col('restaurants')).doc(vendorId).get();
    return _tokensOf(restSnap.data());
  }

  /// Extracts the device-token set from an entity doc — the `fcmTokens` array
  /// plus any legacy single `fcmToken`, deduped.
  static List<String> _tokensOf(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final set = <String>{};
    final arr = data['fcmTokens'];
    if (arr is List) {
      for (final t in arr) {
        if (t is String && t.isNotEmpty) set.add(t);
      }
    }
    final single = data['fcmToken'];
    if (single is String && single.isNotEmpty) set.add(single);
    return set.toList();
  }

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
      photoUrl: (data['photoUrl'] as String?)?.isEmpty ?? true
          ? null
          : data['photoUrl'] as String?,
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      acceptanceRate: (data['acceptanceRate'] as num?)?.toInt() ?? 100,
      totalEarningsAllTime: (data['totalEarningsAllTime'] as num?)?.toDouble() ?? 0,
      totalTripsAllTime: (data['totalTripsAllTime'] as num?)?.toInt() ?? 0,
      isSuspended: data['isSuspended'] as bool? ?? false,
      documents: _parseStringMap(data['documents']),
      ratingBreakdown: _parseRatingBreakdown(data['ratingBreakdown']),
    );
  }

  static Map<String, String> _parseStringMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (v is String) out[k.toString()] = v;
    });
    return out;
  }

  static Map<int, int> _parseRatingBreakdown(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <int, int>{};
    raw.forEach((k, v) {
      final star = int.tryParse(k.toString());
      final count = (v as num?)?.toInt();
      if (star != null && count != null) out[star] = count;
    });
    return out;
  }

  static const _cloudinaryCloud = 'dhsq8isal';
  static const _cloudinaryPreset = 'unieats';

  Future<String> _uploadToCloudinary(File file, String folder) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloud/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _cloudinaryPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed (${response.statusCode}): $body');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }

  /// Uploads a new avatar image to Cloudinary and writes its URL onto the
  /// driver doc. Returns the public download URL.
  Future<String> updateProfilePhoto(String uid, File image) async {
    final url = await _uploadToCloudinary(image, 'driver_avatars/$uid');
    await _driversCol.doc(uid).set({'photoUrl': url}, SetOptions(merge: true));
    return url;
  }

  /// Uploads a (re)submitted document file and marks it 'pending' review.
  Future<void> submitDocument(String uid, String docKey, File file) async {
    await _uploadToCloudinary(file, 'driver_documents/$uid');
    await _driversCol.doc(uid).set({
      'documents': {docKey: 'pending'},
    }, SetOptions(merge: true));
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
      // Persist explicitly so the rules' suspension guard has a value to
      // compare against on later self-updates (avatar, name, documents).
      'isSuspended': profile.isSuspended,
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
      // write an 'id' field.
      //
      // Parse each doc defensively: a throw inside this .map() (e.g. a vendor
      // app writing `createdAt` or `items` in an unexpected shape) propagates
      // out of the stream transform and kills the ENTIRE listener — the same
      // "Reconnecting" loop a PERMISSION_DENIED causes, just triggered by one
      // bad document instead of a rule. Skip the offending doc and keep the
      // rest of the pool flowing. (A server-side PERMISSION_DENIED can't be
      // caught here — it errors the snapshot itself, not an individual map()
      // call — that's handled by the orders read rule + DriverProvider.onError.)
      final parsed = <FirestoreOrder>[];
      for (final d in docs) {
        try {
          parsed.add(_fromFirestore(d.id, d.data()));
        } catch (e) {
          debugPrint('[FirestoreOrderService] skipping unparseable order ${d.id}: $e');
        }
      }
      return parsed;
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
    // A driver committed → the kitchen starts. Let the customer know.
    OrderPush.notifyCustomer(
      orderId: orderId,
      title: 'A driver is on it 👨‍🍳',
      body: 'Your order has been accepted and is being prepared.',
    ).catchError((e) => debugPrint('[push] notifyCustomer (accept) failed: $e'));
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

  /// Watches for an offered order becoming unavailable while the driver is
  /// still deciding (within the 30-second window). Emits true when the order
  /// is no longer claimable so the incoming-order card auto-dismisses.
  ///
  /// Triggers on three distinct events:
  ///   • vendor cancels the order         (status == 'cancelled')
  ///   • another driver claims it first   (status leaves 'awaitingDriver'/'ready')
  ///   • order is already delivered       (status == 'delivered')
  Stream<({bool gone, bool takenByOther})> watchOrderUnavailable(String orderId) {
    return _col.doc(orderId).snapshots().map((snap) {
      if (!snap.exists) return (gone: true, takenByOther: false);
      final status = snap.data()?['status'] as String?;
      if (status == 'cancelled' || status == 'delivered' || status == null) {
        return (gone: true, takenByOther: false);
      }
      // Still claimable states — keep waiting.
      if (status == 'awaitingDriver' || status == 'ready') {
        return (gone: false, takenByOther: false);
      }
      // Any other status (preparing, assigned, pickedUp, …) means another
      // driver already claimed it.
      return (gone: true, takenByOther: true);
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
    await FirebaseFirestore.instance.collection(AppEnv.col('orderDeclines')).add({
      'orderId': orderId,
      'driverId': kDriverId,
      'driverName': kDriverName,
      'reason': reason,
      'declinedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Live `isSuspended` flag on a driver's own doc — watched for the whole
  /// session so an admin suspending a driver mid-shift takes effect
  /// immediately (force sign-out) instead of only at the next app launch.
  Stream<bool> watchSuspension(String uid) {
    return _driversCol
        .doc(uid)
        .snapshots()
        .map((s) => s.data()?['isSuspended'] as bool? ?? false);
  }

  /// Driver can't reach the customer at the drop-off. Written while status
  /// stays 'arrivedAtCustomer' — a self-transition the assigned-driver rule
  /// branch already allows — so the customer/vendor apps can prompt a
  /// response without the driver having to abandon a delivery they've
  /// physically completed the run for. Does NOT change `status`.
  Future<void> flagCustomerUnreachable(String orderId, {String? note}) async {
    await _col.doc(orderId).update({
      'customerUnreachable': true,
      'customerUnreachableAt': FieldValue.serverTimestamp(),
      if (note != null) 'customerUnreachableNote': note,
    });
  }

  /// Clears the unreachable flag once the customer responds.
  Future<void> clearCustomerUnreachable(String orderId) async {
    await _col.doc(orderId).update({'customerUnreachable': false});
  }

  /// Flags that a picked-up delivery has run past its promised ETA so the
  /// customer app can show a proactive "running late" note. Written at a
  /// post-pickup status (self-transition), so no rule change is needed.
  Future<void> flagRunningLate(String orderId) async {
    await _col.doc(orderId).update({
      'runningLate': true,
      'runningLateAt': FieldValue.serverTimestamp(),
    });
  }

  /// A blocking incident the driver hit AFTER pickup (accident, damaged food,
  /// safety issue). The food is already in hand, so unlike abandonDelivery
  /// this can't return the order to the pool — instead it raises an
  /// admin/vendor alert flag without rolling back status. Written at a
  /// post-pickup status (self-transition), so no rule change is needed.
  Future<void> reportIncident(String orderId, {required String reason}) async {
    await _col.doc(orderId).update({
      'driverIncident': true,
      'driverIncidentReason': reason,
      'driverIncidentAt': FieldValue.serverTimestamp(),
    });
  }

  /// Lightweight liveness heartbeat on the driver's own doc so a future
  /// server/admin reaper (and the vendor app's capacity math) can tell a live
  /// driver from one whose app died mid-shift. Own-doc merge write that
  /// leaves isSuspended untouched, satisfying the drivers update rule.
  Future<void> heartbeat() async {
    if (kDriverId.isEmpty) return;
    await _driversCol.doc(kDriverId).set(
      {'lastActiveAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Driver tapped "I'm near" — push the customer to be ready. No status
  /// change; purely a heads-up notification.
  Future<void> notifyCustomerDriverNear(String orderId) {
    return OrderPush.notifyCustomer(
      orderId: orderId,
      title: 'Your driver is almost there 🛵',
      body: 'Please be ready to collect your order.',
    );
  }

  /// Update delivery step status.
  Future<void> updateDeliveryStatus(String orderId, String status) async {
    await _col.doc(orderId).update({
      'status': status,
      if (status == 'delivered') 'deliveredAt': FieldValue.serverTimestamp(),
    });
    _notifyCustomerOfStatus(orderId, status);
  }

  // Push a customer-facing message for delivery-status transitions the driver
  // drives. Fire-and-forget — a failed push must never fail the status write.
  void _notifyCustomerOfStatus(String orderId, String status) {
    final (title, body) = switch (status) {
      'pickedUp' || 'enRoute' => ('Out for delivery 🛵', 'Your order is on its way.'),
      'arrivedAtCustomer' => ('Your driver has arrived 📍', 'Your driver is at your location.'),
      'delivered' => ('Delivered ✅', 'Enjoy your order! Tap to rate it.'),
      _ => ('', ''),
    };
    if (title.isNotEmpty) {
      OrderPush.notifyCustomer(orderId: orderId, title: title, body: body)
          .catchError((e) => debugPrint('[push] notifyCustomer failed: $e'));
    }
    // Tell the vendor the moment the driver collects the order, so their
    // dashboard's "out for delivery" move is backed by a push too.
    if (status == 'pickedUp') {
      OrderPush.notifyVendor(
        orderId: orderId,
        title: 'Order picked up',
        body: 'The driver has collected the order and is on the way.',
      ).catchError((e) => debugPrint('[push] notifyVendor (pickedUp) failed: $e'));
    }
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
    // Snapshot the order while we can still read it (driverId == us). The
    // update below clears driverId and returns the order to the pool, after
    // which it leaves our read scope entirely — so this is the only chance to
    // capture it for the driver's own abandoned-trips history.
    Map<String, dynamic>? snapshot;
    try {
      snapshot = (await _col.doc(orderId).get()).data();
    } catch (e) {
      debugPrint('[FirestoreOrderService] abandon snapshot read failed: $e');
    }

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

    // Log the abandoned trip under the driver's own doc so it shows in History.
    // Fail-soft: a denied write (rules not yet shipped) must never fail the
    // abandon itself — the order is already safely back in the pool.
    if (snapshot != null && kDriverId.isNotEmpty) {
      final items = (snapshot['items'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      try {
        await _driversCol
            .doc(kDriverId)
            .collection('abandonedTrips')
            .doc(orderId)
            .set({
          'orderNumber': snapshot['orderNumber'] ?? '#$orderId',
          'restaurantName': snapshot['restaurantName'] ?? 'Restaurant',
          'customerName': snapshot['customerName'] ?? 'Customer',
          'deliveryAddress': snapshot['deliveryAddress'] ?? 'Campus',
          'total': snapshot['total'] ?? 0,
          'items': items,
          'itemCount':
              items.fold<int>(0, (sum, i) => sum + ((i['qty'] as num?)?.toInt() ?? 1)),
          'orderType': snapshot['orderType'] ?? 'delivery',
          'createdAt': snapshot['createdAt'],
          'reason': reason,
          'abandonedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[FirestoreOrderService] abandon log write failed: $e');
      }
    }
  }

  /// Mirrors the vendor app's own capacity check — true if any online
  /// driver has a free delivery slot right now.
  ///
  /// NOTE: the in-flight count below reads delivery orders assigned to OTHER
  /// drivers, which the hardened Firestore rules deny (a driver may only read
  /// the unclaimed pool + their own orders). That read therefore throws under
  /// the deployed rules. We FAIL SAFE: if we can't compute the global in-flight
  /// count we assume capacity exists (return true) rather than throwing, so the
  /// caller never wrongly flags an order "No Drivers Available". Erring the
  /// other way (false on error) would spam customers with false "no driver"
  /// banners. A precise global capacity check needs either a server-side
  /// aggregate (no Cloud Functions in this project) or a rules change to let
  /// drivers read in-flight delivery orders — deliberately left as a product
  /// decision rather than silently re-widening order reads.
  Future<bool> hasDeliveryCapacity() async {
    final driversSnap = await _driversCol.where('isOnline', isEqualTo: true).get();
    final onlineDrivers = driversSnap.docs.length;
    if (onlineDrivers == 0) return false;

    try {
      final ordersSnap = await _col.where('orderType', isEqualTo: 'delivery').get();
      final inFlight = ordersSnap.docs
          .where((d) => _kInFlightDeliveryStatuses.contains(d.data()['status'] as String?))
          .length;
      return (onlineDrivers * _kMaxOrdersPerDriver) - inFlight > 0;
    } catch (e) {
      debugPrint('[FirestoreOrderService] hasDeliveryCapacity in-flight read failed '
          '(assuming capacity available): $e');
      return true;
    }
  }

  /// Maps a raw order document to a [DeliveredTrip] with the given [outcome].
  /// Shared by every history fetch so the field mapping lives in one place.
  static DeliveredTrip _tripFromOrderDoc(
    String docId,
    Map<String, dynamic> d,
    TripOutcome outcome,
  ) {
    final deliveredAt = (d['deliveredAt'] as Timestamp?)?.toDate();
    final cancelledAt = (d['cancelledAt'] as Timestamp?)?.toDate();
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    // The moment the trip concluded — delivery time when delivered, otherwise
    // the cancel time (falling back to createdAt, then now).
    final concludedAt = deliveredAt ?? cancelledAt ?? createdAt ?? DateTime.now();
    final placedAt = createdAt ?? concludedAt;
    final items = (d['items'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return DeliveredTrip(
      orderNumber: d['orderNumber'] as String? ?? '#$docId',
      restaurant: d['restaurantName'] as String? ?? 'Restaurant',
      customerName: d['customerName'] as String? ?? 'Customer',
      dropoff: d['deliveryAddress'] as String? ?? 'Campus',
      amount: outcome == TripOutcome.delivered ? kDriverPayoutPerDelivery : 0,
      orderTotal: (d['total'] as num?)?.toDouble() ?? 0,
      itemCount: items.fold<int>(0, (sum, i) => sum + ((i['qty'] as num?)?.toInt() ?? 1)),
      items: items,
      isPickup: (d['orderType'] as String?) == 'pickup',
      placedAt: placedAt,
      deliveredAt: concludedAt,
      outcome: outcome,
      cancelReason: (d['cancelReason'] as String?) ?? (d['driverCancelReason'] as String?),
      customerUnreachable: d['customerUnreachable'] as bool? ?? false,
      runningLate: d['runningLate'] as bool? ?? false,
      driverIncident: d['driverIncident'] as bool? ?? false,
      driverIncidentReason: d['driverIncidentReason'] as String?,
    );
  }

  /// Maps a `drivers/{uid}/abandonedTrips/{orderId}` log doc (written by
  /// [abandonDelivery]) to a [DeliveredTrip] with outcome `abandoned`.
  static DeliveredTrip _tripFromAbandonDoc(String id, Map<String, dynamic> d) {
    final abandonedAt = (d['abandonedAt'] as Timestamp?)?.toDate() ??
        (d['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate() ?? abandonedAt;
    final items = (d['items'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return DeliveredTrip(
      orderNumber: d['orderNumber'] as String? ?? '#$id',
      restaurant: d['restaurantName'] as String? ?? 'Restaurant',
      customerName: d['customerName'] as String? ?? 'Customer',
      dropoff: d['deliveryAddress'] as String? ?? 'Campus',
      amount: 0,
      orderTotal: (d['total'] as num?)?.toDouble() ?? 0,
      itemCount: items.isNotEmpty
          ? items.fold<int>(0, (sum, i) => sum + ((i['qty'] as num?)?.toInt() ?? 1))
          : (d['itemCount'] as num?)?.toInt() ?? 0,
      items: items,
      isPickup: (d['orderType'] as String?) == 'pickup',
      placedAt: createdAt,
      deliveredAt: abandonedAt,
      outcome: TripOutcome.abandoned,
      cancelReason: d['reason'] as String?,
    );
  }

  /// Full trip history for the History screen across a date range, covering
  /// every outcome: delivered, vendor-cancelled, and driver-abandoned.
  ///
  /// Delivered/cancelled come from the orders collection (driverId == uid);
  /// abandoned trips come from the driver's own `abandonedTrips` log, since an
  /// abandoned order has its driverId cleared and leaves the driver's read
  /// scope. Each non-delivered source is read defensively so a missing index
  /// or rule on one never blanks out the whole list.
  Future<List<DeliveredTrip>> fetchTripRecords(
    String uid,
    DateTime start,
    DateTime end,
  ) async {
    final startTs = Timestamp.fromDate(start);
    final endTs = Timestamp.fromDate(end);
    final out = <DeliveredTrip>[];

    // Delivered — range-filtered server-side on deliveredAt.
    final deliveredSnap = await _col
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'delivered')
        .where('deliveredAt', isGreaterThanOrEqualTo: startTs)
        .where('deliveredAt', isLessThanOrEqualTo: endTs)
        .get();
    for (final doc in deliveredSnap.docs) {
      out.add(_tripFromOrderDoc(doc.id, doc.data(), TripOutcome.delivered));
    }

    // Cancelled — vendor cancelled after assignment (driverId still us).
    // Date-filtered client-side: cancelled docs may lack a consistently
    // indexed timestamp, and cancellations are low-volume.
    try {
      final cancelledSnap = await _col
          .where('driverId', isEqualTo: uid)
          .where('status', isEqualTo: 'cancelled')
          .get();
      for (final doc in cancelledSnap.docs) {
        final t = _tripFromOrderDoc(doc.id, doc.data(), TripOutcome.cancelled);
        if (!t.deliveredAt.isBefore(start) && !t.deliveredAt.isAfter(end)) {
          out.add(t);
        }
      }
    } catch (e) {
      debugPrint('[FirestoreOrderService] cancelled trips read failed: $e');
    }

    // Abandoned — from the driver's own abandon log.
    try {
      final abandonedSnap =
          await _driversCol.doc(uid).collection('abandonedTrips').get();
      for (final doc in abandonedSnap.docs) {
        final t = _tripFromAbandonDoc(doc.id, doc.data());
        if (!t.deliveredAt.isBefore(start) && !t.deliveredAt.isAfter(end)) {
          out.add(t);
        }
      }
    } catch (e) {
      debugPrint('[FirestoreOrderService] abandoned trips read failed: $e');
    }

    out.sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));
    return out;
  }

  /// Fetches trip history for an arbitrary date range (used by the custom
  /// date picker on the Earnings screen). Delivered trips only — Earnings
  /// counts paid deliveries, so cancelled/abandoned are deliberately excluded.
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

    return snap.docs
        .map((doc) => _tripFromOrderDoc(doc.id, doc.data(), TripOutcome.delivered))
        .toList()
      ..sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));
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

    return snap.docs
        .map((doc) => _tripFromOrderDoc(doc.id, doc.data(), TripOutcome.delivered))
        .toList()
      ..sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));
  }

  /// Update the driver's online status in /drivers collection.
  Future<void> setDriverOnline(bool isOnline) async {
    await FirebaseFirestore.instance
        .collection(AppEnv.col('drivers'))
        .doc(kDriverId)
        .set({
      'isOnline': isOnline,
      'name': kDriverName,
      // Stamp the heartbeat in the SAME write that flips isOnline, so an
      // `isOnline: true` doc can never exist without a fresh `lastActiveAt`.
      // The customer app treats isOnline=true with a stale/absent heartbeat as
      // a ghost driver and ignores it; coupling the two writes here closes the
      // window where the separate _startHeartbeat() write could lag or fail and
      // leave a genuinely-online driver looking dead.
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
