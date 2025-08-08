import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Model/Ovqat_model.dart';

class OvqatController {
  static const String baseUrl = "https://sorab.richman.uz/api";

  Future<List<Ovqat>> fetchProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // 🧠 tokenni olish

    if (token == null) {
      throw Exception("Token topilmadi! Iltimos, qayta login qiling.");
    }
    // Avval foods endpoint ni sinab ko'ramiz
    final url = Uri.parse("$baseUrl/foods/list");

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print("✅ Mahsulotlar API javobi: ${response.body}");

    if (response.statusCode == 200) {
      final dynamic decoded = json.decode(response.body);
      print("🔍 Mahsulotlar decoded turi: ${decoded.runtimeType}");

      // API javobi Map bo'lsa, data kalitini olish
      if (decoded is Map<String, dynamic>) {
        final data =
            decoded['foods'] ??
            decoded['data'] ??
            decoded['products'] ??
            decoded;
        if (data is List) {
          return data.map((e) => Ovqat.fromJson(e)).toList();
        } else {
          throw Exception("API javobida mahsulotlar ro'yxati topilmadi");
        }
      } else if (decoded is List) {
        return decoded.map((e) => Ovqat.fromJson(e)).toList();
      } else {
        throw Exception("API javobi noto'g'ri formatda");
      }
    } else {
      throw Exception("Mahsulotlar olishda xatolik: ${response.statusCode}");
    }
  }

  Future<List<Ovqat>> fetchProductsByCategory(String categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // 🧠 tokenni olish

    if (token == null) {
      throw Exception("Token topilmadi! Iltimos, qayta login qiling.");
    }
    final url = Uri.parse("$baseUrl/foods/list?category=$categoryId");

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print("✅ Kategoriya bo'yicha mahsulotlar: ${response.body}");

    if (response.statusCode == 200) {
      final dynamic decoded = json.decode(response.body);
      print("🔍 Kategoriya mahsulotlari decoded turi: ${decoded.runtimeType}");

      // API javobi Map bo'lsa, data kalitini olish
      if (decoded is Map<String, dynamic>) {
        final data =
            decoded['foods'] ??
            decoded['data'] ??
            decoded['products'] ??
            decoded;
        if (data is List) {
          return data.map((e) => Ovqat.fromJson(e)).toList();
        } else {
          throw Exception("API javobida mahsulotlar ro'yxati topilmadi");
        }
      } else if (decoded is List) {
        return decoded.map((e) => Ovqat.fromJson(e)).toList();
      } else {
        throw Exception("API javobi noto'g'ri formatda");
      }
    } else {
      throw Exception(
        "Kategoriya bo'yicha mahsulotlar olishda xatolik: ${response.statusCode}",
      );
    }
  }
}
