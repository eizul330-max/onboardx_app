//user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class UserService {
  final String backendBaseUrl = "http://10.111.132.36:4000/api"; // emulator: 10.0.2.2, real device: http://<host-ip>:4000

  // Fetch profile + team via backend endpoint /api/users/profile/:uid
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final resp = await http.get(Uri.parse('$backendBaseUrl/users/profile/$uid'));
      if (resp.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(resp.body));
      } else {
        print('UserService.getUserProfile status ${resp.statusCode}: ${resp.body}');
        return null;
      }
    } catch (e) {
      print('UserService.getUserProfile error: $e');
      return null;
    }
  }
}