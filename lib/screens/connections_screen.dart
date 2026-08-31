// lib/screens/connections_screen.dart
//
// Manage multiple LPG connections under one household (e.g. a joint family
// with two domestic connections, or a domestic + commercial connection).
// Most users will only ever have one — this screen stays out of their way
// until they explicitly add a second.

import 'package:flutter/material.dart';
import '../models/cylinder_booking.dart';
import '../models/gas_connection.dart';
import '../services/database_service.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final _db = DatabaseService();
  List<GasConnection> _connections = [];
  bool _loading = true;
  static const _orange = Color(0xFFE8581A);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final connections = await _db.getConnections();
    setState(() {
      _connections = connections;
      _loading = false;
    });
  }

  Future<void> _openEditor({GasConnection? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConnectionEditorSheet(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(GasConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove connection?'),
        content: Text(
          'Removing "${connection.nickname}" won\'t delete its booking history — those bookings will just show as unassigned.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && connection.id != null) {
      await _db.deleteConnection(connection.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: _orange,
        title: const Text('My Connections', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: _orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add connection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    'If your household has more than one LPG connection (e.g. two domestic connections, or domestic + commercial), keep each one here — bookings, predictions, and history are tracked separately per connection.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.5),
                  ),
                ),
                const SizedBox(height: 8),
                for (final c in _connections) _connectionCard(c),
              ],
            ),
    );
  }

  Widget _connectionCard(GasConnection c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.isDefault ? _orange : Colors.grey.shade200, width: c.isDefault ? 1.2 : 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFFFFF0E8), borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('🛢️', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(c.nickname, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  if (c.isDefault) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: _orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Default', style: TextStyle(fontSize: 10, color: _orange, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  [
                    _companyLabel(c.company),
                    if (c.consumerNumber != null && c.consumerNumber!.isNotEmpty) 'Consumer #${c.consumerNumber}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey.shade500, size: 20),
            onSelected: (value) {
              if (value == 'edit') _openEditor(existing: c);
              if (value == 'default' && c.id != null) {
                _db.setDefaultConnection(c.id!).then((_) => _load());
              }
              if (value == 'delete') _confirmDelete(c);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (!c.isDefault) const PopupMenuItem(value: 'default', child: Text('Set as default')),
              if (_connections.length > 1) const PopupMenuItem(value: 'delete', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }

  String _companyLabel(LpgCompany c) {
    switch (c) {
      case LpgCompany.indane:
        return 'Indane Gas';
      case LpgCompany.hpGas:
        return 'HP Gas';
      case LpgCompany.bharatGas:
        return 'Bharat Gas';
      case LpgCompany.unknown:
        return 'Unknown';
    }
  }
}

class _ConnectionEditorSheet extends StatefulWidget {
  final GasConnection? existing;
  const _ConnectionEditorSheet({this.existing});

  @override
  State<_ConnectionEditorSheet> createState() => _ConnectionEditorSheetState();
}

class _ConnectionEditorSheetState extends State<_ConnectionEditorSheet> {
  final _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameCtrl;
  late final TextEditingController _consumerCtrl;
  late final TextEditingController _phoneCtrl;
  late LpgCompany _company;
  bool _saving = false;

  static const _orange = Color(0xFFE8581A);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nicknameCtrl = TextEditingController(text: e?.nickname ?? '');
    _consumerCtrl = TextEditingController(text: e?.consumerNumber ?? '');
    _phoneCtrl = TextEditingController(text: e?.registeredPhone ?? '');
    _company = e?.company ?? LpgCompany.indane;
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _consumerCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final nickname = _nicknameCtrl.text.trim();
    final consumer = _consumerCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (widget.existing != null) {
      await _db.updateConnection(widget.existing!.copyWith(
        nickname: nickname,
        company: _company,
        consumerNumber: consumer.isEmpty ? null : consumer,
        registeredPhone: phone.isEmpty ? null : phone,
      ));
    } else {
      await _db.insertConnection(GasConnection(
        nickname: nickname,
        company: _company,
        consumerNumber: consumer.isEmpty ? null : consumer,
        registeredPhone: phone.isEmpty ? null : phone,
        createdAt: DateTime.now(),
      ));
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Form(
          key: _formKey,
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
              Text(
                widget.existing != null ? 'Edit connection' : 'Add a connection',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nicknameCtrl,
                decoration: const InputDecoration(labelText: 'Nickname *', hintText: 'e.g. Home, Mom\'s connection'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Give this connection a name' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<LpgCompany>(
                initialValue: _company,
                decoration: const InputDecoration(labelText: 'LPG company'),
                items: const [
                  DropdownMenuItem(value: LpgCompany.indane, child: Text('Indane Gas')),
                  DropdownMenuItem(value: LpgCompany.hpGas, child: Text('HP Gas')),
                  DropdownMenuItem(value: LpgCompany.bharatGas, child: Text('Bharat Gas')),
                ],
                onChanged: (v) { if (v != null) setState(() => _company = v); },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _consumerCtrl,
                decoration: const InputDecoration(labelText: 'Consumer number (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Registered mobile number (optional)'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
