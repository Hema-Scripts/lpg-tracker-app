// lib/services/sms_parser.dart
//
// Parses SMS from Indane, HP Gas, and Bharat Gas.
// Uses regex only — no network calls, no scraping.

import '../models/cylinder_booking.dart';

class SmsParser {
  // ─── SENDER ID PATTERNS ──────────────────────────────────────────────────

  static const _indaneSenders = [
    'INDANE', 'IOCGAS', 'IOCLPG', 'INDGAS', 'IOC-LPG', 'INDANE-GAS',
    'VM-INDANE', 'BP-INDANE', 'VK-INDANE', 'AM-INDANE', 'LT-INDANE',
  ];

  static const _hpSenders = [
    'HPGAS', 'HP-GAS', 'HPCGAS', 'HPCL', 'HPCLPG', 'VM-HPGAS',
    'BP-HPGAS', 'LT-HPGAS', 'AM-HPGAS', 'HINDUSTAN-PETROLEUM',
  ];

  static const _bharatSenders = [
    'BHARATGAS', 'BPCGAS', 'BPCLLPG', 'BPCLPG', 'VM-BPCL',
    'BP-BPCL', 'LT-BPCL', 'BHARAT-GAS', 'BHARATPETROLE',
  ];

  // ─── BOOKING CONFIRMATION PATTERNS ───────────────────────────────────────

  static final _bookingPatterns = [
    // Indane: "Your booking no. 1234567 has been registered"
    RegExp(
      r'(?:booking|order)\s*(?:no\.?|number|#|id)[\s:]*([A-Z0-9\-]{5,15})',
      caseSensitive: false,
    ),
    // HP Gas: "Booking ID 9876543 confirmed"
    RegExp(
      r'(?:booking|order)\s*(?:id|ID)[\s:#]*(\d{6,12})',
      caseSensitive: false,
    ),
    // Bharat Gas: "Ref No 4567890 received"
    RegExp(
      r'(?:ref|reference)\s*(?:no\.?|number|#)[\s:]*([A-Z0-9\-]{5,15})',
      caseSensitive: false,
    ),
    // Generic fallback: any 7-10 digit number, used only if none of the
    // more specific booking patterns above matched.
    RegExp(
      r'\b(\d{7,10})\b',
      caseSensitive: false,
    ),
  ];

  // Indian mobile numbers (10 digits starting 6-9) that the generic fallback
  // pattern above should never mistake for a booking ID, e.g. a distributor's
  // "call us on 98765xxxxx" contact line.
  static final _mobileNumberPattern = RegExp(r'^[6-9]\d{9}$');

  // ─── DAC NUMBER PATTERNS ─────────────────────────────────────────────────

  static final _dacPatterns = [
    // "DAC No: 902847" or "DAC number 902847"
    RegExp(
      r'DAC\s*(?:no\.?|number|#|:)?\s*[:\-]?\s*([A-Z0-9\-]{4,12})',
      caseSensitive: false,
    ),
    // "Delivery Authorization Code: 1234"
    RegExp(
      r'delivery\s*auth(?:orization)?\s*(?:code|no\.?|#)[\s:]*([A-Z0-9\-]{4,12})',
      caseSensitive: false,
    ),
    // "Cash Memo No: 5678"
    RegExp(
      r'cash\s*memo\s*(?:no\.?|#|:)?\s*([A-Z0-9\-]{4,12})',
      caseSensitive: false,
    ),
  ];

  // ─── DELIVERY DATE PATTERNS ───────────────────────────────────────────────

  static final _deliveryDatePatterns = [
    // "delivery on 25-03-2025" or "25/03/2025"
    RegExp(
      r'(?:delivery|deliver(?:ed)?|expected)\s*(?:on|by|date)?[\s:]*(\d{1,2}[\-/\.]\d{1,2}[\-/\.]\d{2,4})',
      caseSensitive: false,
    ),
    // "by 25 March 2025"
    RegExp(
      r'(?:by|on)\s+(\d{1,2}\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{2,4})',
      caseSensitive: false,
    ),
  ];

  // ─── PRICE PATTERNS ──────────────────────────────────────────────────────

