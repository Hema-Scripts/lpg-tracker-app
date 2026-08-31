// lib/services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/cylinder_booking.dart';
import '../models/gas_connection.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;
  static const int _dbVersion = 2;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'lpg_tracker.db');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createConnectionsTable(db);
        await _createBookingsTable(db);

        await db.execute('''
          CREATE TABLE sms_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender TEXT,
            body TEXT,
            received_at TEXT,
            parsed INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');

        await _insertDefaultSettings(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createConnectionsTable(db);
          await db.execute('ALTER TABLE bookings ADD COLUMN connection_id INTEGER');

          // Migrate existing single-household data: create one default
          // connection from whatever was in settings, and point every
          // existing booking at it, so nothing "disappears" after update.
          final settingsRows = await db.query('settings');
          final settings = {for (final r in settingsRows) r['key'] as String: r['value'] as String?};
          final companyName = settings['lpg_company'] ?? 'indane';
          final company = LpgCompany.values.firstWhere(
            (e) => e.name == companyName || _legacySettingsCompanyMatch(e, companyName),
            orElse: () => LpgCompany.indane,
          );

          final defaultConnectionId = await db.insert('connections', {
            'nickname': 'My Connection',
            'company': company.name,
            'consumer_number': null,
            'registered_phone': settings['registered_phone'],
            'is_default': 1,
            'created_at': DateTime.now().toIso8601String(),
          });

          await db.update('bookings', {'connection_id': defaultConnectionId});
        }
      },
    );
  }

  static bool _legacySettingsCompanyMatch(LpgCompany e, String raw) {
    // Old settings screen stored display names like "Indane", "HP Gas",
    // "Bharat Gas" in some builds instead of the enum name — normalize.
    final normalized = raw.toLowerCase().replaceAll(' ', '');
    switch (e) {
      case LpgCompany.indane:
        return normalized.contains('indane');
      case LpgCompany.hpGas:
        return normalized.contains('hp');
      case LpgCompany.bharatGas:
        return normalized.contains('bharat');
      case LpgCompany.unknown:
        return false;
    }
  }

  Future<void> _createConnectionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS connections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nickname TEXT NOT NULL,
        company TEXT NOT NULL,
        consumer_number TEXT,
        registered_phone TEXT,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createBookingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE bookings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        connection_id INTEGER,
        booking_id TEXT NOT NULL,
        company TEXT NOT NULL,
        booking_date TEXT NOT NULL,
        dac_number TEXT,
        dac_date TEXT,
        delivery_date TEXT,
        price REAL,
        distributor_name TEXT,
        distributor_phone TEXT,
        cylinder_weight REAL,
        status TEXT NOT NULL,
        raw_sms TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _insertDefaultSettings(Database db) async {
    await db.insert('settings', {'key': 'notifications_delivery', 'value': 'true'});
    await db.insert('settings', {'key': 'notifications_booking', 'value': 'true'});
    await db.insert('settings', {'key': 'notifications_safety', 'value': 'false'});
    await db.insert('settings', {'key': 'language', 'value': 'en'});
    await db.insert('settings', {'key': 'lpg_company', 'value': 'indane'});
    await db.insert('settings', {'key': 'registered_phone', 'value': ''});
    await db.insert('settings', {'key': 'distributor_name', 'value': ''});
    await db.insert('settings', {'key': 'distributor_phone', 'value': ''});
    await db.insert('settings', {'key': 'sms_enabled', 'value': 'true'});
  }

  // ─── CONNECTIONS ────────────────────────────────────────────────────────

  Future<int> insertConnection(GasConnection connection) async {
    final db = await database;
    // First connection ever created is automatically the default.
    final existingCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM connections'),
        ) ??
        0;
    final isFirst = existingCount == 0;

    final id = await db.insert(
      'connections',
      connection.copyWith(isDefault: isFirst || connection.isDefault).toMap(),
    );

    if (isFirst || connection.isDefault) {
      await setDefaultConnection(id);
    }
    return id;
  }

  Future<void> updateConnection(GasConnection connection) async {
    final db = await database;
    await db.update('connections', connection.toMap(), where: 'id = ?', whereArgs: [connection.id]);
  }

  /// Deletes a connection. Bookings under it are kept but unlinked
  /// (connection_id set to NULL) rather than deleted, so history is never
  /// silently lost.
  Future<void> deleteConnection(int id) async {
    final db = await database;
    await db.update('bookings', {'connection_id': null}, where: 'connection_id = ?', whereArgs: [id]);
    await db.delete('connections', where: 'id = ?', whereArgs: [id]);

    // If we just deleted the default connection, promote another one.
    final remaining = await db.query('connections', orderBy: 'created_at ASC', limit: 1);
    if (remaining.isNotEmpty) {
      final hasDefault = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM connections WHERE is_default = 1'),
          ) ??
          0;
      if (hasDefault == 0) {
        await setDefaultConnection(remaining.first['id'] as int);
      }
    }
  }

  Future<void> setDefaultConnection(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('connections', {'is_default': 0});
      await txn.update('connections', {'is_default': 1}, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<GasConnection>> getConnections() async {
    final db = await database;
    final maps = await db.query('connections', orderBy: 'is_default DESC, created_at ASC');
    return maps.map((m) => GasConnection.fromMap(m)).toList();
  }

  Future<GasConnection?> getDefaultConnection() async {
    final db = await database;
    final maps = await db.query('connections', where: 'is_default = 1', limit: 1);
    if (maps.isEmpty) {
      final any = await db.query('connections', limit: 1, orderBy: 'created_at ASC');
      if (any.isEmpty) return null;
      return GasConnection.fromMap(any.first);
    }
    return GasConnection.fromMap(maps.first);
  }

  /// Convenience used when attaching a new booking to *some* connection.
  /// Creates a default connection on the fly if the user somehow has none
  /// (shouldn't normally happen once onboarding/migration has run).
  Future<int> getOrCreateDefaultConnectionId({LpgCompany? company}) async {
    final existing = await getDefaultConnection();
    if (existing?.id != null) return existing!.id!;
    return insertConnection(GasConnection(
      nickname: 'My Connection',
      company: company ?? LpgCompany.indane,
      isDefault: true,
      createdAt: DateTime.now(),
    ));
  }

  // ─── BOOKINGS ─────────────────────────────────────────────────────────────

  Future<int> insertBooking(CylinderBooking booking, {int? connectionId}) async {
    final db = await database;
    // Check if booking ID already exists *within the same connection* — the
    // same numeric booking ID could coincidentally repeat across two
    // separate connections/companies over the years.
    final resolvedConnectionId = connectionId ?? await getOrCreateDefaultConnectionId(company: booking.company);

    final existing = await db.query(
      'bookings',
      where: 'booking_id = ? AND (connection_id = ? OR connection_id IS NULL)',
      whereArgs: [booking.bookingId, resolvedConnectionId],
    );
    if (existing.isNotEmpty) {
      return await _mergeBooking(db, existing.first, booking, resolvedConnectionId);
    }
    final map = booking.toMap();
    map['connection_id'] = resolvedConnectionId;
    return await db.insert('bookings', map);
  }

  Future<int> _mergeBooking(
    Database db,
    Map<String, dynamic> existing,
    CylinderBooking incoming,
    int connectionId,
  ) async {
    final id = existing['id'] as int;
    final updates = <String, dynamic>{};

    if (existing['connection_id'] == null) {
      updates['connection_id'] = connectionId;
    }
    if (incoming.dacNumber != null && existing['dac_number'] == null) {
      updates['dac_number'] = incoming.dacNumber;
      updates['dac_date'] = incoming.dacDate?.toIso8601String();
    }
    if (incoming.deliveryDate != null && existing['delivery_date'] == null) {
      updates['delivery_date'] = incoming.deliveryDate!.toIso8601String();
    }
    if (incoming.price != null && existing['price'] == null) {
      updates['price'] = incoming.price;
    }
    if (incoming.distributorName != null && existing['distributor_name'] == null) {
      updates['distributor_name'] = incoming.distributorName;
    }
    if (incoming.distributorPhone != null && existing['distributor_phone'] == null) {
      updates['distributor_phone'] = incoming.distributorPhone;
    }
    if (incoming.cylinderWeight != null && existing['cylinder_weight'] == null) {
      updates['cylinder_weight'] = incoming.cylinderWeight;
    }
    // Always update status to latest, and keep the raw SMS from whichever
    // message triggered this update so the detail screen shows the most
    // recent status text (e.g. the "delivered" SMS rather than the original
    // booking confirmation).
    updates['status'] = incoming.status.name;
    updates['raw_sms'] = incoming.rawSms;

    if (updates.isNotEmpty) {
      await db.update('bookings', updates, where: 'id = ?', whereArgs: [id]);
    }
    return id;
  }

  Future<List<CylinderBooking>> getAllBookings({int? connectionId}) async {
    final db = await database;
    final maps = await db.query(
      'bookings',
      where: connectionId != null ? 'connection_id = ?' : null,
      whereArgs: connectionId != null ? [connectionId] : null,
      orderBy: 'booking_date DESC',
    );
    return maps.map((m) => CylinderBooking.fromMap(m)).toList();
  }

  /// Like [getAllBookings], but returns the raw DB rows (including
  /// `connection_id`, which `CylinderBooking` doesn't carry as a model
  /// field) — used by [BackupService] to preserve which connection each
  /// booking belongs to across export/import.
  Future<List<Map<String, dynamic>>> getAllBookingsRaw({int? connectionId}) async {
    final db = await database;
    return db.query(
      'bookings',
      where: connectionId != null ? 'connection_id = ?' : null,
      whereArgs: connectionId != null ? [connectionId] : null,
      orderBy: 'booking_date DESC',
    );
  }

  Future<CylinderBooking?> getLatestBooking({int? connectionId}) async {
    final db = await database;
    final maps = await db.query(
      'bookings',
      where: connectionId != null ? 'connection_id = ?' : null,
      whereArgs: connectionId != null ? [connectionId] : null,
      orderBy: 'booking_date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CylinderBooking.fromMap(maps.first);
  }

  Future<List<CylinderBooking>> getDeliveredBookings({int? connectionId}) async {
    final db = await database;
    final where = connectionId != null ? 'status = ? AND connection_id = ?' : 'status = ?';
    final whereArgs = connectionId != null ? ['delivered', connectionId] : ['delivered'];
    final maps = await db.query(
      'bookings',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'delivery_date DESC',
    );
    return maps.map((m) => CylinderBooking.fromMap(m)).toList();
  }

  Future<void> updateBooking(CylinderBooking booking) async {
    final db = await database;
    await db.update(
      'bookings',
      booking.toMap(),
      where: 'id = ?',
      whereArgs: [booking.id],
    );
  }

  Future<void> setBookingConnection(int bookingId, int connectionId) async {
    final db = await database;
    await db.update('bookings', {'connection_id': connectionId}, where: 'id = ?', whereArgs: [bookingId]);
  }

  Future<void> deleteBooking(int id) async {
    final db = await database;
    await db.delete('bookings', where: 'id = ?', whereArgs: [id]);
  }

  // ─── SMS LOG ──────────────────────────────────────────────────────────────

  Future<void> logSms(String sender, String body, DateTime receivedAt, bool parsed) async {
    final db = await database;
    await db.insert('sms_log', {
      'sender': sender,
      'body': body,
      'received_at': receivedAt.toIso8601String(),
      'parsed': parsed ? 1 : 0,
    });
  }

  // ─── SETTINGS ─────────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String?>> getAllSettings() async {
    final db = await database;
    final rows = await db.query('settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String?};
  }

  // ─── ANALYTICS ────────────────────────────────────────────────────────────

  /// Returns list of [deliveryDate, duration_days] pairs
  Future<List<Map<String, dynamic>>> getCylinderDurations({int? connectionId}) async {
    final delivered = await getDeliveredBookings(connectionId: connectionId);
    if (delivered.length < 2) return [];

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < delivered.length - 1; i++) {
      final current = delivered[i];
      final next = delivered[i + 1];
      if (current.deliveryDate != null && next.deliveryDate != null) {
        final days = current.deliveryDate!.difference(next.deliveryDate!).inDays.abs();
        result.add({
          'delivery_date': current.deliveryDate,
          'duration_days': days,
          'price': current.price,
        });
      }
    }
    return result;
  }

  Future<double> getTotalSpent({int? connectionId}) async {
    final db = await database;
    final where = connectionId != null ? 'WHERE price IS NOT NULL AND connection_id = ?' : 'WHERE price IS NOT NULL';
    final result = await db.rawQuery(
      'SELECT SUM(price) as total FROM bookings $where',
      connectionId != null ? [connectionId] : null,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<int, int>> getMonthlyUsage(int year, {int? connectionId}) async {
    final db = await database;
    final where = connectionId != null
        ? "status = 'delivered' AND delivery_date LIKE ? AND connection_id = ?"
        : "status = 'delivered' AND delivery_date LIKE ?";
    final args = connectionId != null ? ['$year%', connectionId] : ['$year%'];
    final result = await db.rawQuery(
      '''SELECT strftime('%m', delivery_date) as month, COUNT(*) as count
         FROM bookings
         WHERE $where
         GROUP BY month''',
      args,
    );
    final map = <int, int>{};
    for (final row in result) {
      final month = int.tryParse(row['month'] as String? ?? '') ?? 0;
      map[month] = (row['count'] as int?) ?? 0;
    }
    return map;
  }
}
