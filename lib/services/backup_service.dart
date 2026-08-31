// lib/services/backup_service.dart
//
// Everything in this app lives in a local SQLite database with no server —
// which is great for privacy, but means uninstalling the app or switching
// phones loses everything with no way to get it back. This service exports
// all connections/bookings/settings to a single JSON file the user can
// share to Drive, email to themselves, save with a file manager, etc., and
// re-import later. No data ever leaves the device except by the user's own
// explicit share action.

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/cylinder_booking.dart';
import '../models/gas_connection.dart';
import 'database_service.dart';

class ImportResult {
  final int connectionsImported;
  final int bookingsImported;
  final int bookingsSkipped;
  ImportResult({required this.connectionsImported, required this.bookingsImported, required this.bookingsSkipped});
}

class BackupService {
  final _db = DatabaseService();
  static const int _backupFormatVersion = 1;

  Future<String> _buildBackupJson() async {
    final connections = await _db.getConnections();
    final bookingRows = await _db.getAllBookingsRaw();
    final settings = await _db.getAllSettings();

    // Bookings reference a connection by its position in the connections
    // list (not its raw DB id, which won't mean anything on another
    // device/after reinstall) so restore can relink them correctly.
    final connectionIndexById = <int, int>{};
    for (int i = 0; i < connections.length; i++) {
      if (connections[i].id != null) connectionIndexById[connections[i].id!] = i;
    }

    final data = {
      'format_version': _backupFormatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'connections': connections.map((c) => {
            'nickname': c.nickname,
            'company': c.company.name,
            'consumer_number': c.consumerNumber,
            'registered_phone': c.registeredPhone,
            'is_default': c.isDefault,
          }).toList(),
      // Raw rows (not CylinderBooking.toMap()) so connection_id survives —
      // it's a DB-only column, not a CylinderBooking model field.
      'bookings': bookingRows.map((row) {
        final map = Map<String, dynamic>.from(row);
        map.remove('id');
        return map;
      }).toList(),
      'connection_index_by_id': connectionIndexById.map((k, v) => MapEntry(k.toString(), v)),
      'settings': settings,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Exports and opens the OS share sheet so the user can save it wherever
  /// they like (Drive, Files, email to self, etc.).
  Future<void> shareBackup() async {
    final json = await _buildBackupJson();
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/lpg_tracker_backup_$timestamp.json');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'LPG Tracker backup',
      text: 'LPG Tracker data backup — keep this file safe to restore your booking history later.',
    );
  }

  /// Lets the user pick a previously exported .json file and merges it in.
  /// Existing data is never deleted — this only adds connections/bookings
  /// that aren't already present, so it's safe to import the same file
  /// twice.
  Future<ImportResult?> pickAndImportBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    return importFromJson(content);
  }

  Future<ImportResult> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    final rawConnections = (data['connections'] as List?) ?? [];
    final rawBookings = (data['bookings'] as List?) ?? [];

    final existingConnections = await _db.getConnections();

    // Map: index in the backup's connections array -> real DB id after import.
    final indexToNewId = <int, int>{};

    int connectionsImported = 0;
    for (int i = 0; i < rawConnections.length; i++) {
      final c = rawConnections[i] as Map<String, dynamic>;
      final nickname = c['nickname'] as String? ?? 'Imported connection';

      // Skip creating a duplicate if a connection with the same nickname
      // and company already exists locally.
      final companyName = c['company'] as String? ?? 'unknown';
      final match = existingConnections.where((e) => e.nickname == nickname && e.company.name == companyName);
      if (match.isNotEmpty) {
        indexToNewId[i] = match.first.id!;
        continue;
      }

      final newId = await _db.insertConnection(GasConnection(
        nickname: nickname,
        company: LpgCompany.values.firstWhere((e) => e.name == companyName, orElse: () => LpgCompany.unknown),
        consumerNumber: c['consumer_number'],
        registeredPhone: c['registered_phone'],
        createdAt: DateTime.now(),
      ));
      indexToNewId[i] = newId;
      connectionsImported++;
    }

    // Figure out, for each booking in the backup, which connection index it
    // belonged to (via the id->index map saved at export time).
    final connectionIndexById = <int, int>{};
    final rawIndexMap = data['connection_index_by_id'] as Map<String, dynamic>?;
    if (rawIndexMap != null) {
      rawIndexMap.forEach((k, v) => connectionIndexById[int.parse(k)] = v as int);
    }

    int bookingsImported = 0;
    int bookingsSkipped = 0;
    for (final raw in rawBookings) {
      final map = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final oldConnectionId = map['connection_id'] as int?;
      int? newConnectionId;
      if (oldConnectionId != null) {
        final index = connectionIndexById[oldConnectionId];
        if (index != null) newConnectionId = indexToNewId[index];
      }
      map.remove('connection_id');
      map.remove('id');

      try {
        final booking = CylinderBooking.fromMap(map);
        await _db.insertBooking(booking, connectionId: newConnectionId);
        bookingsImported++;
      } catch (_) {
        bookingsSkipped++;
      }
    }

    return ImportResult(
      connectionsImported: connectionsImported,
      bookingsImported: bookingsImported,
      bookingsSkipped: bookingsSkipped,
    );
  }
}
