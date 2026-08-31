// lib/models/cylinder_booking.dart

enum BookingStatus { booked, dacGenerated, outForDelivery, delivered, unknown }

enum LpgCompany { indane, hpGas, bharatGas, unknown }

class CylinderBooking {
  final int? id;
  final String bookingId;
  final LpgCompany company;
  final DateTime bookingDate;
  final String? dacNumber;
  final DateTime? dacDate;
  final DateTime? deliveryDate;
  final double? price;
  final String? distributorName;
  final String? distributorPhone;
  final double? cylinderWeight;
  final BookingStatus status;
  final String rawSms;
  final DateTime createdAt;

  CylinderBooking({
    this.id,
    required this.bookingId,
    required this.company,
    required this.bookingDate,
    this.dacNumber,
    this.dacDate,
    this.deliveryDate,
    this.price,
    this.distributorName,
    this.distributorPhone,
    this.cylinderWeight,
    required this.status,
    required this.rawSms,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'booking_id': bookingId,
      'company': company.name,
      'booking_date': bookingDate.toIso8601String(),
      'dac_number': dacNumber,
      'dac_date': dacDate?.toIso8601String(),
      'delivery_date': deliveryDate?.toIso8601String(),
      'price': price,
      'distributor_name': distributorName,
      'distributor_phone': distributorPhone,
      'cylinder_weight': cylinderWeight,
      'status': status.name,
      'raw_sms': rawSms,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CylinderBooking.fromMap(Map<String, dynamic> map) {
    return CylinderBooking(
      id: map['id'],
      bookingId: map['booking_id'] ?? '',
      company: LpgCompany.values.firstWhere(
        (e) => e.name == map['company'],
        orElse: () => LpgCompany.unknown,
      ),
      bookingDate: DateTime.parse(map['booking_date']),
      dacNumber: map['dac_number'],
      dacDate: map['dac_date'] != null ? DateTime.parse(map['dac_date']) : null,
      deliveryDate:
          map['delivery_date'] != null ? DateTime.parse(map['delivery_date']) : null,
      price: map['price'],
      distributorName: map['distributor_name'],
      distributorPhone: map['distributor_phone'],
      cylinderWeight: map['cylinder_weight'],
      status: BookingStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => BookingStatus.unknown,
      ),
      rawSms: map['raw_sms'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  CylinderBooking copyWith({
    int? id,
    String? bookingId,
    LpgCompany? company,
    DateTime? bookingDate,
    String? dacNumber,
    DateTime? dacDate,
    DateTime? deliveryDate,
    double? price,
    String? distributorName,
    String? distributorPhone,
    double? cylinderWeight,
    BookingStatus? status,
    String? rawSms,
    DateTime? createdAt,
  }) {
    return CylinderBooking(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      company: company ?? this.company,
      bookingDate: bookingDate ?? this.bookingDate,
      dacNumber: dacNumber ?? this.dacNumber,
      dacDate: dacDate ?? this.dacDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      price: price ?? this.price,
      distributorName: distributorName ?? this.distributorName,
      distributorPhone: distributorPhone ?? this.distributorPhone,
      cylinderWeight: cylinderWeight ?? this.cylinderWeight,
      status: status ?? this.status,
      rawSms: rawSms ?? this.rawSms,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Duration in days this cylinder lasted (delivery to next delivery)
  int? get durationDays {
    if (deliveryDate == null) return null;
    return null; // Calculated by PredictionService using next booking
  }

  String get companyDisplayName {
    switch (company) {
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

  String get statusDisplayName {
    switch (status) {
      case BookingStatus.booked:
        return 'Booking Confirmed';
      case BookingStatus.dacGenerated:
        return 'DAC Generated';
      case BookingStatus.outForDelivery:
        return 'Out for Delivery';
      case BookingStatus.delivered:
        return 'Delivered';
      case BookingStatus.unknown:
        return 'Unknown';
    }
  }
}
