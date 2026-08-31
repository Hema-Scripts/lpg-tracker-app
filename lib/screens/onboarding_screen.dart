// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sms_service.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import 'main_navigation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _db = DatabaseService();
  int _currentPage = 0;
  bool _smsGranted = false;
  bool _notifGranted = false;
  bool _isScanning = false;
  bool _manualOnly = false;

  static const _orange = Color(0xFFE8581A);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestSms() async {
    final status = await Permission.sms.request();
    setState(() => _smsGranted = status.isGranted);
    if (status.isGranted) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  /// Lets someone skip SMS auto-detection entirely — e.g. iOS-style
  /// preference, no SMS permission granted by policy, bookings placed by
  /// phone call/WhatsApp with no SMS confirmation reaching this device, etc.
  /// The app is fully usable with manual entry only.
  Future<void> _useManualOnly() async {
    setState(() => _manualOnly = true);
    await _db.setSetting('sms_enabled', 'false');
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _requestNotifications() async {
    final status = await Permission.notification.request();
    setState(() => _notifGranted = status.isGranted);
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isScanning = true);

    if (!_manualOnly) {
      // Scan inbox for past LPG SMS
      final smsService = SmsService();
      await smsService.initialize();
      await smsService.scanInbox();
    }

    // Initialize notifications
    await NotificationService().initialize();

    // Mark onboarding complete
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    setState(() => _isScanning = false);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildPage0(),
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                ],
              ),
            ),
            _buildIndicators(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPage0() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: const Color(0xFFFFF0E8), borderRadius: BorderRadius.circular(24)),
            child: const Center(child: Text('🛢️', style: TextStyle(fontSize: 48))),
          ),
          const SizedBox(height: 28),
          const Text(
            'Smart LPG Tracker',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Track your Indane, HP Gas, and Bharat Gas bookings automatically using your SMS inbox.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 32),
          _buildPrivacyNote(),
          const SizedBox(height: 32),
          _primaryButton('Get Started', () {
            _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }),
        ],
      ),
    );
  }

  Widget _buildPage1() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📩', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          const Text(
            'Read SMS Inbox',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'LPG Tracker needs to read your SMS to detect booking confirmations, DAC numbers, and delivery updates from Indane, HP Gas, and Bharat Gas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 16),
          _infoBox('Your SMS data is NEVER shared with any server. Everything stays on your phone.'),
          const SizedBox(height: 32),
          _primaryButton(
            _smsGranted ? '✅ Permission Granted' : 'Allow SMS Access',
            _smsGranted ? null : _requestSms,
          ),
          if (_smsGranted) ...[
            const SizedBox(height: 12),
            _secondaryButton('Continue', () {
              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
            }),
          ] else ...[
            const SizedBox(height: 12),
            _secondaryButton("I'll add bookings manually instead", _useManualOnly),
          ],
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          const Text(
            'Enable Notifications',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Get notified when your cylinder is delivered, when it\'s time to book the next one, and safety reminders.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 32),
          _primaryButton(
            _notifGranted ? '✅ Notifications Enabled' : 'Enable Notifications',
            _notifGranted ? null : _requestNotifications,
          ),
          const SizedBox(height: 12),
          _secondaryButton('Skip for now', () {
            _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }),
        ],
      ),
    );
  }

  Widget _buildPage3() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✅', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          const Text(
            'All Set!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            _manualOnly
                ? "You're all set to add bookings manually — you can turn on SMS auto-detection later from Settings if you change your mind."
                : 'We\'ll scan your SMS inbox for past LPG messages and set up your dashboard.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 32),
          _isScanning
              ? Column(
                  children: [
                    const CircularProgressIndicator(color: _orange),
                    const SizedBox(height: 12),
                    Text(_manualOnly ? 'Setting things up...' : 'Scanning SMS inbox...', style: const TextStyle(fontSize: 14, color: _orange)),
                  ],
                )
              : _primaryButton('Start Tracking', _finishOnboarding),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Column(
        children: [
          _privacyRow('No LPG server connection', '❌'),
          _privacyRow('SMS used only for LPG tracking', '✅'),
          _privacyRow('All data stored on your device', '✅'),
          _privacyRow('No personal data shared', '✅'),
        ],
      ),
    );
  }

  Widget _privacyRow(String text, String emoji) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7EF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF9FE1CB), width: 0.5),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF1A9E5F)), textAlign: TextAlign.center),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: i == _currentPage ? 20 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: i == _currentPage ? _orange : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(3),
        ),
      )),
    );
  }
}
