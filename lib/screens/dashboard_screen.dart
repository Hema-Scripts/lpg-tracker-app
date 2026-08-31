// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cylinder_booking.dart';
import '../models/gas_connection.dart';
import '../services/database_service.dart';
import '../services/prediction_service.dart';
import '../services/sms_service.dart';
import '../widgets/cylinder_widget.dart';
import '../widgets/stat_card.dart';
import '../widgets/timeline_widget.dart';
import '../widgets/order_now_sheet.dart';
import 'add_booking_screen.dart';
import 'connections_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseService();
  final _prediction = PredictionService();
  final _sms = SmsService();
  CylinderBooking? _latestBooking;
  PredictionResult? _predictionResult;
  List<GasConnection> _connections = [];
  GasConnection? _activeConnection;
  bool _loading = true;
  bool _isScanning = false;
  static const _orange = Color(0xFFE8581A);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final connections = await _db.getConnections();
    // Keep whichever connection was already selected if it still exists,
    // otherwise fall back to the default one.
    GasConnection? active;
    if (_activeConnection != null) {
      for (final c in connections) {
        if (c.id == _activeConnection!.id) { active = c; break; }
      }
    }
    if (active == null && connections.isNotEmpty) {
      active = connections.firstWhere((c) => c.isDefault, orElse: () => connections.first);
    }

    final booking = await _db.getLatestBooking(connectionId: active?.id);
    final prediction = await _prediction.predict(connectionId: active?.id);
    setState(() {
      _connections = connections;
      _activeConnection = active;
      _latestBooking = booking;
      _predictionResult = prediction;
      _loading = false;
    });
  }

  Future<void> _scanInbox() async {
    setState(() => _isScanning = true);
    final count = await _sms.scanInbox();
    await _load();
    setState(() => _isScanning = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count > 0 ? 'Found $count LPG message${count == 1 ? "" : "s"} in inbox!' : 'No new LPG messages found.'),
        backgroundColor: _orange,
      ));
    }
  }

  Future<void> _openOrderNow() async {
    final company = _activeConnection?.company ?? _latestBooking?.company ?? LpgCompany.indane;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderNowSheet(initialCompany: company),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AddBookingScreen(initialConnectionId: _activeConnection?.id)));
          if (result == true) _load();
        },
        backgroundColor: _orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add booking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        color: _orange,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _orange))
            : CustomScrollView(slivers: [_buildAppBar(), SliverToBoxAdapter(child: _buildBody())]),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: _orange,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: _orange,
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('LPG Tracker', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                const Spacer(),
                _isScanning
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _scanInbox, tooltip: 'Scan SMS inbox'),
              ]),
              Text(
                _latestBooking?.distributorName != null
                    ? '${_latestBooking!.companyDisplayName} · ${_latestBooking!.distributorName}'
                    : 'Pull down or tap ↺ to scan SMS',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_connections.length > 1) ...[_buildConnectionSwitcher(), const SizedBox(height: 10)],
          _buildOrderNowButton(),
          const SizedBox(height: 10),
          CylinderWidget(booking: _latestBooking, gasPercent: _predictionResult?.gasRemainingPercent ?? 100),
          const SizedBox(height: 10),
          if (_predictionResult?.shouldBookSoon == true) ...[_buildAlertBanner(), const SizedBox(height: 10)],
          _buildStatsGrid(),
          const SizedBox(height: 16),
          if (_latestBooking != null) ...[
            _sectionLabel('Booking timeline'),
            const SizedBox(height: 6),
            TimelineWidget(booking: _latestBooking!),
          ] else _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildConnectionSwitcher() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in _connections)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c.nickname, style: const TextStyle(fontSize: 12.5)),
                selected: _activeConnection?.id == c.id,
                selectedColor: _orange.withValues(alpha: 0.15),
                labelStyle: TextStyle(color: _activeConnection?.id == c.id ? _orange : Colors.black87, fontWeight: FontWeight.w600),
                onSelected: (_) {
                  setState(() => _activeConnection = c);
                  _load();
                },
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.settings, size: 15),
            label: const Text('Manage', style: TextStyle(fontSize: 12.5)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectionsScreen()));
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderNowButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openOrderNow,
        icon: const Icon(Icons.chat, size: 18),
        label: const Text('Order Now via WhatsApp', style: TextStyle(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildAlertBanner() {
    final days = _predictionResult?.daysRemaining ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFFF7E0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF4C875), width: 0.5)),
      child: Row(children: [
        const Text('⚠', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Book your next cylinder soon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFD4880A))),
          Text(days <= 0 ? 'Gas may have finished! Book now.' : 'Gas estimated to finish in $days day${days == 1 ? "" : "s"}.',
              style: TextStyle(fontSize: 12, color: const Color(0xFFD4880A).withValues(alpha: 0.85))),
        ])),
      ]),
    );
  }

  Widget _buildStatsGrid() {
    final pred = _predictionResult;
    final booking = _latestBooking;
    final fmt = DateFormat('d MMM yyyy');
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.2,
      children: [
        StatCard(label: 'Expected finish', value: pred?.estimatedFinishDate != null ? fmt.format(pred!.estimatedFinishDate!) : '—', valueColor: _orange),
        StatCard(label: 'Avg cylinder lasts', value: pred != null ? '${pred.avgDurationDays.round()} days' : '—', valueColor: const Color(0xFF1A6FE8)),
        StatCard(label: 'Last price paid', value: booking?.price != null ? '₹${booking!.price!.toStringAsFixed(2)}' : '—', valueColor: const Color(0xFF1A9E5F)),
        StatCard(label: 'DAC number', value: booking?.dacNumber ?? (booking?.bookingId ?? '—'), valueColor: Colors.black87),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200, width: 0.5)),
      child: Column(children: [
        Icon(Icons.sms_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('No LPG bookings found yet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 6),
        Text('Tap ↺ above to scan your SMS inbox for Indane, HP Gas, or Bharat Gas messages.\n\nOr tap "+ Add booking" to enter manually.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.8));
}

  Widget _buildAlertBanner() {
    final days = _predictionResult?.daysRemaining ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFFF7E0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF4C875), width: 0.5)),
      child: Row(children: [
        const Text('⚠', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Book your next cylinder soon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFD4880A))),
          Text(days <= 0 ? 'Gas may have finished! Book now.' : 'Gas estimated to finish in $days day${days == 1 ? "" : "s"}.',
              style: TextStyle(fontSize: 12, color: const Color(0xFFD4880A).withValues(alpha: 0.85))),
        ])),
      ]),
    );
  }

  Widget _buildStatsGrid() {
    final pred = _predictionResult;
    final booking = _latestBooking;
    final fmt = DateFormat('d MMM yyyy');
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.2,
      children: [
        StatCard(label: 'Expected finish', value: pred?.estimatedFinishDate != null ? fmt.format(pred!.estimatedFinishDate!) : '—', valueColor: _orange),
        StatCard(label: 'Avg cylinder lasts', value: pred != null ? '${pred.avgDurationDays.round()} days' : '—', valueColor: const Color(0xFF1A6FE8)),
        StatCard(label: 'Last price paid', value: booking?.price != null ? '₹${booking!.price!.toStringAsFixed(2)}' : '—', valueColor: const Color(0xFF1A9E5F)),
        StatCard(label: 'DAC number', value: booking?.dacNumber ?? (booking?.bookingId ?? '—'), valueColor: Colors.black87),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200, width: 0.5)),
      child: Column(children: [
        Icon(Icons.sms_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('No LPG bookings found yet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 6),
        Text('Tap ↺ above to scan your SMS inbox for Indane, HP Gas, or Bharat Gas messages.\n\nOr tap "+ Add booking" to enter manually.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.8));
}
