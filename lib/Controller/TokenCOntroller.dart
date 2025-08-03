import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class AuthService {
  static const String baseUrl = "https://sora-b.vercel.app/api";
  static const String userCode = "9090034564";
  static const String password = "0000";

  // Tokenni local storage (SharedPreferences) ga saqlash
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    print("✅ Token localda saqlandi");
  }

  // Local storage dan tokenni olish
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Login qilish va token olish
  static Future<void> loginAndPrintToken() async {
    final Uri loginUrl = Uri.parse('$baseUrl/auth/login');

    print("Yuborilayotgan ma'lumot: user_code=$userCode, password=$password");

    try {
      final response = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_code': userCode,
          'password': password,
        }),
      );

      print("📥 Status Code: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String token = data['token'];
        await saveToken(token);
        print("✅ Token muvaffaqiyatli olindi: $token");
      } else {
        print("❌ Login xatolik. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      print("❗ Xatolik yuz berdi: $e");
    }
  }
}
