//auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb;

class AuthService {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final String backendBaseUrl = "http://10.111.132.36:4000/api"; // ubah ikut environment

  Future<fb.User?> signInWithEmail(String email, String password) async {
    try {
      fb.UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Optionally sync default profile (minimal). Full profile sync done by syncUserProfile
      await _syncMinimal(userCredential.user!);

      return userCredential.user;
    } catch (e) {
      print("Error signing in: $e");
      return null;
    }
  }

  Future<fb.User?> registerWithEmail(String email, String password) async {
    try {
      fb.UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Error registering: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // Keep internal minimal sync if needed
  Future<void> _syncMinimal(fb.User firebaseUser) async {
    try {
      final idToken = await firebaseUser.getIdToken();
      final userData = {
        "uid": firebaseUser.uid,
        "email": firebaseUser.email,
        "displayName": firebaseUser.displayName,
        "photoURL": firebaseUser.photoURL,
      };
      await http.post(
        Uri.parse("$backendBaseUrl/users/sync"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode(userData),
      );
    } catch (e) {
      print("Error minimal syncing user: $e");
    }
  }

  // New: sync full profile from registration screen
  Future<bool> syncUserProfile(fb.User firebaseUser, Map<String, dynamic> profileData) async {
    try {
      final idToken = await firebaseUser.getIdToken();
      final payload = {
        "uid": firebaseUser.uid,
        "email": firebaseUser.email,
        "displayName": firebaseUser.displayName,
        "photoURL": firebaseUser.photoURL,
        // include extra profile fields
        ...profileData,
      };

      final resp = await http.post(
        Uri.parse("$backendBaseUrl/users/sync"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode(payload),
      );

      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      print("Error syncing profile: $e");
      return false;
    }
  }
}