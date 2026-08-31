// lib/screens/booking_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/cylinder_booking.dart';
import '../services/database_service.dart';

class BookingDetailScreen extends StatelessWidget {
  final CylinderBooking booking;

  const BookingDetailScreen({super.key, required this.booking});

  static const _orange = Color(0xFFE8581A);
  static final _fmt = DateFormat('d MMM yyyy, h:mm a');
  static final _fmtDate = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: _orange,
        title: Text('Booking ${booking.bookingId}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _statusCard(),
          const SizedBox(height: 12),
          _detailCard('Booking Information', [
            _row('Booking ID', booking.bookingId, copyable: true),
            _row('Company', booking.companyDisplayName),
            _row('Booking date', _fmtDate.format(booking.bookingDate)),
            _row('Status', booking.statusDisplayName),
          ]),
          if (booking.dacNumber != null) ...[
            const SizedBox(height: 12),
            _detailCard('DAC Details', [
              _row('DAC number', booking.dacNumber!, copyable: true),
              if (booking.dacDate != null)
                _row('DAC date', _fmtDate.format(booking.dacDate!)),
            ]),
          ],
          if (booking.deliveryDate != null || booking.price != null || booking.cylinderWeight != null) ...[
            const SizedBox(height: 12),
            _detailCard('Delivery Details', [
              if (booking.deliveryDate != null)
                _row('Delivery date', _fmtDate.format(booking.deliveryDate!)),
              if (booking.price != null)
                _row('Amount paid', '₹${booking.price!.toStringAsFixed(2)}'),
              if (booking.cylinderWeight != null)
                _row('Cylinder weight', '${booking.cylinderWeight} kg'),
            ]),
          ],
          if (booking.distributorName != null || booking.distributorPhone != null) ...[
            const SizedBox(height: 12),
            _detailCard('Distributor', [
              if (booking.distributorName != null)
                _row('Name', booking.distributorName!),
              if (booking.distributorPhone != null)
                _row('Phone', booking.distributorPhone!, copyable: true),
            ]),
          ],
          const SizedBox(height: 12),
          _detailCard('Raw SMS', [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SelectableText(
                booking.rawSms == '[Manual Entry]'
                    ? 'This booking was added manually.'
                    : booking.rawSms,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            'Added to app: ${_fmt.format(booking.createdAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final isDelivered = booking.status == BookingStatus.delivered;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDelivered ? const Color(0xFFE6F7EF) : const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDelivered ? const Color(0xFF9FE1CB) : const Color(0xFFF5956A),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            isDelivered ? '✅' : '⏳',
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.statusDisplayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDelivered ? const Color(0xFF1A9E5F) : _orange,
                ),
              ),
              Text(
                booking.companyDisplayName,
                style: TextStyle(
                  fontSize: 13,
                  color: isDelivered
                      ? const Color(0xFF1A9E5F).withValues(alpha: 0.7)
                      : _orange.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
          ),
          ...children.map((w) => Column(
                children: [
                  const Divider(height: 0.5, indent: 14, endIndent: 14),
                  w,
                ],
              )),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.right,
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Clipboard.setData(ClipboardData(text: value)),
                    child: Icon(Icons.copy, size: 14, color: Colors.grey.shade400),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete booking?'),
        content: Text('Remove booking ${booking.bookingId} from history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (booking.id != null) {
                await DatabaseService().deleteBooking(booking.id!);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
