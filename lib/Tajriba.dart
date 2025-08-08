import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Food {
  final String id;
  final String name;
  final int price;
  final String warehouse;
  final String unit;
  final int soni;

  Food({
    required this.id,
    required this.name,
    required this.price,
    required this.warehouse,
    required this.unit,
    required this.soni,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      price: json['price'] ?? 0,
      warehouse: json['warehouse']?['name'] ?? '',
      unit: json['unit'] ?? '',
      soni: json['soni'] ?? 0,
    );
  }
}

class ProductsPage extends StatefulWidget {
  final String token;

  const ProductsPage({super.key, required this.token});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Food> _foods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFoods();
  }

  Future<void> _fetchFoods() async {
    final response = await http.get(
      Uri.parse("https://sora-b.vercel.app/api/foods"),
      headers: {"x-access-token": widget.token},
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      setState(() {
        _foods = jsonData.map((json) => Food.fromJson(json)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      debugPrint("Xatolik: ${response.statusCode} - ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Kulrang fon
      appBar: AppBar(
        title: const Text("Mahsulotlar"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _foods.isEmpty
          ? const Center(child: Text("Ma'lumot topilmadi"))
          : Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
              MaterialStateColor.resolveWith((states) => Colors.grey[200]!),
              dataRowColor: MaterialStateColor.resolveWith((states) => Colors.white),
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('Nomi')),
                DataColumn(label: Text('Narxi')),
                DataColumn(label: Text('Ombor')),
                DataColumn(label: Text('Birlik')),
                DataColumn(label: Text('Soni')),
              ],
              rows: _foods.map((food) {
                return DataRow(
                  cells: [
                    DataCell(Text(food.name)),
                    DataCell(Text(food.price.toString())),
                    DataCell(Text(food.warehouse)),
                    DataCell(Text(food.unit)),
                    DataCell(Text(food.soni.toString())),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
