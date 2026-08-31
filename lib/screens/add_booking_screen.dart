// lib/screens/add_booking_screen.dart
//
// Allows users to manually enter a booking if SMS was missed or deleted.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cylinder_booking.dart';
import '../models/gas_connection.dart';
import '../services/sms_service.dart';
import '../services/database_service.dart';

class AddBookingScreen extends StatefulWidget {
  final int? initialConnectionId;
  const AddBookingScreen({super.key, this.initialConnectionId});

  @override
  State<AddBookingScreen> createState() => _AddBookingScreenState();
}

class _AddBookingScreenState extends State<AddBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _smsService = SmsService();
  final _db = DatabaseService();

  static const _orange = Color(0xFFE8581A);

  // Form fields
  final _bookingIdCtrl = TextEditingController();
  final _dacCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _distributorCtrl = TextEditingController();

  LpgCompany _company = LpgCompany.indane;
  DateTime _bookingDate = DateTime.now();
  DateTime? _deliveryDate;
  bool _isDelivered = false;
  bool _saving = false;
  List<GasConnection> _connections = [];
  int? _selectedConnectionId;

  final _fmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _selectedConnectionId = widget.initialConnectionId;
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    final connections = await _db.getConnections();
    setState(() {
      _connections = connections;
      _selectedConnectionId ??= connections.isEmpty
          ? null
          : connections.firstWhere((c) => c.isDefault, orElse: () => connections.first).id;
      final selected = connections.where((c) => c.id == _selectedConnectionId);
      if (selected.isNotEmpty) _company = selected.first.company;
    });
  }

  @override
  void dispose() {
    _bookingIdCtrl.dispose();
    _dacCtrl.dispose();
    _priceCtrl.dispose();
    _distributorCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isDelivery) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDelivery ? (_deliveryDate ?? DateTime.now()) : _bookingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _orange),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isDelivery) {
        _deliveryDate = picked;
      } else {
        _bookingDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    await _smsService.addManualBooking(
      bookingId: _bookingIdCtrl.text.trim(),
      company: _company,
      bookingDate: _bookingDate,
      dacNumber: _dacCtrl.text.trim().isEmpty ? null : _dacCtrl.text.trim(),
      deliveryDate: _isDelivered ? _deliveryDate : null,
      price: double.tryParse(_priceCtrl.text.trim()),
      distributorName: _distributorCtrl.text.trim().isEmpty ? null : _distributorCtrl.text.trim(),
      connectionId: _selectedConnectionId,
    );

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking added successfully!'),
          backgroundColor: _orange,
        ),
      );
      Navigator.of(context).pop(true); // Return true = refresh dashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: _orange,
        title: const Text('Add Booking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_connections.length > 1) ...[
              _card([
                _sectionTitle('Which connection?'),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _selectedConnectionId,
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  items: _connections
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nickname)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final match = _connections.where((c) => c.id == v);
                    setState(() {
                      _selectedConnectionId = v;
                      if (match.isNotEmpty) _company = match.first.company;
                    });
                  },
                ),
              ]),
              const SizedBox(height: 12),
            ],
            _card([
              _sectionTitle('LPG Company'),
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
            ]),

            const SizedBox(height: 12),

            _card([
              _sectionTitle('Booking Details'),
              const SizedBox(height: 12),
              _textField(
                controller: _bookingIdCtrl,
                label: 'Booking ID *',
                hint: 'e.g. 4821939',
                validator: (v) => v == null || v.trim().isEmpty ? 'Booking ID is required' : null,
              ),
              const SizedBox(height: 12),
              _datePicker(
                label: 'Booking date *',
                date: _bookingDate,
                onTap: () => _pickDate(false),
              ),
              const SizedBox(height: 12),
              _textField(
                controller: _distributorCtrl,
                label: 'Distributor name',
                hint: 'e.g. Raj Gas Agency',
              ),
            ]),

            const SizedBox(height: 12),

            _card([
              _sectionTitle('DAC Number'),
              const SizedBox(height: 12),
              _textField(
                controller: _dacCtrl,
                label: 'DAC number (optional)',
                hint: 'e.g. 902847',
                keyboardType: TextInputType.number,
              ),
            ]),

            const SizedBox(height: 12),

            _card([
              Row(
                children: [
                  _sectionTitle('Delivery'),
                  const Spacer(),
                  Switch(
                    value: _isDelivered,
                    onChanged: (v) => setState(() => _isDelivered = v),
                    activeThumbColor: _orange,
                  ),
                ],
              ),
              if (_isDelivered) ...[
                const SizedBox(height: 12),
                _datePicker(
                  label: 'Delivery date',
                  date: _deliveryDate,
                  onTap: () => _pickDate(true),
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _priceCtrl,
                  label: 'Amount paid (₹)',
                  hint: 'e.g. 903.50',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₹ ',
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Toggle on if the cylinder has been delivered',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
            ]),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save Booking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _orange, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _datePicker({required String label, required DateTime? date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text(
                  date != null ? _fmt.format(date) : 'Select date',
                  style: TextStyle(
                    fontSize: 14,
                    color: date != null ? Colors.black87 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
