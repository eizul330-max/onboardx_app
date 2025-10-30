// home_screen.dart
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:onboardx_app/screens/auth/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onboardx_app/screens/document/document_manager_screen.dart';
import 'package:onboardx_app/screens/facilities/perks_facilities_screen.dart';
import 'package:onboardx_app/screens/learninghub/learning_hub_screen.dart';
import 'package:onboardx_app/screens/meettheteam/meet_the_team_screen.dart';
import 'package:onboardx_app/screens/myjourney/appbar_my_journey.dart';
import 'package:onboardx_app/screens/myjourney/timeline_screen.dart';
import 'package:onboardx_app/screens/qrcodescanner/qr_code_scanner.dart';
import 'package:onboardx_app/screens/setting/setting_screen.dart';
import 'package:onboardx_app/screens/setting/manage_your_account_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:onboardx_app/services/user_service.dart';
import 'package:onboardx_app/services/team_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _userData;
  bool _isCheckingVerification = true;

  // Use UserService & TeamService instead of SupabaseService
  final UserService _userService = UserService();
  final TeamService _teamService = TeamService();

  List<Map<String, dynamic>> _projects = [];

  // List of screens for each tab
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeContent(), // Home tab (loads its own data)
      const HomeContent(), // QR Code Scanner tab
      const SettingScreen(), // Settings tab
    ];

    _loadUserData();

    // Check email verification after UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEmailVerification();
    });
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Load basic user data for header / caching (optional)
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Try to fetch full profile via backend
      final profile = await _userService.getUserProfile(user.uid);

      if (!mounted) return;

      final merged = <String, dynamic>{};

      if (profile != null) {
        // profile already contains user fields and optionally `team` object
        merged.addAll(profile);

        // canonicalize keys for UI
        merged['fullName'] = profile['full_name'] ?? profile['fullName'] ?? profile['displayName'];
        merged['email'] = profile['email'] ?? profile['email'];
        merged['phoneNumber'] = profile['phone_number'] ?? profile['phoneNumber'];
        merged['workType'] = profile['work_type'] ?? profile['workType'];
        merged['username'] = profile['username'] ?? profile['username'];

        // profileImageUrl is provided by backend as profileImageUrl (see backend code)
        if (profile['profileImageUrl'] != null) {
          merged['profileImageUrl'] = profile['profileImageUrl'];
        } else if (profile['profile_image'] != null) {
          // backend may expose profile_image; backend typically builds profileImageUrl
          merged['profileImageUrl'] = profile['profile_image'];
        }

        // team info - backend attaches `team` if available
        if (profile['team'] != null && profile['team'] is Map) {
          merged['workTeam'] = profile['team']['work_team'] ?? merged['workTeam'];
          merged['workPlace'] = profile['team']['work_place'] ?? merged['workPlace'];
        } else {
          // fallback to fields on user document
          merged['workTeam'] = profile['work_team'] ?? profile['work_unit'] ?? merged['workTeam'];
          merged['workPlace'] = profile['work_place'] ?? merged['workPlace'];
        }
      }

      setState(() {
        _userData = merged;
      });
    } catch (e) {
      // keep silent but log for debugging
      print('Error loading user data in HomeScreen: $e');
    }
  }

  Future<void> _checkEmailVerification() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null && !user.emailVerified) {
        if (!mounted) return;
        _showVerificationDialog(context, user);
      }

      if (!mounted) return;
      setState(() {
        _isCheckingVerification = false;
      });
    } catch (e) {
      print('Error checking email verification: $e');
      if (!mounted) return;
      setState(() {
        _isCheckingVerification = false;
      });
    }
  }

  void _showVerificationDialog(BuildContext context, User user) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Email Not Verified'),
          content: const Text(
              'Please verify your email address before using the app. '
              'Check your inbox for a verification email.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Resend Verification'),
              onPressed: () async {
                try {
                  await user.sendEmailVerification();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification email sent!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _signOut();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    final primaryColor = isDarkMode
        ? const Color.fromRGBO(180, 100, 100, 1)
        : const Color.fromRGBO(224, 124, 124, 1);

    if (_isCheckingVerification) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNavBar(primaryColor),
    );
  }

  // Bottom Navigation Bar
  Widget _buildBottomNavBar(Color primaryColor) {
    return CurvedNavigationBar(
      backgroundColor: Colors.transparent,
      color: primaryColor,
      buttonBackgroundColor: primaryColor,
      height: 60,
      items: const <Widget>[
        Icon(Icons.home, size: 30, color: Colors.white),
        Icon(Icons.qr_code_scanner, size: 30, color: Colors.white),
        Icon(Icons.settings, size: 30, color: Colors.white),
      ],
      index: _selectedIndex,
      onTap: _onItemTapped,
      letIndexChange: (index) => true,
    );
  }
}

