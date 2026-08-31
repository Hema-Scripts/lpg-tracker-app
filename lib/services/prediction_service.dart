// lib/services/prediction_service.dart

import 'database_service.dart';
import '../models/cylinder_booking.dart';

class PredictionResult {
  final double avgDurationDays;
  final DateTime? estimatedFinishDate;
  final DateTime? suggestedBookingDate;
  final double gasRemainingPercent;
  final bool shouldBookSoon;
  final int? daysRemaining;

  PredictionResult({
    required this.avgDurationDays,
    this.estimatedFinishDate,
    this.suggestedBookingDate,
    required this.gasRemainingPercent,
    required this.shouldBookSoon,
    this.daysRemaining,
  });
}

class PredictionService {
  final _db = DatabaseService();

  /// Number of days before finish to alert user to book
  static const int _alertDaysBefore = 5;

  /// Minimum number of historical cylinders needed to make a prediction
  static const int _minHistoryCount = 2;

  Future<PredictionResult> predict({int? connectionId}) async {
    final durations = await _db.getCylinderDurations(connectionId: connectionId);
    final latestDelivered = await _getLatestDeliveredBooking(connectionId: connectionId);

    if (durations.isEmpty || latestDelivered?.deliveryDate == null) {
      return PredictionResult(
        avgDurationDays: 45, // Default Indian avg
        gasRemainingPercent: 100,
        shouldBookSoon: false,
      );
    }

    // Calculate average duration from history (weighted: recent ones count more)
    final avg = _weightedAverage(durations);

    // Days since last delivery
    final daysSince = DateTime.now()
        .difference(latestDelivered!.deliveryDate!)
        .inDays;

    // Gas remaining (linear model)
    final remaining = ((avg - daysSince) / avg * 100).clamp(0.0, 100.0);

    // Estimated finish date
    final finishDate =
        latestDelivered.deliveryDate!.add(Duration(days: avg.round()));

    // Suggested booking date (finish - alertDaysBefore)
    final bookingDate =
        finishDate.subtract(const Duration(days: _alertDaysBefore));

    final daysRemaining = finishDate.difference(DateTime.now()).inDays;
    final shouldBook = daysRemaining <= _alertDaysBefore;

    return PredictionResult(
      avgDurationDays: avg,
      estimatedFinishDate: finishDate,
      suggestedBookingDate: bookingDate,
      gasRemainingPercent: remaining,
      shouldBookSoon: shouldBook,
      daysRemaining: daysRemaining,
    );
  }

  /// Weighted average: recent cylinders count 2x
  double _weightedAverage(List<Map<String, dynamic>> durations) {
    if (durations.isEmpty) return 45;
    if (durations.length == 1) return (durations.first['duration_days'] as int).toDouble();

    double totalWeight = 0;
    double weightedSum = 0;

    for (int i = 0; i < durations.length; i++) {
      final weight = i == 0 ? 2.0 : 1.0; // Most recent gets 2x weight
      final days = (durations[i]['duration_days'] as int).toDouble();
      weightedSum += days * weight;
      totalWeight += weight;
    }

    return weightedSum / totalWeight;
  }

  Future<CylinderBooking?> _getLatestDeliveredBooking({int? connectionId}) async {
    final delivered = await _db.getDeliveredBookings(connectionId: connectionId);
    return delivered.isEmpty ? null : delivered.first;
  }

  /// Return cylinder duration pairs for charting
  Future<List<int>> getDurationHistory({int? connectionId}) async {
    final durations = await _db.getCylinderDurations(connectionId: connectionId);
    return durations.map((d) => d['duration_days'] as int).toList();
  }

  /// Price trend
  Future<List<double>> getPriceHistory({int? connectionId}) async {
    final durations = await _db.getCylinderDurations(connectionId: connectionId);
    return durations
        .where((d) => d['price'] != null)
        .map((d) => (d['price'] as num).toDouble())
        .toList();
  }
}
