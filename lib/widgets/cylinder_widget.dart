// lib/widgets/cylinder_widget.dart

import 'package:flutter/material.dart';
import '../models/cylinder_booking.dart';
import 'package:intl/intl.dart';

class CylinderWidget extends StatefulWidget {
  final CylinderBooking? booking;
  final double gasPercent;

  const CylinderWidget({
    super.key,
    required this.booking,
    required this.gasPercent,
  });

  @override
  State<CylinderWidget> createState() => _CylinderWidgetState();
}

class _CylinderWidgetState extends State<CylinderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnimation;

  static const _orange = Color(0xFFE8581A);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fillAnimation = Tween<double>(begin: 0, end: widget.gasPercent / 100)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(CylinderWidget old) {
    super.didUpdateWidget(old);
    if (old.gasPercent != widget.gasPercent) {
      _fillAnimation = Tween<double>(
        begin: _fillAnimation.value,
        end: widget.gasPercent / 100,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _fillColor {
    if (widget.gasPercent > 50) return const Color(0xFF1A9E5F);
    if (widget.gasPercent > 25) return const Color(0xFFD4880A);
    return const Color(0xFFD93B3B);
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final fmt = DateFormat('d MMM yyyy');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cylinder SVG visual
          AnimatedBuilder(
            animation: _fillAnimation,
            builder: (_, __) => CustomPaint(
              size: const Size(52, 80),
              painter: _CylinderPainter(
                fillPercent: _fillAnimation.value,
                fillColor: _fillColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusBadge(booking),
                const SizedBox(height: 6),
                Text(
                  booking != null ? 'Cylinder Active' : 'No cylinder tracked',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (booking?.deliveryDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Delivered ${fmt.format(booking!.deliveryDate!)}${booking.cylinderWeight != null ? ' · ${booking.cylinderWeight} kg' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 10),
                // Gas level bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.gasPercent / 100,
                          minHeight: 7,
                          backgroundColor: Colors.grey.shade100,
                          color: _fillColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '~${widget.gasPercent.round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(CylinderBooking? booking) {
    if (booking == null) {
      return _badge('No data', Colors.grey.shade100, Colors.grey.shade600);
    }
    switch (booking.status) {
      case BookingStatus.delivered:
        return _badge('Delivered', const Color(0xFFE6F7EF), const Color(0xFF1A9E5F));
      case BookingStatus.outForDelivery:
        return _badge('Out for delivery', const Color(0xFFFFF0E8), _orange);
      case BookingStatus.dacGenerated:
        return _badge('DAC Generated', const Color(0xFFE8F1FF), const Color(0xFF1A6FE8));
      case BookingStatus.booked:
        return _badge('Booking Confirmed', const Color(0xFFE8F1FF), const Color(0xFF1A6FE8));
      default:
        return _badge('Unknown', Colors.grey.shade100, Colors.grey.shade600);
    }
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg)),
        ],
      ),
    );
  }
}

class _CylinderPainter extends CustomPainter {
  final double fillPercent;
  final Color fillColor;

  _CylinderPainter({required this.fillPercent, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 14, w - 8, h - 20),
      const Radius.circular(10),
    );

    // Background
    canvas.drawRRect(bodyRect, Paint()..color = const Color(0xFFF0F0F0));

    // Fill (clipped)
    final fillHeight = (h - 20) * fillPercent;
    canvas.save();
    canvas.clipRRect(bodyRect);
    canvas.drawRect(
      Rect.fromLTWH(4, 14 + (h - 20) * (1 - fillPercent), w - 8, fillHeight),
      Paint()..color = fillColor.withValues(alpha: 0.85),
    );
    canvas.restore();

    // Outline
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Cap
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w / 2 - 8, 2, 16, 7),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.grey.shade400,
    );

    // Collar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 9, w - 4, 6),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.grey.shade300,
    );

    // Base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, h - 7, w - 12, 4),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.grey.shade300,
    );

    // Percentage text
    final pct = '${(fillPercent * 100).round()}%';
    final tp = TextPainter(
      text: TextSpan(
        text: pct,
        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, 14 + (h - 20) * 0.4));
  }

  @override
  bool shouldRepaint(_CylinderPainter old) =>
      old.fillPercent != fillPercent || old.fillColor != fillColor;
}
