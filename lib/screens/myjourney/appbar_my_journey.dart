import 'package:flutter/material.dart';
import 'package:onboardx_app/l10n/app_localizations.dart';
import 'timeline_screen.dart';
import 'checklist_screen.dart';

class AppBarMyJourney extends StatefulWidget {
  const AppBarMyJourney({super.key});

  @override
  State<AppBarMyJourney> createState() => _AppBarMyJourneyState();
}

class _AppBarMyJourneyState extends State<AppBarMyJourney> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          (AppLocalizations.of(context)!.myjourney),
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color.fromARGB(0, 255, 255, 255),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF107966),
          labelColor: const Color(0xFF107966),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: (AppLocalizations.of(context)!.timeline)), 
            Tab(text: (AppLocalizations.of(context)!.checklist)), 
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TimelineScreen(),
          ChecklistScreen(),
        ],
      ),
    );
  }
}