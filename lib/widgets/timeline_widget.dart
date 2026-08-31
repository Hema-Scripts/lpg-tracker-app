// lib/widgets/timeline_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cylinder_booking.dart';

class TimelineWidget extends StatelessWidget {
  final CylinderBooking booking;

  const TimelineWidget({super.key, required this.booking});

  static const _orange = Color(0xFFE8581A);
  static const _green = Color(0xFF1A9E5F);

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM');
    final steps = _buildSteps(fmt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final isLast = entry.key == steps.length - 1;
          return _TimelineStep(
            step: entry.value,
            showDivider: !isLast,
          );
        }).toList(),
      ),
    );
  }

  List<_StepData> _buildSteps(DateFormat fmt) {
    final steps = <_StepData>[];

    // Step 1: Booking
    steps.add(_StepData(
      icon: '📝',
      title: 'Booking confirmed',
      subtitle: 'ID: ${booking.bookingId} · ${booking.companyDisplayName}',
      time: fmt.format(booking.bookingDate),
      state: _StepState.done,
    ));

    // Step 2: DAC
    final hasDac = booking.dacNumber != null;
    steps.add(_StepData(
      icon: '📋',
      title: 'DAC generated',
      subtitle: hasDac ? 'DAC: ${booking.dacNumber}' : 'Pending',
      time: booking.dacDate != null ? fmt.format(booking.dacDate!) : '',
      state: hasDac ? _StepState.done : _StepState.pending,
    ));

    // Step 3: Delivery
    final isDelivered = booking.status == BookingStatus.delivered;
    final isOutForDelivery = booking.status == BookingStatus.outForDelivery;
    steps.add(_StepData(
      icon: '🛢️',
      title: isDelivered ? 'Cylinder delivered' : (isOutForDelivery ? 'Out for delivery' : 'Delivery pending'),
      subtitle: isDelivered
          ? '${booking.cylinderWeight != null ? '${booking.cylinderWeight} kg' : ''}'
              '${booking.price != null ? ' · ₹${booking.price!.toStringAsFixed(2)}' : ''}'
          : (isOutForDelivery ? 'On the way!' : 'Expected soon'),
      time: booking.deliveryDate != null ? fmt.format(booking.deliveryDate!) : '',
      state: isDelivered
          ? _StepState.done
          : (isOutForDelivery ? _StepState.active : _StepState.pending),
    ));

    // Step 4: Next booking prediction
    steps.add(_StepData(
      icon: '🔮',
      title: 'Next booking due',
      subtitle: 'Predicted based on avg usage',
      time: 'Soon',
      state: _StepState.active,
    ));

    return steps;
  }
}

enum _StepState { done, active, pending }

class _StepData {
  final String icon;
  final String title;
  final String subtitle;
  final String time;
  final _StepState state;

  _StepData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.state,
  });
}

class _TimelineStep extends StatelessWidget {
  final _StepData step;
  final bool showDivider;

  static const _orange = Color(0xFFE8581A);
  static const _green = Color(0xFF1A9E5F);

  const _TimelineStep({required this.step, required this.showDivider});

  Color get _iconBg {
    switch (step.state) {
      case _StepState.done: return const Color(0xFFE6F7EF);
      case _StepState.active: return const Color(0xFFFFF0E8);
      case _StepState.pending: return const Color(0xFFF5F5F0);
    }
  }

  Color get _iconColor {
    switch (step.state) {
      case _StepState.done: return _green;
      case _StepState.active: return _orange;
      case _StepState.pending: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: _iconBg, shape: BoxShape.circle),
                child: Center(
                  child: step.state == _StepState.done
                      ? Icon(Icons.check, size: 14, color: _iconColor)
                      : Text(step.icon, style: const TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: step.state == _StepState.pending
                            ? Colors.grey.shade500
                            : Colors.black87,
                      ),
                    ),
                    if (step.subtitle.isNotEmpty)
                      Text(
                        step.subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              if (step.time.isNotEmpty)
                Text(
                  step.time,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 0.5, indent: 56, endIndent: 14, color: Colors.grey.shade200),
      ],
    );
  }
}
