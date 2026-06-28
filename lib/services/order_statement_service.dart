import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'firestore_order_service.dart';

/// Builds a downloadable/shareable Excel statement of a driver's completed
/// trips — exists so a driver (or their supervisor, since it's a real file
/// that can be emailed/saved) has a record of every delivery outside the
/// app itself, not just whatever's visible on the History screen.
class OrderStatementService {
  OrderStatementService._();

  static Future<void> generateAndShare({
    required String driverId,
    required String driverName,
    required DateTime since,
    required String periodLabel,
  }) async {
    final trips = await FirestoreOrderService.instance.fetchTripHistory(driverId, since);

    final workbook = Excel.createExcel();
    final sheetName = workbook.getDefaultSheet()!;
    final sheet = workbook[sheetName];

    const headers = [
      'Order Number',
      'Restaurant',
      'Customer',
      'Dropoff',
      'Order Type',
      'Items',
      'Order Value (QAR)',
      'Driver Earnings (QAR)',
      'Placed At',
      'Delivered At',
      'Trip Duration (min)',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final t in trips) {
      sheet.appendRow([
        TextCellValue(t.orderNumber),
        TextCellValue(t.restaurant),
        TextCellValue(t.customerName),
        TextCellValue(t.dropoff),
        TextCellValue(t.isPickup ? 'Pickup' : 'Delivery'),
        IntCellValue(t.itemCount),
        DoubleCellValue(t.orderTotal),
        DoubleCellValue(t.amount),
        TextCellValue(_formatDateTime(t.placedAt)),
        TextCellValue(_formatDateTime(t.deliveredAt)),
        IntCellValue(t.tripDuration.inMinutes),
      ]);
    }

    // Summary footer — total trips and total earnings, so a supervisor
    // glancing at the sheet doesn't have to sum the column themselves.
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Total trips'),
      IntCellValue(trips.length),
    ]);
    sheet.appendRow([
      TextCellValue('Total earnings (QAR)'),
      DoubleCellValue(trips.fold<double>(0, (s, t) => s + t.amount)),
    ]);

    final bytes = workbook.encode();
    if (bytes == null) {
      throw Exception('Could not generate the statement file.');
    }

    final dir = await getTemporaryDirectory();
    final safeDriverName = driverName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    final fileName =
        'order_statement_${safeDriverName}_${periodLabel.replaceAll(' ', '_')}.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Order Statement — $driverName ($periodLabel)',
      text: 'Order statement for $driverName covering $periodLabel — '
          '${trips.length} completed trip${trips.length == 1 ? '' : 's'}.',
    );
  }

  static String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $h:$m $period';
  }
}
