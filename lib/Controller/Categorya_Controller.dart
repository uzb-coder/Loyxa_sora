import 'dart:convert';

import 'package:http/http.dart' as http;

class CategoryaController{

  final String baseUrl = "https://sora-b.vercel.app/api";
  final String token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2ODhhYmQxZjVhN2VjODNlNjM1NTAxNzciLCJyb2xlIjoiYWZpdHNhbnQiLCJpYXQiOjE3NTQwMzIwMzMsImV4cCI6MTc1NDYzNjgzM30.T6JGpOvgTQ08yzKYEYd-5wYPpYWV7SQzb2PE4wEQIVw";


  Future<List<dynamic>> fetchCategories() async {
    final url = Uri.parse("$baseUrl/categories/list");

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print(response.body);
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded["categories"]; // Agar backend "categories" ichida yuborayotgan bo‘lsa
    } else {
      throw Exception("Kategoriya olishda xatolik: ${response.statusCode}");
    }
  }
}