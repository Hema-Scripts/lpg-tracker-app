// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/pdf_export_service.dart';
import '../services/backup_service.dart';
import '../services/whatsapp_order_service.dart';
import '../models/cylinder_booking.dart';
import 'connections_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseService();
  final _pdfService = PdfExportService();
  final _backupService = BackupService();
  final _whatsapp = WhatsAppOrderService();
  bool _exporting = false;
  bool _backingUp = false;
  bool _importing = false;
  bool _smsEnabled = true;
  static const _orange = Color(0xFFE8581A);

  bool _notifDelivery = true;
  bool _notifBooking = true;
  bool _notifSafety = false;
  String _language = 'English';
  String _company = 'Indane';
  final _phoneController = TextEditingController();
  final _distributorController = TextEditingController();
  final _distributorPhoneController = TextEditingController();
  final _waIndaneController = TextEditingController();
  final _waHpController = TextEditingController();
  final _waBharatController = TextEditingController();

  static const _languages = [
    'English', 'Hindi', 'Tamil', 'Telugu', 'Bengali',
    'Malayalam', 'Kannada', 'Marathi', 'Gujarati', 'Punjabi',
  ];

  static const _companies = ['Indane', 'HP Gas', 'Bharat Gas'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _distributorController.dispose();
    _distributorPhoneController.dispose();
    _waIndaneController.dispose();
    _waHpController.dispose();
    _waBharatController.dispose();
    super.dispose();
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
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _exportBackup() async {
    setState(() => _backingUp = true);
    try {
      await _backupService.shareBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _backingUp = false);
  }

  Future<void> _importBackup() async {
    setState(() => _importing = true);
    try {
      final result = await _backupService.pickAndImportBackup();
      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${result.bookingsImported} booking${result.bookingsImported == 1 ? '' : 's'}'
              '${result.connectionsImported > 0 ? ' and ${result.connectionsImported} connection${result.connectionsImported == 1 ? '' : 's'}' : ''}.',
            ),
            backgroundColor: _orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _importing = false);
  }

  Future<void> _loadSettings() async {
    _notifDelivery = (await _db.getSetting('notifications_delivery')) == 'true';
    _notifBooking = (await _db.getSetting('notifications_booking')) == 'true';
    _notifSafety = (await _db.getSetting('notifications_safety')) == 'true';
    _smsEnabled = (await _db.getSetting('sms_enabled')) != 'false';
    _language = (await _db.getSetting('language')) ?? 'English';
    _company = (await _db.getSetting('lpg_company')) ?? 'Indane';
    _phoneController.text = (await _db.getSetting('registered_phone')) ?? '';
    _distributorController.text = (await _db.getSetting('distributor_name')) ?? '';
    _distributorPhoneController.text = (await _db.getSetting('distributor_phone')) ?? '';
    _waIndaneController.text = (await _whatsapp.infoFor(LpgCompany.indane)).number;
    _waHpController.text = (await _whatsapp.infoFor(LpgCompany.hpGas)).number;
    _waBharatController.text = (await _whatsapp.infoFor(LpgCompany.bharatGas)).number;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: _orange,
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _section('Account', [
            _editTile('Registered phone', _phoneController, Icons.phone, 'registered_phone', TextInputType.phone),
            _dropdownTile('LPG company', _companies, _company, Icons.local_fire_department, (v) {
              setState(() => _company = v);
              _db.setSetting('lpg_company', v);
            }),
          ]),
          _section('Connections', [
            _actionTile(
              'Manage connections',
              'For households with more than one LPG connection',
              Icons.hub_outlined,
              () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectionsScreen()));
              },
            ),
          ]),
          _section('Distributor', [
            _editTile('Distributor name', _distributorController, Icons.store, 'distributor_name', TextInputType.text),
            _editTile('Distributor phone', _distributorPhoneController, Icons.call, 'distributor_phone', TextInputType.phone),
          ]),
          _section('SMS Auto-Detection', [
            _toggleTile(
              'Read SMS automatically',
              _smsEnabled ? 'Booking confirmations are detected from SMS' : 'Manual entry only — add bookings yourself',
              Icons.sms_outlined,
              _smsEnabled,
              (v) {
                setState(() => _smsEnabled = v);
                _db.setSetting('sms_enabled', v.toString());
                if (v) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Restart the app for SMS detection to take effect.')),
                  );
                }
              },
            ),
          ]),
          _section('Notifications', [
            _toggleTile('Delivery alerts', 'Notify when cylinder is delivered', Icons.local_shipping, _notifDelivery, (v) {
              setState(() => _notifDelivery = v);
              _db.setSetting('notifications_delivery', v.toString());
            }),
            _toggleTile('Booking reminders', 'Alert 3–5 days before gas finishes', Icons.calendar_today, _notifBooking, (v) {
              setState(() => _notifBooking = v);
              _db.setSetting('notifications_booking', v.toString());
            }),
            _toggleTile('Safety reminders', 'After each delivery', Icons.shield, _notifSafety, (v) {
              setState(() => _notifSafety = v);
              _db.setSetting('notifications_safety', v.toString());
            }),
          ]),
          _section('Language', [
            _dropdownTile('App language', _languages, _language, Icons.language, (v) {
              setState(() => _language = v);
              _db.setSetting('language', v);
            }),
          ]),
          _section('WhatsApp Ordering', [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Text(
                'Official booking numbers used by "Order Now" on the dashboard. These can change from the OMC\'s side — edit here if a number stops working.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, height: 1.4),
              ),
            ),
            _editTile('Indane WhatsApp number', _waIndaneController, Icons.chat_outlined, WhatsAppOrderService.settingKeyForStatic(LpgCompany.indane)!, TextInputType.phone),
            _editTile('HP Gas WhatsApp number', _waHpController, Icons.chat_outlined, WhatsAppOrderService.settingKeyForStatic(LpgCompany.hpGas)!, TextInputType.phone),
            _editTile('Bharat Gas WhatsApp number', _waBharatController, Icons.chat_outlined, WhatsAppOrderService.settingKeyForStatic(LpgCompany.bharatGas)!, TextInputType.phone),
          ]),
          _section('Data & Privacy', [
            _actionTile(
              _exporting ? 'Exporting…' : 'Export history as PDF',
              'Save all bookings locally',
              Icons.picture_as_pdf,
              _exporting ? null : _exportPdf,
            ),
            _actionTile(
              _backingUp ? 'Preparing backup…' : 'Backup my data',
              'Save a file you can restore later or on a new phone',
              Icons.backup_outlined,
              _backingUp ? null : _exportBackup,
            ),
            _actionTile(
              _importing ? 'Importing…' : 'Restore from backup',
              'Import a previously exported backup file',
              Icons.restore_outlined,
              _importing ? null : _importBackup,
            ),
            _infoTile('Privacy', 'All data stays on your device. No data is sent to any server.', Icons.lock),
            _infoTile('App version', '1.0.0 — Not affiliated with any LPG company', Icons.info_outline),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.8),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 0.5),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _toggleTile(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: _orange),
        ],
      ),
    );
  }

  Widget _dropdownTile(String title, List<String> options, String current, IconData icon, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          DropdownButton<String>(
            value: current,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 13, color: _orange, fontWeight: FontWeight.w500),
            onChanged: (v) { if (v != null) onChanged(v); },
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _editTile(String title, TextEditingController ctrl, IconData icon, String settingKey, TextInputType keyboard) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: keyboard,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: title,
                labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (v) => _db.setSetting(settingKey, v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(String title, String subtitle, IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
