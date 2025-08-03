import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'Controller/usersCOntroller.dart';

class Salom extends StatefulWidget {
  final User user;
  final String token;

  const Salom({super.key, required this.user, required this.token});

  @override
  State<Salom> createState() => _PosScreenState();
}

class _PosScreenState extends State<Salom> {
  String? responseData;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    final url = Uri.parse('https://sora-b.vercel.app/api/orders');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}', // Tokenni yuboramiz
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        responseData = response.body;
      });
    } else {
      setState(() {
        responseData = 'Xatolik: ${response.statusCode} - ${response.body}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS Screen')),
      body: Center(
        child: responseData == null
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            responseData!,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }
}
