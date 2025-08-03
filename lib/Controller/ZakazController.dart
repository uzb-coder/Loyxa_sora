import 'dart:convert';
import 'package:http/http.dart' as http;

class Zakazcontroller {
  final String baseUrl = "https://sora-b.vercel.app/api";
  final String token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2ODhhYmQxZjVhN2VjODNlNjM1NTAxNzciLCJyb2xlIjoiYWZpdHNhbnQiLCJpYXQiOjE3NTQwMzIwMzMsImV4cCI6MTc1NDYzNjgzM30.T6JGpOvgTQ08yzKYEYd-5wYPpYWV7SQzb2PE4wEQIVw";

  Future<bool> closeOrder(String orderId) async {
    final url = Uri.parse('$baseUrl/orders/close/$orderId');

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return true;
      } else {
        throw Exception(data['message']);
      }
    } else {
      throw Exception('Xatolik: ${response.statusCode} ${response.body}');
    }
  }





}
