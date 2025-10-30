import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:onboardx_app/l10n/app_localizations.dart';
import 'package:onboardx_app/screens/facilities/benefits.dart';
import 'package:onboardx_app/screens/facilities/canteen.dart';
import 'package:onboardx_app/screens/facilities/office.dart';
import 'package:onboardx_app/screens/facilities/parking.dart';

class PerksFacilitiesScreen extends StatefulWidget {
  const PerksFacilitiesScreen({super.key});

  @override
  State<PerksFacilitiesScreen> createState() => _PerksFacilitiesScreenState();
}

class _PerksFacilitiesScreenState extends State<PerksFacilitiesScreen> {
  int selectedIndex = -1;

  final List<Map<String, String>> perksList = [
    {
      "title": "Benefits Overview",
      "image": "assets/images/benefits.png",
    },
    {
      "title": "Your Office’s Location",
      "image": "assets/images/office.png",
    },
    {
      "title": "Canteen Menu",
      "image": "assets/images/canteen.png",
    },
    {
      "title": "Parking Info",
      "image": "assets/images/parking.png",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(
          (AppLocalizations.of(context)!.perksandfacilities),
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
        leading: Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF107966),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: (AppLocalizations.of(context)!.search),
                  filled: true,
                  fillColor: Colors.grey[300],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Perks List
              Expanded(
                child: ListView.builder(
                  itemCount: perksList.length,
                  itemBuilder: (context, index) {
                    bool isSelected = selectedIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedIndex = index;
                        });

                        // Navigate based on selected item
                        if (perksList[index]["title"] == "Benefits Overview") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BenifitsPage(),
                            ),
                          );
                        }
                        else if (perksList[index]["title"] ==
                            "Your Office’s Location") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OfficePage(),
                            ),
                          );
                        }
                        else if (perksList[index]["title"] ==
                            "Canteen Menu") {
                              Navigator.push(context, 
                              MaterialPageRoute(builder: (context) => const CanteenPage(),),
                              );
                          // Implement navigation to Canteen Menu page
                        }
                        else if (perksList[index]["title"] ==
                            "Parking Info") {
                              Navigator.push(context, 
                              MaterialPageRoute(builder: (context) => const ParkingPage(),),
                              );
                          // Implement navigation to Parking Info page
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                          image: DecorationImage(
                            image: AssetImage(perksList[index]["image"]!),
                            fit: BoxFit.cover,
                            colorFilter: isSelected
                                ? null
                                : ColorFilter.mode(
                                    Colors.black.withOpacity(0.3),
                                    BlendMode.darken,
                                  ),
                          ),
                        ),
                        height: 100,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          perksList[index]["title"]!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
