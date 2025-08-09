import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class Food {
  final String id;
  final String name;
  final int price;
  final String warehouse;
  final String unit;
  final int soni;
  final String subcategory;
  final String categoryTitle;
  final String categoryId;
  final String departmentId;
  final String? expiration;

  Food({
    required this.id,
    required this.name,
    required this.price,
    required this.warehouse,
    required this.unit,
    required this.soni,
    required this.subcategory,
    required this.categoryTitle,
    required this.categoryId,
    required this.departmentId,
    this.expiration,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: _parseToInt(json['price']),
      warehouse: json['warehouse']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      soni: _parseToInt(json['soni']),
      subcategory: json['subcategory']?.toString() ?? '',
      categoryTitle: json['category'] is Map
          ? json['category']['title']?.toString() ?? ''
          : json['category']?.toString() ?? '',
      categoryId: json['category'] is Map
          ? json['category']['_id']?.toString() ?? ''
          : json['category']?.toString() ?? '',
      departmentId: json['department_id']?.toString() ?? '',
      expiration: json['expiration']?.toString(),
    );
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) {
        return parsed.toInt();
      }
      return 0;
    }
    return 0;
  }
}

class Category {
  final String id;
  final String title;
  final List<String> subcategories;

  Category({required this.id, required this.title, required this.subcategories});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subcategories: (json['subcategories'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

class Department {
  final String id;
  final String title;
  final String warehouse;

  Department({required this.id, required this.title, required this.warehouse});

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
    await _showFoodDialog(null);
  }

  Future<void> _showEditFoodDialog(Food food) async {
    await _showFoodDialog(food);
  }

  Future<void> _showFoodDialog(Food? food) async {
    final nameController = TextEditingController(text: food?.name ?? '');
    final priceController = TextEditingController(text: food?.price.toString() ?? '');
    final quantityController = TextEditingController(text: food?.soni.toString() ?? '');
    final subcategoryController = TextEditingController(text: food?.subcategory ?? '');
    final dateController = TextEditingController(text: food?.expiration ?? '');

    String? selectedUnit = food?.unit;
    Category? selectedCategory;
    Department? selectedDepartment;
    String? selectedSubcategory = food?.subcategory?.isNotEmpty == true ? food?.subcategory : null;

    // Agar editing bo'lsa, kategoriya va departmentni topish
    if (food != null) {
      try {
        selectedCategory = await _getCategoryById(food.categoryId);
        selectedDepartment = await _getDepartmentById(food.departmentId);
      } catch (e) {
        print('Kategoriya yoki departmentni topishda xato: $e');
      }
    }

    const units = ['dona', 'kg', 'litr', 'sm', 'gramm', 'metr', 'bek'];
    final isEditing = food != null;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return FutureBuilder(
              future: Future.wait([_futureCategories, _futureDepartments]),
              builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AlertDialog(
                    content: SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (snapshot.hasError || snapshot.data == null) {
                  return AlertDialog(
                    title: const Text('Xatolik'),
                    content: Text(
                      'Ma\'lumotlarni yuklashda xatolik: ${snapshot.error ?? 'Noma\'lum xatolik'}',
                    ),
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

                List<String> subcategories = selectedCategory?.subcategories ?? [];

                return AlertDialog(
                  title: Text(
                    isEditing ? 'Mahsulotni tahrirlash' : 'Yangi mahsulot qo\'shish',
                  ),
                  content: SingleChildScrollView(
                    child: SizedBox(
                      width: double.maxFinite,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Taom nomi *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Narxi *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Birligi *',
                              border: OutlineInputBorder(),
                            ),
                            value: selectedUnit,
                            items: units
                                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (v) {
                              setDialogState(() {
                                selectedUnit = v;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Soni (ombordagi) *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: dateController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Yaroqlilik muddati (ixtiyoriy)',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
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
                          const SizedBox(height: 16),
                          DropdownButtonFormField<Category>(
                            decoration: const InputDecoration(
                              labelText: 'Kategoriya *',
                              border: OutlineInputBorder(),
                            ),
                            value: selectedCategory,
                            items: categories
                                .map((c) => DropdownMenuItem(value: c, child: Text(c.title)))
                                .toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedCategory = val;
                                selectedSubcategory = null;
                                subcategoryController.text = '';
                                subcategories = val?.subcategories ?? [];
                              });
                            },
                          ),
                          if (subcategories.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Subkategoriya (ixtiyoriy)',
                                border: OutlineInputBorder(),
                              ),
                              value: selectedSubcategory,
                              items: subcategories
                                  .map((sub) => DropdownMenuItem(value: sub, child: Text(sub)))
                                  .toList(),
                              onChanged: (val) {
                                setDialogState(() {
                                  selectedSubcategory = val;
                                  subcategoryController.text = val ?? '';
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          DropdownButtonFormField<Department>(
                            decoration: const InputDecoration(
                              labelText: 'Bo\'lim (otdel) *',
                              border: OutlineInputBorder(),
                            ),
                            value: selectedDepartment,
                            items: departments
                                .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text('${d.title} (${d.warehouse})'),
                            ))
                                .toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedDepartment = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Bekor qilish'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        // Validatsiya
                        if (nameController.text.trim().isEmpty) {
                          _showErrorSnackBar(context, 'Taom nomini kiriting!');
                          return;
                        }

                        final priceText = priceController.text.trim();
                        if (priceText.isEmpty) {
                          _showErrorSnackBar(context, 'Narxni kiriting!');
                          return;
                        }

                        final price = int.tryParse(priceText);
                        if (price == null || price <= 0) {
                          _showErrorSnackBar(context, 'To\'g\'ri narx kiriting!');
                          return;
                        }

                        if (selectedUnit == null) {
                          _showErrorSnackBar(context, 'Birlikni tanlang!');
                          return;
                        }

                        final quantityText = quantityController.text.trim();
                        if (quantityText.isEmpty) {
                          _showErrorSnackBar(context, 'Sonni kiriting!');
                          return;
                        }

                        final quantity = int.tryParse(quantityText);
                        if (quantity == null || quantity <= 0) {
                          _showErrorSnackBar(context, 'To\'g\'ri sonni kiriting!');
                          return;
                        }

                        if (selectedCategory == null) {
                          _showErrorSnackBar(context, 'Kategoriyani tanlang!');
                          return;
                        }

                        if (selectedDepartment == null) {
                          _showErrorSnackBar(context, 'Bo\'limni tanlang!');
                          return;
                        }

                        try {
                          // Progress dialog ko'rsatish
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => AlertDialog(
                              content: Row(
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(width: 20),
                                  Text(
                                    isEditing ? 'Mahsulot yangilanmoqda...' : 'Mahsulot qo\'shilmoqda...',
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (isEditing) {
                            await updateFood(
                              widget.token,
                              food!.id,
                              nameController.text.trim(),
                              price,
                              selectedCategory!.id,
                              selectedSubcategory ?? '',
                              selectedDepartment!.id,
                              selectedDepartment!.warehouse,
                              selectedUnit!,
                              quantity,
                              dateController.text.isEmpty ? null : dateController.text,
                            );
                          } else {
                            await createFood(
                              widget.token,
                              nameController.text.trim(),
                              price,
                              selectedCategory!.id,
                              selectedSubcategory ?? '',
                              selectedDepartment!.id,
                              selectedDepartment!.warehouse,
                              selectedUnit!,
                              quantity,
                              dateController.text.isEmpty ? null : dateController.text,
                            );
                          }

                          if (!mounted) return;

                          // Progress dialogni yopish
                          Navigator.pop(context);
                          // Form dialogni yopish
                          Navigator.pop(context);

                          // Ma'lumotlarni qayta yuklash
                          setState(() {
                            _loadData();
                          });

                          // Muvaffaqiyat xabari
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEditing
                                    ? 'Mahsulot muvaffaqiyatli yangilandi!'
                                    : 'Mahsulot muvaffaqiyatli qo\'shildi!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          // Progress dialogni yopish
                          Navigator.pop(context);
                          _showErrorSnackBar(context, 'Xatolik: $e');
                        }
                      },
                      child: Text(isEditing ? 'Yangilash' : 'Qo\'shish'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<Category?> _getCategoryById(String id) async {
    try {
      final categories = await _futureCategories;
      return categories.firstWhereOrNull((c) => c.id == id);
    } catch (e) {
      print('Category topishda xato: $e');
      return null;
    }
  }

  Future<Department?> _getDepartmentById(String id) async {
    try {
      final departments = await _futureDepartments;
      return departments.firstWhereOrNull((d) => d.id == id);
    } catch (e) {
      print('Department topishda xato: $e');
      return null;
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('Mahsulotlar'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _loadData();
              });
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Yangilash',
          ),
        ],
      ),
      body: FutureBuilder<List<Food>>(
        future: _futureFoods,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      "Xatolik yuz berdi: ${snapshot.error ?? 'Noma\'lum xatolik'}",
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadData();
                        });
                      },
                      child: const Text('Qayta urinish'),
                    ),
                  ],
                ),
              ),
            );
          }

          final foods = snapshot.data ?? [];

          if (foods.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    "Mahsulotlar topilmadi",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showCreateFoodDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Birinchi mahsulotni qo\'shing'),
                  ),
                ],
              ),
            );
          }

          return Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
                  dataRowMinHeight: 50,
                  dataRowMaxHeight: 60,
                  columnSpacing: 20,
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  columns: const [
                    DataColumn(label: Text("Nomi")),
                    DataColumn(label: Text("Narxi")),
                    DataColumn(label: Text("Birligi")),
                    DataColumn(label: Text("Soni")),
                    DataColumn(label: Text("Yaroqlilik")),
                    DataColumn(label: Text("Kategoriya")),
                    DataColumn(label: Text("Subkategoriya")),
                    DataColumn(label: Text("Amallar")),
                  ],
                  rows: foods.map((f) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              f.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text('${f.price} so\'m')),
                        DataCell(Text(f.unit)),
                        DataCell(Text(f.soni.toString())),
                        DataCell(
                          Text(
                            f.expiration?.isNotEmpty == true
                                ? f.expiration!.substring(0, 10)
                                : '',
                          ),
                        ),
                        DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              f.categoryTitle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              f.subcategory,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showEditFoodDialog(f),
                                tooltip: 'Tahrirlash',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDelete(f),
                                tooltip: 'O\'chirish',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateFoodDialog,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Yangi mahsulot qo\'shish',
      ),
    );
  }

  Future<void> _confirmDelete(Food food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tasdiqlash"),
        content: Text("\"${food.name}\" mahsulotini o'chirmoqchimisiz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Yo'q"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ha", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('O\'chirilmoqda...'),
              ],
            ),
          ),
        );

        await deleteFood(widget.token, food.id);

        if (!mounted) return;
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mahsulot o'chirildi"),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _loadData());
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> deleteFood(String token, String foodId) async {
    final response = await http.delete(
      Uri.parse('https://sora-b.vercel.app/api/foods/delete/$foodId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      final errorBody = response.body.isNotEmpty
          ? jsonDecode(response.body)['message'] ?? response.body
          : 'Noma\'lum xatolik';
      throw Exception('Mahsulotni o\'chirishda xatolik: $errorBody');
    }
  }

  Future<List<Food>> fetchFoods(String token) async {
    final res = await http.get(
      Uri.parse('https://sora-b.vercel.app/api/foods/list'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['foods'] is List) {
        return (data['foods'] as List).map((f) => Food.fromJson(f)).toList();
      }
      return [];
    } else {
      throw Exception("Mahsulotlarni yuklashda xatolik: ${res.statusCode}");
    }
  }

  Future<List<Category>> fetchCategories(String token) async {
    final res = await http.get(
      Uri.parse('https://sora-b.vercel.app/api/categories/list'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['categories'] is List) {
        return (data['categories'] as List)
            .map((c) => Category.fromJson(c))
            .toList();
      }
      return [];
    } else {
      throw Exception("Kategoriyalarni yuklashda xatolik: ${res.statusCode}");
    }
  }

  Future<List<Department>> fetchDepartments(String token) async {
    final res = await http.get(
      Uri.parse('https://sora-b.vercel.app/api/departments/list'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['departments'] is List) {
        return (data['departments'] as List)
            .map((d) => Department.fromJson(d))
            .toList();
      }
      return [];
    } else {
      throw Exception("Bo'limlarni yuklashda xatolik: ${res.statusCode}");
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
      String? expiration,
      ) async {
    final Map<String, dynamic> foodData = {
      'name': name,
      'price': price,
      'category': categoryId,
      'department_id': departmentId,
      'warehouse': warehouse,
      'unit': unit,
      'soni': soni,
      if (subcategory.isNotEmpty) 'subcategory': subcategory,
      if (expiration != null && expiration.isNotEmpty) 'expiration': expiration,
    };

    final response = await http.post(
      Uri.parse('https://sora-b.vercel.app/api/foods/create'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'food': foodData}),
    );

    if (response.statusCode != 201) {
      final errorMessage = response.body.isNotEmpty
          ? jsonDecode(response.body)['message'] ?? 'Noma\'lum xatolik'
          : 'Noma\'lum xatolik';
      throw Exception("Mahsulot qo'shishda xatolik: $errorMessage");
    }
  }

  Future<void> updateFood(
      String token,
      String foodId,
      String name,
      int price,
      String categoryId,
      String subcategory,
      String departmentId,
      String warehouse,
      String unit,
      int soni,
      String? expiration,
      ) async {
    final Map<String, dynamic> foodData = {
      'name': name,
      'price': price,
      'category': categoryId,
      'department_id': departmentId,
      'warehouse': warehouse,
      'unit': unit,
      'soni': soni,
      if (subcategory.isNotEmpty) 'subcategory': subcategory,
      if (expiration != null && expiration.isNotEmpty) 'expiration': expiration,
    };

    final response = await http.put(
      Uri.parse('https://sora-b.vercel.app/api/foods/update/$foodId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'food': foodData}),
    );

    if (response.statusCode != 200) {
      final errorMessage = response.body.isNotEmpty
          ? jsonDecode(response.body)['message'] ?? 'Noma\'lum xatolik'
          : 'Noma\'lum xatolik';
      throw Exception("Mahsulotni yangilashda xatolik: $errorMessage");
    }
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}