import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String id;
  final String firstName;
  final String lastName;
  final String role;
  final String userCode;
  final bool isActive;
  final List<String> permissions;
  final int percent;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.userCode,
    required this.isActive,
    required this.permissions,
    required this.percent,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      role: json['role'] ?? '',
      userCode: json['user_code'] ?? '',
      isActive: json['is_active'] ?? false,
      permissions: List<String>.from(json['permissions'] ?? []),
      percent: json['percent'] ?? 0,
    );
  }
}



class AuthService {
  static const String baseUrl = "https://sora-b.vercel.app/api";
  static const String userCode = "123";
  static const String password = "1";

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


class UserController {
 static  final String baseUrl = "https://sora-b.vercel.app/api";

 static Future<List<User>> getAllUsers() async {

   final String? token = await AuthService.getToken(); // Tokenni shu yerda olamiz

   final response = await http.get(
     Uri.parse('$baseUrl/users'),
     headers: {
       'Authorization': 'Bearer $token',
       'Content-Type': 'application/json',
     },
   );

   if (response.statusCode == 200) {
     print(response.body);
     final List<dynamic> jsonList = json.decode(response.body);
     return jsonList.map((json) => User.fromJson(json)).toList();
   } else {
     throw Exception('Foydalanuvchilarni yuklashda xatolik: ${response.statusCode}');
   }
 }

}
