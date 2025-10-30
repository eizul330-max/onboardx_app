import 'package:flutter/material.dart';
import 'package:onboardx_app/l10n/app_localizations.dart';

class BenifitsPage extends StatelessWidget {
  const BenifitsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Column(
          children: [
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
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    (AppLocalizations.of(context)!.perksandfacilities),
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
                  'assets/images/benefits1.png', // replace with your image asset
                  width: double.infinity,
                  height: 280,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.white.withOpacity(0.8),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (AppLocalizations.of(context)!.benefitsOverview1),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'A benefits overview is the support provided by a company '
                          'to its employees, outlined according to the organization’s '
                          'terms and conditions.',
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
                child: ListView(
                  children: const [
                    _BenefitItem(text: 'Easy access to public transport'),
                    _BenefitItem(text: 'Health insurance'),
                    _BenefitItem(text: 'Flexible working hour'),
                    _BenefitItem(text: 'Paid time off'),
                    _BenefitItem(text: 'Free training development programs'),
                    _BenefitItem(text: 'Employee discounts'),
                    _BenefitItem(text: 'Wellness programs'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final String text;
  const _BenefitItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}
