// lib/services/whatsapp_order_service.dart
//
// Deep-links into WhatsApp to start a refill order with the official
// provider chatbot numbers (Indane / HP Gas / Bharat Gas all run WhatsApp-
// based booking today).
//
// IMPORTANT — what this can and can't do:
// This app has no way to read or automate what happens *inside* WhatsApp.
// WhatsApp doesn't expose any API for a third-party app to send a message
// on the user's behalf, read the chatbot's reply, or extract a delivery
// date/DAC code from that conversation. Nothing on Android (short of an
// accessibility-service screen-scraper, which is against WhatsApp's terms
// and not something this app does) can close that gap.
//
// The good news is you don't actually need that gap closed: regardless of
// *how* a refill is booked — call, WhatsApp, IVR, missed call, or the
// official app — the OMC (oil marketing company) backend still sends the
// same booking-confirmation / DAC / out-for-delivery SMS to the registered
// mobile number. Those SMS are exactly what SmsService/SmsParser already
// detect automatically. So the flow is:
//   1. This screen opens WhatsApp with the right number and a prefilled
//      message.
//   2. The user sends it and finishes booking inside WhatsApp as normal.
//   3. The confirmation SMS that the OMC sends arrives a few moments later
//      and gets picked up automatically like any other booking — no manual
//      step needed, and no automation of WhatsApp required.
import 'package:url_launcher/url_launcher.dart';
import '../models/cylinder_booking.dart';
import 'database_service.dart';

class WhatsAppOrderInfo {
  final String number;
  final String prefilledMessage;
  final String instructions;

  const WhatsAppOrderInfo({
    required this.number,
    required this.prefilledMessage,
    required this.instructions,
  });
}

class WhatsAppOrderService {
  final _db = DatabaseService();

  // Official numbers as of this writing — oil marketing companies do
  // occasionally change these, so they're editable in Settings and this is
  // only the fallback default.
  static const _defaults = <LpgCompany, WhatsAppOrderInfo>{
    LpgCompany.indane: WhatsAppOrderInfo(
      number: '917588888824',
      prefilledMessage: 'REFILL',
      instructions: 'Send from your registered mobile number to book an Indane refill.',
    ),
    LpgCompany.hpGas: WhatsAppOrderInfo(
      number: '919222201122',
      prefilledMessage: 'Hi',
      instructions: 'Send from your registered mobile number, then follow the chatbot prompts to book an HP Gas refill.',
    ),
    LpgCompany.bharatGas: WhatsAppOrderInfo(
      number: '911800224344',
      prefilledMessage: 'Hi',
      instructions: 'Send from your registered mobile number, then follow the chatbot prompts to book a Bharat Gas refill.',
    ),
  };

  static const Map<LpgCompany, String> _settingKeys = {
    LpgCompany.indane: 'whatsapp_number_indane',
    LpgCompany.hpGas: 'whatsapp_number_hpgas',
    LpgCompany.bharatGas: 'whatsapp_number_bharatgas',
  };

  String? settingKeyFor(LpgCompany company) => _settingKeys[company];

  /// Static accessor so callers (e.g. Settings screen) don't need an
  /// instance just to know which settings key backs a given company.
  static String? settingKeyForStatic(LpgCompany company) => _settingKeys[company];

  Future<WhatsAppOrderInfo> infoFor(LpgCompany company) async {
    final fallback = _defaults[company] ?? _defaults[LpgCompany.indane]!;
    final key = _settingKeys[company];
    if (key == null) return fallback;
    final override = await _db.getSetting(key);
    if (override == null || override.trim().isEmpty) return fallback;
    return WhatsAppOrderInfo(
      number: override.trim(),
      prefilledMessage: fallback.prefilledMessage,
      instructions: fallback.instructions,
    );
  }

  String defaultNumberFor(LpgCompany company) => (_defaults[company] ?? _defaults[LpgCompany.indane]!).number;

  /// Opens WhatsApp to the provider's booking number with a prefilled
  /// message. Returns false if WhatsApp (or any app that can handle a
  /// wa.me link) isn't available on the device.
  ///
  /// Deliberately doesn't gate on `canLaunchUrl` alone — that check is
  /// known to false-negative for https: links on Android 11+ even when a
  /// handler exists, so we attempt the launch and fall back gracefully.
  Future<bool> openOrder(LpgCompany company) async {
    final info = await infoFor(company);
    final digitsOnly = info.number.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digitsOnly?text=${Uri.encodeComponent(info.prefilledMessage)}');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
