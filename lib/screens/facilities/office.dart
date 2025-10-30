import 'package:flutter/material.dart';
import 'package:onboardx_app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class OfficePage extends StatelessWidget {
  const OfficePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Column(
          children: [
            // Top bar (same as BenefitsPage)
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

            // Office Image Section
            Stack(
              children: [
                // Office background image
                Container(
                  width: double.infinity,
                  height: 220,
                  color: Colors.blue[50],
                  child: Image.asset(
                    'assets/images/office.png', // Replace with your office image
                    width: double.infinity,
                    height: 280,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.business_center,
                          size: 60,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.white.withOpacity(0.9),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (AppLocalizations.of(context)!.officeFacilities),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Modern workspace designed for comfort and productivity',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Facilities List Section
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Office Location Header
                      Text(
                        (AppLocalizations.of(context)!.officelocation),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Facilities Description
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Text(
                          'We provide air-conditioned offices, a pantry and cafeteria, '
                          'dedicated toilets on each floor, elevator and prayer rooms',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Address Section
                      const Text(
                        'Enterprise Solutions (Non-SAP)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      const Text(
                        'Center of Delivery & Operation Services ICT Division\n'
                        'Tenaga Nasional Berhad Level 33, Tower 1\n'
                        'UOA Business Park 40150 Shah Alam, Selangor',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Map Section
                      Text(
                        (AppLocalizations.of(context)!.map),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Interactive Map Container
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Stack(
                          children: [
                            // Map placeholder - replace with actual map widget
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 50,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    (AppLocalizations.of(context)!.interactiveMap),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (AppLocalizations.of(context)!.tapToOpenInMaps),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Tap to open maps
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    _openMaps(context);
                                  },
                                  child: Container(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Directions Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.directions, size: 20),
                          label: Text((AppLocalizations.of(context)!.getDirections)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF107966),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            _openMaps(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMaps(BuildContext context) {
    // Simulate opening maps - replace with actual map integration
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text((AppLocalizations.of(context)!.openInMaps)),
        content: const Text('Would you like to open this location in your maps application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text((AppLocalizations.of(context)!.cancel)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Here you would typically launch the maps URL
              launchUrl(Uri.parse('https://www.google.com/maps?rlz=1C1ONGR_enMY1067MY1067&gs_lcrp=EgZjaHJvbWUqEggBEC4YJxivARjHARiABBiKBTIMCAAQRRg5GLEDGIAEMhIIARAuGCcYrwEYxwEYgAQYigUyDQgCEC4YrwEYxwEYgAQyEAgDEC4YrwEYxwEYsQMYgAQyDQgEEC4YrwEYxwEYgAQyDQgFEC4YxwEY0QMYgAQyEwgGEC4YrwEYxwEYgAQYmAUYmQUyDQgHEC4YxwEY0QMYgAQyDQgIEC4YrwEYxwEYgATSAQk0NTQzajBqMTWoAgiwAgHxBSsO3w-5w2Wp&um=1&ie=UTF-8&fb=1&gl=my&sa=X&geocode=KZFPEDhFTMwxMZXR3YvKMBE_&daddr=Jalan+Pengaturcara+U1/51,+Kawasan+Perindustrian+Temasya,+40150+Shah+Alam,+Selangor'));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text((AppLocalizations.of(context)!.openingMapsApplication)),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text((AppLocalizations.of(context)!.open)),
          ),
        ],
      ),
    );
  }
}

// You can add this to your navigation
// Navigator.push(context, MaterialPageRoute(builder: (context) => const OfficePage()));