import 'package:flutter/material.dart';
import 'package:onboardx_app/l10n/app_localizations.dart';

class CanteenPage extends StatefulWidget {
  const CanteenPage({super.key});

  @override
  State<CanteenPage> createState() => _CanteenPage();
}

class _CanteenPage extends State<CanteenPage>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.grey[200],
        body: SafeArea(
            child: Column(children: [
          // Top bar
          Container(
            color: Colors.grey[300],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Back button
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF107966),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  (AppLocalizations.of(context)!.canteenmenu),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Image + Benefits Overview
          Stack(
            children: [
              // Background image
              Image.asset(
                'assets/images/canteen1.png',
                width: double.infinity,
                height: 280,
                fit: BoxFit.cover,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: const Color.fromARGB(54, 255, 255, 255)
                      .withOpacity(0.8),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (AppLocalizations.of(context)!.canteenOverview),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'We take great care to maintain a clean canteen environment and '
                        'prepare food with the highest standards of hygiene.',
                        style: TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom red container
          Expanded(
            child: Container(
              width: double.infinity,
              color: Color(0xFF107966),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((AppLocalizations.of(context)!.availableStall),
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        _BenefitItem(
                            text: 'Stall 1',
                            onTap: () => _showStallMenu(context, 'Stall 1')),
                        _BenefitItem(
                            text: 'Stall 2',
                            onTap: () => _showStallMenu(context, 'Stall 2')),
                        _BenefitItem(
                            text: 'Stall 3',
                            onTap: () => _showStallMenu(context, 'Stall 3')),
                        _BenefitItem(
                            text: 'Stall 4',
                            onTap: () => _showStallMenu(context, 'Stall 4')),
                        _BenefitItem(
                            text: 'Stall 5',
                            onTap: () => _showStallMenu(context, 'Stall 5')),
                        _BenefitItem(
                            text: 'Stall 6',
                            onTap: () => _showStallMenu(context, 'Stall 6')),
                        _BenefitItem(
                            text: 'Stall 7',
                            onTap: () => _showStallMenu(context, 'Stall 7')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ])));
  }

  void _showStallMenu(BuildContext context, String stallName) {
    // Example menu – you can replace with real data
    final List<String> menuItems = List.generate(
        20, (index) => '$stallName Item ${index + 1}'); // long list demo

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, controller) {
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2)),
                ),
                Text(
                  '$stallName Menu',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(menuItems[index]),
                        leading: const Icon(Icons.fastfood),
                        onTap: () {
                          Navigator.pop(context); // close bottom sheet
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Card-style clickable stall
class _BenefitItem extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _BenefitItem({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.store, color: Color(0xFF107966)),
              const SizedBox(width: 12),
              Text(
                text,
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 16)
            ],
          ),
        ),
      ),
    );
  }
}
