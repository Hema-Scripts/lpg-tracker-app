// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/cylinder_booking.dart';
import '../models/gas_connection.dart';
import '../services/database_service.dart';
import '../services/pdf_export_service.dart';
import 'booking_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = DatabaseService();
  final _pdfService = PdfExportService();

  List<CylinderBooking> _bookings = [];
  List<GasConnection> _connections = [];
  int? _filterConnectionId; // null = all connections
  Map<int, int> _monthlyUsage = {};
  double _totalSpent = 0;
  int _currentYear = DateTime.now().year;
  bool _loading = true;
  bool _exporting = false;

  static const _orange = Color(0xFFE8581A);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final connections = await _db.getConnections();
    final bookings = await _db.getAllBookings(connectionId: _filterConnectionId);
    final monthly = await _db.getMonthlyUsage(_currentYear, connectionId: _filterConnectionId);
    final total = await _db.getTotalSpent(connectionId: _filterConnectionId);
    setState(() {
      _connections = connections;
      _bookings = bookings;
      _monthlyUsage = monthly;
      _totalSpent = total;
      _loading = false;
    });
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      await _pdfService.sharePdf();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: _orange,
        title: const Text('History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
                  tooltip: 'Export PDF',
                  onPressed: _bookings.isEmpty ? null : _exportPdf,
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _bookings.isEmpty
              ? _buildEmpty()
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (_connections.length > 1) ...[_buildConnectionFilter(), const SizedBox(height: 10)],
                    _buildSummaryCards(),
                    const SizedBox(height: 12),
                    _buildMonthlyChart(),
                    const SizedBox(height: 16),
                    _sectionLabel('Booking history (${_bookings.length})'),
                    const SizedBox(height: 8),
                    ..._bookings.map(_buildHistoryItem),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _buildConnectionFilter() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All connections', style: TextStyle(fontSize: 12.5)),
              selected: _filterConnectionId == null,
              selectedColor: _orange.withValues(alpha: 0.15),
              labelStyle: TextStyle(color: _filterConnectionId == null ? _orange : Colors.black87, fontWeight: FontWeight.w600),
              onSelected: (_) { setState(() => _filterConnectionId = null); _load(); },
            ),
          ),
          for (final c in _connections)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c.nickname, style: const TextStyle(fontSize: 12.5)),
                selected: _filterConnectionId == c.id,
                selectedColor: _orange.withValues(alpha: 0.15),
                labelStyle: TextStyle(color: _filterConnectionId == c.id ? _orange : Colors.black87, fontWeight: FontWeight.w600),
                onSelected: (_) { setState(() => _filterConnectionId = c.id); _load(); },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No bookings yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Scan your inbox from the Home tab', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final delivered = _bookings.where((b) => b.status == BookingStatus.delivered).toList();
    final withPrice = delivered.where((b) => b.price != null).toList();
    final avgPrice = withPrice.isNotEmpty
        ? withPrice.fold(0.0, (s, b) => s + b.price!) / withPrice.length
        : 0.0;

    return Row(
      children: [
        Expanded(child: _summaryCard('Cylinders', '${delivered.length}', Icons.propane_tank)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Total spent', '₹${_totalSpent.toStringAsFixed(0)}', Icons.currency_rupee)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Avg price', '₹${avgPrice.toStringAsFixed(0)}', Icons.trending_up)),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _orange),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart() {
    final months = ['J','F','M','A','M','J','J','A','S','O','N','D'];
    final totalThisYear = _monthlyUsage.values.fold(0, (a, b) => a + b);
    final maxMonthly = _monthlyUsage.values.isEmpty
        ? 0
        : _monthlyUsage.values.reduce((a, b) => a > b ? a : b);
    // Always show at least 3 units of headroom so single-cylinder months
    // don't look like a full bar.
    final chartMaxY = (maxMonthly < 3 ? 3 : maxMonthly + 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Monthly usage ($_currentYear)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFFF0E8), borderRadius: BorderRadius.circular(6)),
                child: Text('$totalThisYear cyl', style: const TextStyle(fontSize: 11, color: _orange, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () async {
                  setState(() => _currentYear--);
                  final m = await _db.getMonthlyUsage(_currentYear, connectionId: _filterConnectionId);
                  setState(() => _monthlyUsage = m);
                },
                child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.chevron_left, size: 18)),
              ),
              InkWell(
                onTap: _currentYear < DateTime.now().year ? () async {
                  setState(() => _currentYear++);
                  final m = await _db.getMonthlyUsage(_currentYear, connectionId: _filterConnectionId);
                  setState(() => _monthlyUsage = m);
                } : null,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.chevron_right, size: 18,
                      color: _currentYear < DateTime.now().year ? Colors.grey.shade600 : Colors.grey.shade300),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: chartMaxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, gi, rod, ri) => rod.toY == 0 ? null
                      : BarTooltipItem('${rod.toY.toInt()} cyl', const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= 12) return const SizedBox();
                      final isCurrent = i + 1 == DateTime.now().month && _currentYear == DateTime.now().year;
                      return Text(months[i], style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
                        color: isCurrent ? _orange : Colors.grey.shade500,
                      ));
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(12, (i) {
                final count = (_monthlyUsage[i + 1] ?? 0).toDouble();
                final isCurrent = i + 1 == DateTime.now().month && _currentYear == DateTime.now().year;
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: count,
                    color: count > 0 ? (isCurrent ? _orange : _orange.withValues(alpha: 0.4)) : _orange.withValues(alpha: 0.08),
                    width: 16,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]);
              }),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(CylinderBooking booking) {
    final fmt = DateFormat('d MMM yyyy');
    final isDelivered = booking.status == BookingStatus.delivered;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: booking)),
        );
        if (result == true) _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isDelivered ? const Color(0xFFE6F7EF) : const Color(0xFFE8F1FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDelivered ? Icons.propane_tank : Icons.schedule,
                color: isDelivered ? const Color(0xFF1A9E5F) : const Color(0xFF1A6FE8),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${booking.statusDisplayName} · ${booking.bookingId}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(fmt.format(booking.deliveryDate ?? booking.bookingDate),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  if (booking.dacNumber != null)
                    Text('DAC: ${booking.dacNumber}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (booking.price != null)
                  Text('₹${booking.price!.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(booking.companyDisplayName,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade300),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.8)),
      );
}
