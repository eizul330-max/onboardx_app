//team_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class TeamService {
  final String backendBaseUrl = "http://10.111.132.36:4000/api";

  Future<Map<String, dynamic>?> getTeamByNoTeam(String noTeam) async {
    try {
      final resp = await http.get(Uri.parse('$backendBaseUrl/teams/$noTeam'));
      if (resp.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(resp.body));
      } else {
        print('TeamService.getTeamByNoTeam status ${resp.statusCode}');
        return null;
      }
    } catch (e) {
      print('TeamService.getTeamByNoTeam error: $e');
      return null;
    }
  }
}