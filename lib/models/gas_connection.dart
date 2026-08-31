// lib/models/gas_connection.dart
//
// Represents one LPG gas connection. Most households have exactly one, but
// joint families / homes with both a domestic and commercial connection can
// have several — each tracked (and predicted) separately.

import 'cylinder_booking.dart';

class GasConnection {
  final int? id;
  final String nickname;
  final LpgCompany company;
  final String? consumerNumber;
  final String? registeredPhone;
  final bool isDefault;
  final DateTime createdAt;

  GasConnection({
    this.id,
    required this.nickname,
    required this.company,
    this.consumerNumber,
    this.registeredPhone,
    this.isDefault = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'company': company.name,
      'consumer_number': consumerNumber,
      'registered_phone': registeredPhone,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GasConnection.fromMap(Map<String, dynamic> map) {
    return GasConnection(
      id: map['id'] as int?,
      nickname: map['nickname'] ?? 'My Connection',
      company: LpgCompany.values.firstWhere(
        (e) => e.name == map['company'],
        orElse: () => LpgCompany.unknown,
      ),
      consumerNumber: map['consumer_number'],
      registeredPhone: map['registered_phone'],
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  GasConnection copyWith({
    int? id,
    String? nickname,
    LpgCompany? company,
    String? consumerNumber,
    String? registeredPhone,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return GasConnection(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      company: company ?? this.company,
      consumerNumber: consumerNumber ?? this.consumerNumber,
      registeredPhone: registeredPhone ?? this.registeredPhone,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
