// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/cylinder_booking.dart';
import 'database_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final _db = DatabaseService();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
    );

    _initialized = true;
  }

  /// Reads the user's notification preferences from settings.
  /// Defaults to true (matches the DB's default values) if unset.
  Future<bool> _isEnabled(String settingKey) async {
    final value = await _db.getSetting(settingKey);
    return value == null ? true : value == 'true';
  }

  Future<void> showBookingNotification(CylinderBooking booking) async {
    await initialize();

    // Respect user notification preferences.
    final isDeliveryEvent =
        booking.status == BookingStatus.delivered ||
        booking.status == BookingStatus.outForDelivery;

    final settingKey = isDeliveryEvent
        ? 'notifications_delivery'
        : 'notifications_booking';

    if (!await _isEnabled(settingKey)) return;

    String title;
    String body;

    switch (booking.status) {
      case BookingStatus.booked:
        title = 'Booking Confirmed!';
        body =
            '${booking.companyDisplayName} booking #${booking.bookingId} registered.';
        break;

      case BookingStatus.dacGenerated:
        title = 'DAC Generated';
        body =
            'DAC No: ${booking.dacNumber ?? "N/A"} for booking #${booking.bookingId}';
        break;

      case BookingStatus.outForDelivery:
        title = 'Cylinder Out for Delivery';
        body =
            'Your ${booking.companyDisplayName} cylinder is on the way!';
        break;

      case BookingStatus.delivered:
        title = 'Cylinder Delivered!';
        body =
            '${booking.companyDisplayName} cylinder delivered. Price: ₹${booking.price?.toStringAsFixed(2) ?? "N/A"}';
        break;

      default:
        title = 'LPG Update';
        body = 'New update for booking #${booking.bookingId}';
    }

    await _plugin.show(
      id: booking.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'lpg_booking',
          'LPG Booking Updates',
          channelDescription:
              'Notifications for LPG booking and delivery',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> showGasWarning(int daysRemaining) async {
    await initialize();

    if (!await _isEnabled('notifications_booking')) return;

    await _plugin.show(
      id: 9001,
      title: 'Book Your Next Cylinder',
      body:
          'Gas estimated to finish in $daysRemaining day${daysRemaining == 1 ? '' : 's'}. Book now!',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'lpg_warning',
          'Gas Level Warnings',
          channelDescription: 'Alerts when gas is about to finish',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> showSafetyReminder() async {
    await initialize();

    if (!await _isEnabled('notifications_safety')) return;

    await _plugin.show(
      id: 9002,
      title: 'Safety Reminder',
      body:
          'Check cylinder seal, tube, and regulator after delivery.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'lpg_safety',
          'Safety Reminders',
          channelDescription:
              'Post-delivery safety checklist reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> scheduleBookingReminder(DateTime reminderDate) async {
    await initialize();

    if (!await _isEnabled('notifications_booking')) return;

    // Convert the requested DateTime to the timezone-aware TZDateTime.
    final scheduled = tz.TZDateTime.from(reminderDate, tz.local);

    // If the requested time has already passed, don't schedule it.
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    // Schedule for the future.
    // Android 12+ may require exact-alarm permission depending
    // on the app/device configuration.
    await _plugin.zonedSchedule(
      id: 9003,
      title: 'Time to Book Your Cylinder!',
      body:
          'Your gas is almost finished. Book your next cylinder today.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'lpg_reminder',
          'Booking Reminders',
          channelDescription:
              'Scheduled reminders to book next cylinder',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