// Home Content Widget (With Profile Image Support)
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _isHeaderExpanded = false;
  Map<String, dynamic>? _userData;
  Color? primaryColor;

  // Use backend services
  final UserService _userService = UserService();
  final TeamService _teamService = TeamService();

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Load data when widget initializes
  }

  // Combined function to load user data from backend
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final profile = await _userService.getUserProfile(user.uid);

      if (!mounted) return;

      String? profileImageUrl;
      final merged = <String, dynamic>{};

      if (profile != null) {
        merged.addAll(profile);
        merged['fullName'] = profile['full_name'] ?? profile['fullName'] ?? profile['displayName'];
        merged['email'] = profile['email'] ?? merged['email'];
        merged['phoneNumber'] = profile['phone_number'] ?? merged['phoneNumber'];
        merged['username'] = profile['username'] ?? merged['username'];
        merged['workType'] = profile['work_type'] ?? merged['workType'];

        // backend returns profileImageUrl if available
        if (profile['profileImageUrl'] != null) {
          profileImageUrl = profile['profileImageUrl'];
        } else if (profile['profile_image'] != null) {
          profileImageUrl = profile['profile_image'];
        }
      }

      if (profileImageUrl != null) merged['profileImageUrl'] = profileImageUrl;

      // Get team info if backend did not attach team, try using team_no
      try {
        if (profile != null) {
          if (profile['team'] != null && profile['team'] is Map) {
            merged['workTeam'] = profile['team']['work_team'] ?? merged['workTeam'];
            merged['workPlace'] = profile['team']['work_place'] ?? merged['workPlace'];
          } else if (profile['team_no'] != null) {
            final teamData = await _teamService.getTeamByNoTeam(profile['team_no'].toString());
            if (teamData != null) {
              merged['workTeam'] = teamData['work_team'] ?? merged['workTeam'];
              merged['workPlace'] = teamData['work_place'] ?? merged['workPlace'];
            }
          } else {
            merged['workTeam'] = profile['work_team'] ?? profile['work_unit'] ?? merged['workTeam'];
            merged['workPlace'] = profile['work_place'] ?? merged['workPlace'];
          }
        }
      } catch (e) {
        print('Error loading team info in HomeContent: $e');
      }

      setState(() {
        _userData = merged;
      });

      print('Loaded user data: $_userData');
      print('Profile image URL: ${_userData?['profileImageUrl']}');
    } catch (e) {
      print('Error loading user data in HomeContent: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  void _toggleHeaderExpansion() {
    if (!mounted) return;
    setState(() {
      _isHeaderExpanded = !_isHeaderExpanded;
    });
  }

  // Helper: launch URL
  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    primaryColor = isDarkMode
        ? const Color.fromRGBO(180, 100, 100, 1)
        : const Color.fromRGBO(224, 124, 124, 1);

    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color;
    final hintColor = theme.hintColor;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExpandableUserHeader(primaryColor!),
            const SizedBox(height: 24),
            _buildQuickActions(primaryColor!, cardColor, textColor),
            const SizedBox(height: 24),
            _buildNewsSection(textColor),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableUserHeader(Color primaryColor) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    return GestureDetector(
      onTap: _toggleHeaderExpansion,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _isHeaderExpanded
            ? Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManageAccountScreen(
                                user: _userData ?? <String, dynamic>{},
                              ),
                            ),
                          );
                        },
                        child: _buildProfileAvatar(radius: 40, iconSize: 40),
                      ),
                      const SizedBox(height: 20),
                      _buildDetailRow(
                        Icons.person,
                        _userData?['fullName'] ?? "Loading...",
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.email,
                        _userData?['email'] ?? "Loading...",
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.phone,
                        _userData?['phoneNumber'] ?? "Loading...",
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.business,
                        "${_userData?['workTeam'] ?? "Loading"} | ${_userData?['workPlace'] ?? "Loading"}",
                        maxLines: 2,
                        align: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.work,
                        _userData?['workType'] ?? "Loading...",
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      const Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.white,
                        size: 30,
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManageAccountScreen(
                                user: _userData ?? <String, dynamic>{},
                              ),
                            ),
                          );
                        },
                        child: _buildProfileAvatar(radius: 30, iconSize: 30),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Hello,",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                          Text(
                            _userData?['username'] ??
                                _userData?['fullName'] ??
                                "Loading...",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout,
                            color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 30,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileAvatar(
      {required double radius, required double iconSize}) {
    final String? profileImageUrl = _userData?['profileImageUrl'] as String?;

    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(profileImageUrl),
        onBackgroundImageError: (exception, stackTrace) {
          print('Error loading profile image: $exception');
        },
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: Icon(Icons.person, size: iconSize, color: Colors.grey),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String text,
    {int maxLines = 2, TextAlign align = TextAlign.center}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start, // Penting untuk multi-line
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3), // Sesuaikan posisi vertikal icon
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 3), // Jarak sangat rapat
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: align,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildQuickActions(
      Color primaryColor, Color cardColor, Color? textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Action",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      _buildSmallActionCompact(
                          SvgPicture.asset("assets/svgs/Learning Hub.svg"),
                          "Learning\nHub",
                          primaryColor,
                          textColor),
                      const SizedBox(height: 20),
                      _buildSmallActionCompact(
                          SvgPicture.asset("assets/svgs/Facilities.svg"),
                          "Facilities\n",
                          primaryColor,
                          textColor),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _buildSmallActionCompact(
                          SvgPicture.asset("assets/svgs/My Document.svg"),
                          "My\nDocument",
                          primaryColor,
                          textColor),
                      const SizedBox(height: 20),
                      _buildCenterJourneyCompact(primaryColor),
                      const SizedBox(height: 20),
                      _buildSmallActionCompact(
                          SvgPicture.asset("assets/svgs/Task Manager.svg"),
                          "Task\nManager",
                          primaryColor,
                          textColor),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      _buildSmallActionCompact(
                          SvgPicture.asset("assets/svgs/Meet the Team.svg"),
                          "Meet the\nTeam",
                          primaryColor,
                          textColor),
                      const SizedBox(height: 20),
                      _buildSmallActionCompact(
                          SvgPicture.asset("assets/svgs/Buddy Chat.svg"),
                          "Buddy\nChat",
                          primaryColor,
                          textColor),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActionCompact(
      Widget icon, String label, Color color, Color? textColor) {
    return GestureDetector(
      onTap: () {
        if (label == "Learning\nHub") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeContent(),
            ),
          );
        }
        if (label == "Facilities\n") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PerksFacilitiesScreen(),
            ),
          );
        }
        if (label == "My\nDocument") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DocumentManagerScreen(),
            ),
          );
        }
        if (label == "Task\nManager") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeContent(),
            ),
          );
        }
        if (label == "Meet the\nTeam") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MeetTheTeamScreen(),
            ),
          );
        }
        if (label == "Buddy\nChat") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MeetTheTeamScreen(),
            ),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 50, height: 50, child: icon),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterJourneyCompact(Color color) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HomeContent()),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkMode
                  ? Colors.grey[800]
                  : const Color.fromRGBO(245, 245, 247, 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.18)
                      : Colors.white.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 0),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag, size: 60, color: Colors.white),
                      Text(
                        "My\nJourney",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsSection(Color? textColor) {
    final List<Map<String, String>> newsItems = [
      {
        'title':
            'New App Onboard X: Cleaner, easier to use, and faster to navigate.',
        'image': 'assets/images/background_news.jpeg',
        'url': 'https://asean.bernama.com/news.php?id=2468953',
      },
      {
        'title': 'Latest Developments in Technology Sector',
        'image': 'assets/images/background_news.jpeg',
        'url': 'https://theedgemalaysia.com/node/770755',
      },
      {
        'title': 'Market Trends and Financial Updates',
        'image': 'assets/images/background_news.jpeg',
        'url': 'https://finance.yahoo.com/quote/5347.KL/news/',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "News",
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: newsItems.length,
            itemBuilder: (context, index) {
              final news = newsItems[index];
              return GestureDetector(
                onTap: () => _launchURL(news['url']!),
                child: Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/background_news.jpeg'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black54,
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(
                        colors: [Colors.black87, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          news['title']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}