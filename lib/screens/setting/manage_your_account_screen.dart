//manage_your_account_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

// services (replace SupabaseService with these)
import 'package:onboardx_app/services/user_service.dart';
import 'package:onboardx_app/services/team_service.dart';
import 'package:onboardx_app/services/auth_service.dart';

class ManageAccountScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ManageAccountScreen({super.key, required this.user});

  @override
  State<ManageAccountScreen> createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends State<ManageAccountScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController usernameCtrl;

  File? _pickedImage;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _editing = false;
  bool _loading = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // new services
  final UserService _userService = UserService();
  final TeamService _teamService = TeamService();
  final AuthService _authService = AuthService();

  Map<String, dynamic> _userData = {};

  // Supported image formats (client-side guard)
  static const List<String> _supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif'
  ];

  Color? get appBarIconColor => Theme.of(context).iconTheme.color;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    phoneCtrl = TextEditingController();
    usernameCtrl = TextEditingController();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final firebaseUser = _auth.currentUser;
      final uid = widget.user['uid'] ?? firebaseUser?.uid;
      Map<String, dynamic>? profile;

      if (uid != null) {
        profile = await _userService.getUserProfile(uid);
      }

      // Debug
      print('ManageAccount: profile from backend => $profile');

      if (profile != null) {
        // Build local map with consistent keys used by the UI
        final Map<String, dynamic> local = {
          'fullName': profile['full_name'] ?? '',
          'username': profile['username'] ?? '',
          'email': profile['email'] ?? firebaseUser?.email ?? '',
          'phoneNumber': profile['phone_number'] ?? '',
          'workType': profile['work_type'] ?? '',
          'workTeam': '',
          'workPlace': profile['work_place'] ?? '',
          'profileImageUrl': profile['profileImageUrl'] ?? profile['profile_image'] ?? '',
          'created_at': profile['created_at']?.toString(),
          'team_no': profile['team_no'],
          // keep original profile object for troubleshooting
          '_raw_profile': profile,
        };

        // If team attached by backend as `team` object, use it
        try {
          if (profile['team'] != null && profile['team'] is Map) {
            local['workTeam'] = profile['team']['work_team'] ?? '';
            local['workPlace'] = profile['team']['work_place'] ?? local['workPlace'];
          } else if (profile['team_no'] != null) {
            final teamData = await _getTeamSafely(profile['team_no']);
            if (teamData != null) {
              local['workTeam'] = teamData['work_team'] ?? '';
              local['workPlace'] = teamData['work_place'] ?? local['workPlace'];
            }
          } else {
            local['workTeam'] = profile['work_team'] ?? profile['work_unit'] ?? '';
          }
        } catch (e) {
          print('ManageAccount: failed to load team info: $e');
        }

        setState(() {
          _userData = local;
          nameCtrl.text = _userData['fullName'] ?? '';
          phoneCtrl.text = _userData['phoneNumber'] ?? '';
          usernameCtrl.text = _userData['username'] ?? '';
          _loading = false;
        });
      } else {
        // Fallback to widget.user
        setState(() {
          _userData = {
            'fullName': widget.user['fullName'] ?? widget.user['full_name'] ?? '',
            'username': widget.user['username'] ?? widget.user['username'] ?? '',
            'email': widget.user['email'] ?? '',
            'phoneNumber': widget.user['phoneNumber'] ?? widget.user['phone_number'] ?? '',
            'workType': widget.user['workType'] ?? widget.user['work_type'] ?? '',
            'workTeam': widget.user['workUnit'] ?? widget.user['work_team'] ?? '',
            'workPlace': widget.user['workplace'] ?? widget.user['work_place'] ?? '',
            'profileImageUrl': widget.user['profileImageUrl'] ?? '',
            'created_at': widget.user['created_at']?.toString(),
          };

          nameCtrl.text = _userData['fullName'] ?? '';
          phoneCtrl.text = _userData['phoneNumber'] ?? '';
          usernameCtrl.text = _userData['username'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _userData = {
          'fullName': widget.user['fullName'] ?? widget.user['full_name'] ?? '',
          'username': widget.user['username'] ?? widget.user['username'] ?? '',
          'email': widget.user['email'] ?? '',
          'phoneNumber': widget.user['phoneNumber'] ?? widget.user['phone_number'] ?? '',
          'workType': widget.user['workType'] ?? widget.user['work_type'] ?? '',
          'workTeam': widget.user['workUnit'] ?? widget.user['work_team'] ?? '',
          'workPlace': widget.user['workplace'] ?? widget.user['work_place'] ?? '',
          'profileImageUrl': widget.user['profileImageUrl'] ?? '',
          'created_at': widget.user['created_at']?.toString(),
        };

        nameCtrl.text = _userData['fullName'] ?? '';
        phoneCtrl.text = _userData['phoneNumber'] ?? '';
        usernameCtrl.text = _userData['username'] ?? '';
        _loading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _getTeamSafely(dynamic teamId) async {
    try {
      if (teamId == null) return null;
      return await _teamService.getTeamByNoTeam(teamId.toString());
    } catch (e) {
      print('getTeamSafely error: $e');
      return null;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (!_editing) return;

    final picker = ImagePicker();
    try {
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (file != null) {
        final imageFile = File(file.path);
        final fileSize = await imageFile.length();
        const maxSize = 10 * 1024 * 1024; // 10MB

        // Check file size
        if (fileSize > maxSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image too large. Maximum size is 10MB'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // Check file extension
        final fileExtension = file.path.split('.').last.toLowerCase();
        if (!_supportedImageFormats.contains(fileExtension)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Unsupported format. Supported: ${_supportedImageFormats.join(', ')}',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        setState(() => _pickedImage = imageFile);
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateTimeString);
      final format = DateFormat('dd MMMM yyyy \'at\' HH:mm:ss');
      return format.format(date);
    } catch (e) {
      return 'Unknown date';
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      String? uploadedPath; // path returned by upload endpoint

      // 1) If there's a picked image, upload it to backend documents endpoint
      if (_pickedImage != null) {
        // Prepare multipart request
        final backendBase = _userService.backendBaseUrl; // using userService backendBaseUrl
        final uri = Uri.parse('$backendBase/documents/upload');
        final request = http.MultipartRequest('POST', uri);

        // Attach file
        final fileName = _pickedImage!.path.split('/').last;
        final multipartFile =
            await http.MultipartFile.fromPath('file', _pickedImage!.path, filename: fileName);
        request.files.add(multipartFile);

        // Add fields if backend expects them
        request.fields['created_by'] = user.uid;
        // you may add folder_id if needed: request.fields['folder_id'] = '...';

        // Optionally include auth header (server may not require it for uploads but it's safe)
        final idToken = await user.getIdToken();
        request.headers['Authorization'] = 'Bearer $idToken';

        final streamedResp = await request.send();
        final resp = await http.Response.fromStream(streamedResp);

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final respJson = jsonDecode(resp.body);
          // depending on your backend, you might get the saved document object
          // attempt common keys: 'path', 'file_path', 'name', 'id'
          uploadedPath = respJson['path'] ?? respJson['file_path'] ?? respJson['name'] ?? respJson['fileName'] ?? respJson['id']?.toString();
          print('Image uploaded, server returned: $respJson');
        } else {
          print('Upload failed: ${resp.statusCode} ${resp.body}');
          throw Exception('Failed to upload image. (${resp.statusCode})');
        }
      }

      // 2) Prepare profile payload
      final profileData = <String, dynamic>{
        'full_name': nameCtrl.text.trim(),
        'username': usernameCtrl.text.trim(),
        'phone_number': phoneCtrl.text.trim(),
      };

      if (uploadedPath != null) {
        // backend expects profile_image to be stored so server can build public URL
        profileData['profile_image'] = uploadedPath;
      }

      // 3) Call backend via AuthService.syncUserProfile (will call /api/users/sync with idToken)
      final success = await _authService.syncUserProfile(user, profileData);

      if (!success) {
        throw Exception('Failed to sync profile to server');
      }

      // 4) Refresh profile from backend
      await _fetchUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _editing = false;
          _pickedImage = null;
        });
      }
    } on Exception catch (e) {
      String errorMessage = 'Error updating profile';

      final es = e.toString();
      if (es.contains('Unsupported image format')) {
        errorMessage = 'Unsupported image format. Please use JPG, PNG, GIF, WebP, BMP, HEIC, or HEIF.';
      } else if (es.contains('File too large')) {
        errorMessage = 'Image too large. Maximum size is 10MB.';
      } else if (es.contains('Username already taken')) {
        errorMessage = 'Username already taken. Please choose another one.';
      } else {
        errorMessage = 'Error updating profile: ${es.replaceAll('Exception: ', '')}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String title, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.isNotEmpty ? value : 'Not set',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = isDarkMode
        ? const Color.fromRGBO(180, 100, 100, 1)
        : const Color.fromRGBO(224, 124, 124, 1);
    final cardColor = theme.cardColor;

    final String? createdAtString = _userData['created_at']?.toString();

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Your Account'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: appBarIconColor,
        automaticallyImplyLeading: false,
        leading: Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor,
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
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() => _editing = true);
              },
              tooltip: 'Edit Profile',
            ),
          if (_editing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _editing = false;
                  // Reset changes
                  nameCtrl.text = _userData['fullName'] ?? '';
                  phoneCtrl.text = _userData['phoneNumber'] ?? '';
                  usernameCtrl.text = _userData['username'] ?? '';
                  _pickedImage = null;
                });
              },
              tooltip: 'Cancel Editing',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Profile Image Section
            Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      // Profile Image with different states
                      if (_pickedImage != null)
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: FileImage(_pickedImage!),
                        )
                      else if (_userData['profileImageUrl'] != null && _userData['profileImageUrl'].toString().isNotEmpty)
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: NetworkImage(_userData['profileImageUrl'].toString()),
                          onBackgroundImageError: (exception, stackTrace) {
                            print("Error loading profile image: $exception");
                          },
                        )
                      else
                        const CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, size: 40, color: Colors.grey),
                        ),

                      // Camera icon for editing
                      if (_editing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _editing ? 'Tap avatar to change photo' : '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildSectionHeader('Account Information'),

                  // Username Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _editing
                        ? TextFormField(
                            controller: usernameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              hintText: 'Enter your username',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: cardColor,
                              prefixIcon: Icon(Icons.person, color: primaryColor),
                            ),
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? 'Username is required' : null,
                          )
                        : _buildReadOnlyField('Username', _userData['username'] ?? ''),
                  ),
                  const SizedBox(height: 16),

                  // Full Name Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _editing
                        ? TextFormField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              hintText: 'Enter your full name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: cardColor,
                              prefixIcon: Icon(Icons.badge, color: primaryColor),
                            ),
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? 'Full name is required' : null,
                          )
                        : _buildReadOnlyField('Full Name', _userData['fullName'] ?? ''),
                  ),
                  const SizedBox(height: 16),

                  // Email Field (always read-only)
                  _buildReadOnlyField('Email', _userData['email'] ?? ''),
                  const SizedBox(height: 16),

                  // Phone Number Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _editing
                        ? TextFormField(
                            controller: phoneCtrl,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: 'Enter your phone number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: cardColor,
                              prefixIcon: Icon(Icons.phone, color: primaryColor),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (v) => (v != null && v.length >= 9)
                                ? null
                                : 'Please enter a valid phone number',
                          )
                        : _buildReadOnlyField('Phone Number', _userData['phoneNumber'] ?? ''),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Work Information'),
                  _buildReadOnlyField('Work Type', _userData['workType'] ?? ''),
                  _buildReadOnlyField('Work Team', _userData['workTeam'] ?? ''),
                  _buildReadOnlyField('Workplace', _userData['workPlace'] ?? ''),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Account Metadata'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: primaryColor),
                        const SizedBox(width: 16),
                        const Text('Created at'),
                        const Spacer(),
                        Text(
                          createdAtString != null
                              ? _formatDateTime(createdAtString)
                              : 'Unknown',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Save Button (only when editing)
                  if (_editing) ...[
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}