  static final _pricePatterns = [
    // "Rs. 903.50" or "INR 903" or "₹903.50"
    RegExp(
      r'(?:Rs\.?|INR|₹)\s*(\d{3,4}(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    // "amount: 903.50"
    RegExp(
      r'(?:amount|price|cost)[\s:]*(?:Rs\.?|INR|₹)?\s*(\d{3,4}(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
  ];

  // ─── DISTRIBUTOR PATTERNS ─────────────────────────────────────────────────

  static final _distributorPatterns = [
    RegExp(
      r'(?:distributor|agency|dealer)[\s:]+([A-Za-z\s]{3,40}?)(?:\.|,|\n|$)',
      caseSensitive: false,
    ),
  ];

  // ─── CYLINDER WEIGHT PATTERNS ─────────────────────────────────────────────

  static final _weightPatterns = [
    RegExp(r'(\d{1,2}(?:\.\d)?)\s*(?:kg|KG|Kg)', caseSensitive: false),
  ];

  // ─── STATUS KEYWORD DETECTION ─────────────────────────────────────────────

  static final _deliveredKeywords = RegExp(
    r'\b(?:delivered|dispatch(?:ed)?|cylinder\s+delivered|gas\s+delivered|delivered\s+successfully)\b',
    caseSensitive: false,
  );

  static final _dacKeywords = RegExp(
    r'\bDAC\b|delivery\s+auth(?:orization)?|cash\s+memo',
    caseSensitive: false,
  );

  static final _bookingKeywords = RegExp(
    r'\b(?:booked?|booking\s+(?:confirmed|received|registered)|order\s+(?:confirmed|placed)|registered\s+successfully)\b',
    caseSensitive: false,
  );

  static final _outForDeliveryKeywords = RegExp(
    r'\b(?:out\s+for\s+delivery|on\s+the\s+way|en\s+route|dispatched\s+today|will\s+be\s+delivered\s+today)\b',
    caseSensitive: false,
  );

  // ─── PUBLIC API ───────────────────────────────────────────────────────────

  /// Returns true if this SMS is from an LPG company
  static bool isLpgSms(String sender, String body) {
    final s = sender.toUpperCase();
    final b = body.toUpperCase();

    final senderMatch = _indaneSenders.any((id) => s.contains(id)) ||
        _hpSenders.any((id) => s.contains(id)) ||
        _bharatSenders.any((id) => s.contains(id));

    if (senderMatch) return true;

    // Fallback: body keyword check (some carriers strip sender)
    return b.contains('INDANE') ||
        b.contains('HP GAS') ||
        b.contains('BHARAT GAS') ||
        b.contains('HPCL') ||
        b.contains('BPCL') ||
        (b.contains('CYLINDER') &&
            (b.contains('BOOKING') ||
                b.contains('DELIVER') ||
                b.contains('DAC')));
  }

  /// Parse an SMS body + sender into a CylinderBooking object
  /// Returns null if the SMS is not LPG-related or cannot be parsed
  static CylinderBooking? parse(String sender, String body, DateTime receivedAt) {
    if (!isLpgSms(sender, body)) return null;

    final company = _detectCompany(sender, body);
    final status = _detectStatus(body);
    final bookingId = _extractFirst(body, _bookingPatterns) ?? 'UNK-${receivedAt.millisecondsSinceEpoch}';
    final dacNumber = _extractFirst(body, _dacPatterns);
    final price = _extractPrice(body);
    final deliveryDate = _extractDeliveryDate(body, receivedAt);
    final distributorName = _extractFirst(body, _distributorPatterns)?.trim();
    final weight = _extractWeight(body);

    return CylinderBooking(
      bookingId: bookingId,
      company: company,
      bookingDate: receivedAt,
      dacNumber: dacNumber,
      dacDate: dacNumber != null ? receivedAt : null,
      deliveryDate: status == BookingStatus.delivered ? receivedAt : deliveryDate,
      price: price,
      distributorName: distributorName,
      cylinderWeight: weight,
      status: status,
      rawSms: body,
      createdAt: DateTime.now(),
    );
  }

  // ─── PRIVATE HELPERS ──────────────────────────────────────────────────────

  static LpgCompany _detectCompany(String sender, String body) {
    final s = sender.toUpperCase();
    final b = body.toUpperCase();

    if (_indaneSenders.any((id) => s.contains(id)) ||
        b.contains('INDANE') ||
        b.contains('IOCL')) {
      return LpgCompany.indane;
    }
    if (_hpSenders.any((id) => s.contains(id)) ||
        b.contains('HP GAS') ||
        b.contains('HPCL') ||
        b.contains('HINDUSTAN')) {
      return LpgCompany.hpGas;
    }
    if (_bharatSenders.any((id) => s.contains(id)) ||
        b.contains('BHARAT GAS') ||
        b.contains('BPCL')) {
      return LpgCompany.bharatGas;
    }
    return LpgCompany.unknown;
  }

  static BookingStatus _detectStatus(String body) {
    if (_deliveredKeywords.hasMatch(body)) return BookingStatus.delivered;
    if (_outForDeliveryKeywords.hasMatch(body)) return BookingStatus.outForDelivery;
    if (_dacKeywords.hasMatch(body)) return BookingStatus.dacGenerated;
    if (_bookingKeywords.hasMatch(body)) return BookingStatus.booked;
    return BookingStatus.unknown;
  }

  static String? _extractFirst(String body, List<RegExp> patterns) {
    for (final pattern in patterns) {
      // Use allMatches so the generic fallback pattern can skip over
      // false positives (like a 10-digit mobile number) instead of
      // giving up on the whole SMS.
      for (final match in pattern.allMatches(body)) {
        if (match.groupCount < 1) continue;
        final val = match.group(1)?.trim();
        if (val == null || val.isEmpty) continue;
        if (identical(pattern, _bookingPatterns.last) &&
            _mobileNumberPattern.hasMatch(val)) {
          continue; // looks like a phone number, not a booking ID
        }
        return val;
      }
    }
    return null;
  }

  static double? _extractPrice(String body) {
    for (final pattern in _pricePatterns) {
      final match = pattern.firstMatch(body);
      if (match != null && match.groupCount >= 1) {
        return double.tryParse(match.group(1)!.replaceAll(',', ''));
      }
    }
    return null;
  }

  static double? _extractWeight(String body) {
    final match = _weightPatterns.first.firstMatch(body);
    if (match != null && match.groupCount >= 1) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  static DateTime? _extractDeliveryDate(String body, DateTime fallback) {
    for (final pattern in _deliveryDatePatterns) {
      final match = pattern.firstMatch(body);
      if (match != null && match.groupCount >= 1) {
        final raw = match.group(1)!;
        final parsed = _parseIndianDate(raw);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  /// Parse DD-MM-YYYY, DD/MM/YYYY, DD.MM.YYYY
  static DateTime? _parseIndianDate(String raw) {
    try {
      final parts = raw.split(RegExp(r'[\-/\.]'));
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }
}
