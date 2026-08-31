// lib/widgets/order_now_sheet.dart

import 'package:flutter/material.dart';
import '../models/cylinder_booking.dart';
import '../services/whatsapp_order_service.dart';

class OrderNowSheet extends StatefulWidget {
  final LpgCompany initialCompany;
  const OrderNowSheet({super.key, required this.initialCompany});

  @override
  State<OrderNowSheet> createState() => _OrderNowSheetState();
}

class _OrderNowSheetState extends State<OrderNowSheet> {
  final _whatsapp = WhatsAppOrderService();
  late LpgCompany _company;
  bool _opening = false;
  bool _failed = false;

  static const _orange = Color(0xFFE8581A);
  static const _whatsappGreen = Color(0xFF25D366);

  @override
  void initState() {
    super.initState();
    _company = widget.initialCompany == LpgCompany.unknown ? LpgCompany.indane : widget.initialCompany;
  }

  Future<void> _open() async {
    setState(() { _opening = true; _failed = false; });
    final ok = await _whatsapp.openOrder(_company);
    if (!mounted) return;
    setState(() { _opening = false; _failed = !ok; });
    if (ok) Navigator.of(context).pop();
  }

  String _label(LpgCompany c) {
    switch (c) {
      case LpgCompany.indane: return 'Indane Gas';
      case LpgCompany.hpGas: return 'HP Gas';
      case LpgCompany.bharatGas: return 'Bharat Gas';
      case LpgCompany.unknown: return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: _whatsappGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Icon(Icons.chat, color: _whatsappGreen, size: 20)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Order via WhatsApp', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Which provider?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          SegmentedButton<LpgCompany>(
            segments: const [
              ButtonSegment(value: LpgCompany.indane, label: Text('Indane')),
              ButtonSegment(value: LpgCompany.hpGas, label: Text('HP Gas')),
              ButtonSegment(value: LpgCompany.bharatGas, label: Text('Bharat')),
            ],
            selected: {_company},
            onSelectionChanged: (s) => setState(() => _company = s.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _orange;
                return null;
              }),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F0), borderRadius: BorderRadius.circular(10)),
            child: Text(
              'This opens WhatsApp with a message ready to send to ${_label(_company)}\'s official booking number. Finish the order there as usual — once you do, the confirmation SMS from ${_label(_company)} will be picked up automatically and show up on your dashboard, just like any other booking.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.5),
            ),
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(
              "Couldn't open WhatsApp — make sure it's installed, or add/edit the booking number for ${_label(_company)} in Settings.",
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _opening ? null : _open,
              icon: _opening
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.chat, size: 18),
              label: Text(_opening ? 'Opening...' : 'Open WhatsApp', style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _whatsappGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
