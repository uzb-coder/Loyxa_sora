import 'dart:convert';
import 'package:http/http.dart' as http;

import '../Model/StolModel.dart';


class StolController{

  static const String baseUrl = "https://sorab.richman.uz/api";
  final String token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2ODhhYmQxZjVhN2VjODNlNjM1NTAxNzciLCJyb2xlIjoiYWZpdHNhbnQiLCJpYXQiOjE3NTQwMzIwMzMsImV4cCI6MTc1NDYzNjgzM30.T6JGpOvgTQ08yzKYEYd-5wYPpYWV7SQzb2PE4wEQIVw";

  Future<List<StolModel>> fetchTables() async {
    final url = Uri.parse("$baseUrl/tables/list");

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      print("✅ ${response.body}");
      final List<dynamic> tablesJson = json.decode(response.body);
      return tablesJson.map((json) => StolModel.fromJson(json)).toList();
    } else {
      throw Exception("Xatolik: ${response.statusCode}");
    }
  }

}
