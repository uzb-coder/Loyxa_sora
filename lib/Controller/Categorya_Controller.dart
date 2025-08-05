import 'dart:convert';

import 'package:http/http.dart' as http;

import '../Model/Categorya_Model.dart';

class CategoryaController {
  static const String baseUrl = "https://sorab.richman.uz/api";
  final String token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2ODhhYmQxZjVhN2VjODNlNjM1NTAxNzciLCJyb2xlIjoiYWZpdHNhbnQiLCJpYXQiOjE3NTQwMzIwMzMsImV4cCI6MTc1NDYzNjgzM30.T6JGpOvgTQ08yzKYEYd-5wYPpYWV7SQzb2PE4wEQIVw";

  Future<List<Category>> fetchCategories() async {
    final url = Uri.parse("$baseUrl/categories/list");

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print("✅ Kategoriyalar API javobi: ${response.body}");

    if (response.statusCode == 200) {
      final dynamic decoded = json.decode(response.body);
      print("🔍 decoded turi: ${decoded.runtimeType}");

      // API javobi Map bo'lsa, data kalitini olish
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
