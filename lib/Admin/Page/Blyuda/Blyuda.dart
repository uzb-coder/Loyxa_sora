import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class Food {
  final String id;
  final String name;
  final num price; // int -> num
  final String warehouse;
  final String unit;
  final num soni;  // int -> num
  final String subcategory;
  final String categoryTitle;
  final String createdAt;

  Food({
    required this.id,
    required this.name,
    required this.price,
    required this.warehouse,
    required this.unit,
    required this.soni,
    required this.subcategory,
    required this.categoryTitle,
    required this.createdAt,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: _parseNum(json['price']),         // 👈 shu yer o‘zgardi
      warehouse: json['warehouse']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      soni: _parseNum(json['soni']),           // 👈 shu yer o‘zgardi
      subcategory: (json['subcategory']?.toString().isNotEmpty ?? false)
          ? json['subcategory'].toString()
          : '---',
      categoryTitle: json['category']?['title']?.toString() ?? '---',
      createdAt: _formatDate(json['createdAt']),
    );
  }

  static num _parseNum(dynamic value) {
    try {
      if (value == null) return 0;
      if (value is num) return value;
      if (value is String) return num.tryParse(value) ?? 0;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static String _formatDate(dynamic date) {
    try {
      if (date == null) return '---';
      final parsed = DateTime.tryParse(date.toString());
      return parsed != null
          ? DateFormat('dd.MM.yyyy').format(parsed)
          : '---';
    } catch (_) {
      return '---';
    }
  }
}

class Category {
  final String id;
  final String title;

  Category({required this.id, required this.title});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
    );
  }
}

class Department {
  final String id;
  final String title;
  final String warehouse;

  Department({
    required this.id,
    required this.title,
    required this.warehouse,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      warehouse: json['warehouse']?.toString() ?? '',
    );
  }
}

class FoodsTablePage extends StatefulWidget {
  final String token;
  const FoodsTablePage({super.key, required this.token});

  @override
  State<FoodsTablePage> createState() => _FoodsTablePageState();
}

class _FoodsTablePageState extends State<FoodsTablePage> {
  late Future<List<Food>> _futureFoods;
  late Future<List<Category>> _futureCategories;
  late Future<List<Department>> _futureDepartments;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _futureFoods = fetchFoods(widget.token);
    _futureCategories = fetchCategories(widget.token);
    _futureDepartments = fetchDepartments(widget.token);
  }

  Future<void> _showCreateFoodDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final quantityController = TextEditingController();
    final dateController = TextEditingController();
    String? selectedUnit;
    Category? selectedCategory;
    Department? selectedDepartment;

    final units = ['dona', 'kg', 'litr', 'sm', 'gramm', 'metr'];

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder(
          future: Future.wait([_futureCategories, _futureDepartments]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || snapshot.data == null) {
              return AlertDialog(
                title: const Text('Xatolik'),
                content: Text('Ma\'lumotlarni yuklashda xatolik: ${snapshot.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              );
            }

            final categories = snapshot.data![0] as List<Category>;
            final departments = snapshot.data![1] as List<Department>;

            return AlertDialog(
              title: const Text('Yangi mahsulot qo‘shish'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nomi'),
                    ),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Narxi'),
                    ),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Soni'),
                    ),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Birlik'),
                      items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => selectedUnit = v,
                    ),
                    TextField(
                      controller: dateController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Yaroqlilik muddati'),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                        }
                      },
                    ),
                    DropdownButtonFormField<Category>(
                      decoration: const InputDecoration(labelText: 'Kategoriya'),
                      items: categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c.title)))
                          .toList(),
                      onChanged: (val) => setState(() => selectedCategory = val),
                    ),
                    DropdownButtonFormField<Department>(
                      decoration: const InputDecoration(labelText: 'Bo‘lim'),
                      items: departments
                          .where((d) => selectedCategory == null || true)
                          .map((d) => DropdownMenuItem(value: d, child: Text(d.title)))
                          .toList(),
                      onChanged: (val) => selectedDepartment = val,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Bekor qilish'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final price = int.tryParse(priceController.text) ?? 0;
                      final soni = int.tryParse(quantityController.text) ?? 0;
                      if (nameController.text.isEmpty || price <= 0 || soni <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Barcha maydonlarni to‘g‘ri to‘ldiring!')),
                        );
                        return;
                      }

                      await createFood(
                        widget.token,
                        nameController.text,
                        price,
                        selectedCategory?.id ?? '',
                        '', // subcategory
                        selectedDepartment?.id ?? '',
                        selectedDepartment?.warehouse ?? '',
                        selectedUnit ?? '',
                        soni,
                        dateController.text,
                      );

                      Navigator.pop(context);
                      setState(() {
                        _loadData();
                      });
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
                    }
                  },
                  child: const Text('Qo‘shish'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mahsulotlar ro'yxati"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateFoodDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<Food>>(
        future: _futureFoods,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Ma'lumotlar topilmadi"));
          }

          final foods = snapshot.data!;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey[300]),
                columns: const [
                  DataColumn(label: Text("Nomi")),
                  DataColumn(label: Text("Narxi")),
                  DataColumn(label: Text("Birlik")),
                  DataColumn(label: Text("Soni")),
                  DataColumn(label: Text("Sklad")),
                  DataColumn(label: Text("Kategoriya")),
                  DataColumn(label: Text("Subkategoriya")),
                  DataColumn(label: Text("Mudati")),
                ],
                rows: foods.map((f) {
                  return DataRow(cells: [
                    DataCell(Text(f.name)),
                    DataCell(Text(f.price.toString())),
                    DataCell(Text(f.unit)),
                    DataCell(Text(f.soni.toString())),
                    DataCell(Text(f.warehouse)),
                    DataCell(Text(f.categoryTitle)),
                    DataCell(Text(f.subcategory)),
                    DataCell(Text(f.createdAt)),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<List<Food>> fetchFoods(String token) async {
    final res = await http.get(
      Uri.parse('https://sora-b.vercel.app/api/foods/list'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['foods'] as List).map((f) => Food.fromJson(f)).toList();
    } else {
      throw Exception("Mahsulotlarni yuklashda xatolik");
    }
  }

  Future<List<Category>> fetchCategories(String token) async {
    final res = await http.get(
      Uri.parse('https://sora-b.vercel.app/api/categories/list'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['categories'] as List).map((c) => Category.fromJson(c)).toList();
    } else {
      throw Exception("Kategoriyalarni yuklashda xatolik");
    }
  }

  Future<List<Department>> fetchDepartments(String token) async {
    final res = await http.get(
      Uri.parse('https://sora-b.vercel.app/api/departments/list'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['departments'] as List).map((d) => Department.fromJson(d)).toList();
    } else {
      throw Exception("Bo‘limlarni yuklashda xatolik");
    }
  }
  Future<void> createFood(
      String token,
      String name,
      int price,
      String categoryId,
      String subcategory,
      String departmentId,
      String warehouse,
      String unit,
      int soni,
      String expiration,
      ) async {
    final response = await http.post(
      Uri.parse('https://sora-b.vercel.app/api/foods/create'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'food': {
          'name': name,
          'price': price,
          'category': categoryId,
          'subcategory': subcategory,
          'department_id': departmentId,
          'warehouse': warehouse,
          'unit': unit,
          'soni': soni,
          'expiration': expiration,
        },
      }),
    );

    if (response.statusCode != 201) {
      throw Exception("Mahsulot qo‘shishda xatolik: ${response.statusCode}");
    }
  }

}
