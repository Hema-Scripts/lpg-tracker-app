// lib/screens/safety_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  static const _orange = Color(0xFFE8581A);
  static const _red = Color(0xFFD93B3B);

  static const _emergencyNumbers = [
    {'name': 'Gas Leak Helpline', 'number': '1906'},
    {'name': 'Indane Customer Care', 'number': '1800-2333-555'},
    {'name': 'HP Gas Helpline', 'number': '1800-2333-555'},
    {'name': 'Bharat Gas Helpline', 'number': '1800-22-4344'},
    {'name': 'Fire Emergency', 'number': '101'},
  ];

  static const _safetyGuides = [
    {
      'icon': '🔍',
      'title': 'Check cylinder seal',
      'subtitle': 'Verify seal integrity on delivery',
      'color': Color(0xFFFFF0E8),
      'content': '''When your cylinder is delivered:
      
1. Check that the safety cap is intact and not tampered with.
2. The BIS seal should be present and unbroken.
3. The date stamp on the valve should not be expired.
4. Refuse delivery if the seal is broken or missing.
5. Ask the delivery agent for a replacement if needed.''',
    },
    {
      'icon': '⚖️',
      'title': 'Verify cylinder weight',
      'subtitle': '14.2 kg standard, tolerance ±150g',
      'color': Color(0xFFE8F1FF),
      'content': '''Standard cylinder weight verification:

1. A full 14.2 kg cylinder should weigh 14.2 kg of gas + tare weight (usually 15-17 kg total).
2. Tare weight is printed on the cylinder collar.
3. Ask the delivery agent to weigh it with a scale if you have doubts.
4. Short-fill complaints can be lodged at 1906 or on your LPG company's app.''',
    },
    {
      'icon': '💨',
      'title': 'Gas leak procedure',
      'subtitle': 'What to do if you smell gas',
      'color': Color(0xFFFDEAEA),
      'content': '''If you smell gas (rotten egg smell):

1. DO NOT switch on/off any electrical switches.
2. DO NOT light a match or flame.
3. Close the cylinder valve immediately.
4. Open all windows and doors for ventilation.
5. Evacuate everyone from the area.
6. Call the gas leak helpline: 1906.
7. Do not re-enter until cleared by authorities.''',
    },
    {
      'icon': '🔧',
      'title': 'Regulator safety',
      'subtitle': 'How to check and replace regulators',
      'color': Color(0xFFE6F7EF),
      'content': '''Regulator safety guidelines:

1. Replace regulators every 5 years (check date stamp).
2. Ensure ISI mark (IS 8944) is present on the regulator.
3. Check for gas smell around the regulator connection.
4. Never use soap water to check for leaks near a flame.
5. Use soapy water (no flame) to detect leaks — bubbles indicate a leak.
6. Buy regulators only from authorized dealers.''',
    },
    {
      'icon': '📋',
      'title': 'After delivery checklist',
      'subtitle': 'Steps to follow after every delivery',
      'color': Color(0xFFF5F0FF),
      'content': '''Post-delivery safety checklist:

1. ✅ Check cylinder seal is intact.
2. ✅ Verify cylinder weight (optional).
3. ✅ Inspect rubber tube for cracks or damage.
4. ✅ Check regulator connection is tight.
5. ✅ Test for leaks with soapy water.
6. ✅ Keep cylinder upright and in a ventilated area.
7. ✅ Never store cylinder near heat sources.
8. ✅ Collect the cash memo / delivery receipt.''',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: _orange,
        title: const Text('Safety', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildEmergencyCard(context),
          const SizedBox(height: 12),
          _sectionLabel('Safety guides'),
          const SizedBox(height: 8),
          ..._safetyGuides.map((guide) => _buildGuideItem(context, guide)),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEAEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5BBBB), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🚨 Emergency contacts',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _red,
            ),
          ),
          const SizedBox(height: 10),
          ..._emergencyNumbers.map((e) => GestureDetector(
                onTap: () => _callNumber(e['number']!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e['name']!,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          e['number']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildGuideItem(BuildContext context, Map<String, dynamic> guide) {
    return GestureDetector(
      onTap: () => _showGuideDetail(context, guide),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: guide['color'] as Color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(guide['icon'] as String, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guide['title'] as String,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    guide['subtitle'] as String,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showGuideDetail(BuildContext context, Map<String, dynamic> guide) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${guide['icon']}  ${guide['title']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              guide['content'] as String,
              style: const TextStyle(fontSize: 14, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }

  void _callNumber(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.8,
        ),
      );
}
