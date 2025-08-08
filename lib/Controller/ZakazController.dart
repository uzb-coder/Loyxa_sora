import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Zakazcontroller {
  static const String baseUrl = "https://sorab.richman.uz/api";



  Future<bool> closeOrder(String orderId) async {
    const String apiUrl = "https://sora-b.vercel.app/api/orders/close/";
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // 🧠 tokenni olish

    if (token == null) {
      throw Exception("Token topilmadi! Iltimos, qayta login qiling.");
    }
    try {
      final response = await http.put(
        Uri.parse("$apiUrl$orderId"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      print(" ✅ Close order API response: Status=${response.statusCode},  ✅ Body=${response.body}");
      if (response.statusCode == 200) {
        return true;
      } else {
        print("Close order failed: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("Close order error: $e");
      return false;
    }
  }



}
