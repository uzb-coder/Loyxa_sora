import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Model/StolModel.dart';


class StolController{

  static const String baseUrl = "https://sorab.richman.uz/api";

  Future<List<StolModel>> fetchTables() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // 🧠 tokenni olish

    if (token == null) {
      throw Exception("Token topilmadi! Iltimos, qayta login qiling.");
    }
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
