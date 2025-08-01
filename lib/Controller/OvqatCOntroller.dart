import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodService {

  final String baseUrl = "https://sora-b.vercel.app/api";
  final String token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2ODhhYmQxZjVhN2VjODNlNjM1NTAxNzciLCJyb2xlIjoiYWZpdHNhbnQiLCJpYXQiOjE3NTQwMzIwMzMsImV4cCI6MTc1NDYzNjgzM30.T6JGpOvgTQ08yzKYEYd-5wYPpYWV7SQzb2PE4wEQIVw";

  Future<List<dynamic>> getFoods() async {
    final url = Uri.parse("$baseUrl/foods/list");

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      print(response.body);
      return json.decode(response.body); // List of maps
    } else {
      throw Exception("Ovqatlar yuklab bo‘lmadi: ${response.statusCode}");
    }
  }
}
