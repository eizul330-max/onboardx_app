import 'package:flutter/material.dart';

class MotorParkingScreen extends StatelessWidget {
  const MotorParkingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            
            Expanded(
              child: Container(
                width: double.infinity,
                color: Color(0xFF107966),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: ListView(
                  children: const [
                    _Parkinginfo(text: 'Zone A (Inside)\nRM 3.00 for first hour and RM 2 for next hour'),
                    _Parkinginfo(text: 'Zone B (Outside)\nRM 2.00 for first hour and RM 1.50 for next hour'),
                    _Parkinginfo(text: 'Zone E (Office Parking)\nFree pass parking for permanent staff only'),
                  ],
                ),
              ),
            ),
          ],
        ) 
      ),
    );
  }
}

class _Parkinginfo extends StatelessWidget {
  final String text;
  const _Parkinginfo({required this.text});

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