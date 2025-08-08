import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // tokenni olish uchun

import '../Model/Categorya_Model.dart';

class CategoryaController {
  static const String baseUrl = "https://sorab.richman.uz/api";

  Future<List<Category>> fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // 🧠 tokenni olish

    if (token == null) {
      throw Exception("Token topilmadi! Iltimos, qayta login qiling.");
    }

    final url = Uri.parse("$baseUrl/categories/list");

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // ✅ token ishlatildi
      },
    );

    print("✅ Kategoriyalar API javobi: ${response.body}");

    if (response.statusCode == 200) {
      final dynamic decoded = json.decode(response.body);
      print("🔍 decoded turi: ${decoded.runtimeType}");

      if (decoded is Map<String, dynamic>) {
        final data = decoded['categories'] ?? decoded['data'] ?? decoded;
        if (data is List) {
          return data.map((e) => Category.fromJson(e)).toList();
        } else {
          throw Exception("API javobida kategoriyalar ro'yxati topilmadi");
        }
      } else if (decoded is List) {
        return decoded.map((e) => Category.fromJson(e)).toList();
      } else {
        throw Exception("API javobi noto'g'ri formatda");
      }
    } else {
      throw Exception("Kategoriya olishda xatolik: ${response.statusCode}");
    }
  }
}
