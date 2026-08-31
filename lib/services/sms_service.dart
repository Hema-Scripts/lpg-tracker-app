// lib/services/sms_service.dart

import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sms_parser.dart';
import 'database_service.dart';
import 'notification_service.dart';
import '../models/cylinder_booking.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final Telephony _telephony = Telephony.instance;
  final _db = DatabaseService();
  final _notifications = NotificationService();

  bool _initialized = false;

  /// Request SMS permissions
  Future<bool> requestPermissions() async {
    final smsStatus = await Permission.sms.request();
    return smsStatus.isGranted;
  }

  /// Check if SMS permission is already granted
  Future<bool> hasPermission() async {
    return await Permission.sms.isGranted;
  }

  /// Initialize background SMS listener
  Future<void> initialize() async {
    if (_initialized) return;

    final smsEnabledSetting = await _db.getSetting('sms_enabled');
    if (smsEnabledSetting == 'false') return; // user chose manual-entry-only mode

    _initialized = true;

    final granted = await hasPermission();
    if (!granted) return;

    // Listen for new incoming SMS in background
    _telephony.listenIncomingSms(
      onNewMessage: _onNewSms,
      onBackgroundMessage: _backgroundSmsHandler,
      listenInBackground: true,
    );
  }

  /// Process a new incoming SMS
  Future<void> _onNewSms(SmsMessage message) async {
    final sender = message.address ?? '';
    final body = message.body ?? '';
    final receivedAt = DateTime.fromMillisecondsSinceEpoch(
      message.date ?? DateTime.now().millisecondsSinceEpoch,
    );

    await _processSms(sender, body, receivedAt);
  }

  /// Static handler for background SMS (required by telephony package).
  /// `@pragma('vm:entry-point')` is required so release-mode tree-shaking
  /// doesn't strip this function — without it, background SMS handling
  /// silently stops working in release APKs whenever the app isn't running.
  @pragma('vm:entry-point')
  static Future<void> _backgroundSmsHandler(SmsMessage message) async {
    final sender = message.address ?? '';
    final body = message.body ?? '';
    final receivedAt = DateTime.fromMillisecondsSinceEpoch(
      message.date ?? DateTime.now().millisecondsSinceEpoch,
    );

    if (!SmsParser.isLpgSms(sender, body)) return;

    final booking = SmsParser.parse(sender, body, receivedAt);
    if (booking == null) return;

    final db = DatabaseService();
    await db.insertBooking(booking);

    final notifications = NotificationService();
    await notifications.initialize();
    await notifications.showBookingNotification(booking);
  }

  /// Parse and store SMS, then send notification
  Future<CylinderBooking?> _processSms(
    String sender,
    String body,
    DateTime receivedAt,
  ) async {
    final isLpg = SmsParser.isLpgSms(sender, body);
    await _db.logSms(sender, body, receivedAt, isLpg);

    if (!isLpg) return null;

    final booking = SmsParser.parse(sender, body, receivedAt);
    if (booking == null) return null;

    await _db.insertBooking(booking);
    await _notifications.showBookingNotification(booking);

    return booking;
  }

  /// Scan existing SMS inbox for past LPG messages (first run)
  Future<int> scanInbox() async {
    final granted = await hasPermission();
    if (!granted) return 0;

    int count = 0;

    try {
      // Read inbox SMS
      final inboxMessages = await _telephony.getInboxSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
        ],
        filter: SmsFilter.where(SmsColumn.DATE)
            .greaterThan('${DateTime.now().subtract(const Duration(days: 365)).millisecondsSinceEpoch}'),
        sortOrder: [
          OrderBy(SmsColumn.DATE, sort: Sort.DESC),
        ],
      );

      for (final sms in inboxMessages) {
        final sender = sms.address ?? '';
        final body = sms.body ?? '';
        final date = DateTime.fromMillisecondsSinceEpoch(
          sms.date ?? DateTime.now().millisecondsSinceEpoch,
        );

        if (!SmsParser.isLpgSms(sender, body)) continue;

        final booking = SmsParser.parse(sender, body, date);
        if (booking != null) {
          await _db.insertBooking(booking);
          count++;
        }
      }
    } catch (e) {
      // Handle permission or platform exceptions
      print('SmsService.scanInbox error: $e');
    }

    return count;
  }

  /// Manually add a booking from user input
  Future<void> addManualBooking({
    required String bookingId,
    required LpgCompany company,
    required DateTime bookingDate,
    String? dacNumber,
    DateTime? deliveryDate,
    double? price,
    String? distributorName,
    int? connectionId,
  }) async {
    final booking = CylinderBooking(
      bookingId: bookingId,
      company: company,
      bookingDate: bookingDate,
      dacNumber: dacNumber,
      deliveryDate: deliveryDate,
      price: price,
      distributorName: distributorName,
      status: deliveryDate != null ? BookingStatus.delivered : BookingStatus.booked,
      rawSms: '[Manual Entry]',
      createdAt: DateTime.now(),
    );
    await _db.insertBooking(booking, connectionId: connectionId);
  }
}
