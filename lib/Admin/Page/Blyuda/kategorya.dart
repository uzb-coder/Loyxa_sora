// To'liq tozalangan va to'ldirilgan kod:

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Printer {
  final String id;
  final String name;
  final String ip;

  Printer({required this.id, required this.name, required this.ip});

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      ip: json['ip'] ?? '',
    );
  }
}

class Subcategory {
  final String title;

  Subcategory({required this.title});

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(title: json['title'] ?? '');
  }
}

class Category {
  final String id;
  final String title;
  final Printer printer;
  final List<Subcategory> subcategories;

  Category({
    required this.id,
    required this.title,
    required this.printer,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final subcategoriesJson = json['subcategories'];
    List<Subcategory> subcategoriesList = [];

    if (subcategoriesJson != null && subcategoriesJson is List) {
      subcategoriesList = subcategoriesJson
          .where((e) => e != null)
          .map((e) => Subcategory.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Category(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      printer: Printer.fromJson(json['printer_id'] ?? {}),
      subcategories: subcategoriesList,
    );
  }
}

Future<List<Category>> fetchCategories(String token) async {
  final response = await http.get(
    Uri.parse('https://sora-b.vercel.app/api/categories/list'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final List categoriesJson = data['categories'] ?? [];
    return categoriesJson
        .map((categoryJson) =>
        Category.fromJson(categoryJson as Map<String, dynamic>))
        .toList();
  } else {
    throw Exception('Kategoriya yuklab bo‘lmadi');
  }
}

Future<List<Printer>> fetchPrinters(String token) async {
  final response = await http.get(
    Uri.parse('https://sora-b.vercel.app/api/printers'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final List<dynamic> printersJson = data['printers'] ?? [];
    return printersJson
        .map((e) => Printer.fromJson(e as Map<String, dynamic>))
        .toList();
  } else {
    throw Exception("Printerlar olinmadi");
  }
}

class CategoryTablePage extends StatefulWidget {
  final String token;
  const CategoryTablePage({super.key, required this.token});

  @override
  State<CategoryTablePage> createState() => _CategoryTablePageState();
}

class _CategoryTablePageState extends State<CategoryTablePage> {
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = fetchCategories(widget.token);
  }

  void _refresh() {
    setState(() {
      _categoriesFuture = fetchCategories(widget.token);
    });
  }

  Future<void> _deleteCategory(String id) async {
    final res = await http.delete(
      Uri.parse('https://sora-b.vercel.app/api/categories/delete/$id'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    if (res.statusCode == 200) _refresh();
  }

  void _openAddCategoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddCategoryModal(token: widget.token, onRefresh: _refresh),
    );
  }

  void _openEditCategoryModal(Category category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditCategoryModal(
        token: widget.token,
        category: category,
        onRefresh: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false, // <<< Orqaga qaytish tugmasini yo'qotadi
        title: Row(
          children: [
            ElevatedButton.icon(
              onPressed: _openAddCategoryModal,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Kategoriya yaratish",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFFF5F5F5),
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        height: double.infinity,
        child: FutureBuilder<List<Category>>(
          future: _categoriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Xatolik: ${snapshot.error}"));
            }

            final categories = snapshot.data ?? [];

            return Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width),
                    child: DataTable(
                      headingRowColor: MaterialStateColor.resolveWith(
                              (states) => Colors.grey[200]!),
                      dataRowColor: MaterialStateColor.resolveWith(
                              (states) => Colors.white),
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(
                            label: Text("Kategoriya",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Printer")),
                        DataColumn(label: Text("IP")),
                        DataColumn(label: Text("Subkategoriyalar")),
                        DataColumn(label: Text("Amal")),
                      ],
                      rows: categories.map((cat) {
                        return DataRow(
                          cells: [
                            DataCell(Text(cat.title)),
                            DataCell(Text(cat.printer.name)),
                            DataCell(Text(cat.printer.ip)),
                            DataCell(
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 100,
                                  maxWidth: 250,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: cat.subcategories.map((sub) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Text("• ${sub.title}"),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _openEditCategoryModal(cat),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _deleteCategory(cat.id),
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
              ),
            );
          },
        ),
      ),
    );
  }

}

// AddCategoryModal ni avvalgi kodingizdagidek ishlatish mumkin, o'zgarish kiritilmagan.

// AddCategoryModal ni avvalgi kodingizdagidek ishlatish mumkin, o'zgarish kiritilmagan.

class AddCategoryModal extends StatefulWidget {
  final String token;
  final VoidCallback onRefresh;

  const AddCategoryModal({super.key, required this.token, required this.onRefresh});

  @override
  State<AddCategoryModal> createState() => _AddCategoryModalState();
}

class _AddCategoryModalState extends State<AddCategoryModal> {
  final _categoryNameController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final List<String> _subcategories = [];
  List<Printer> _printers = [];
  Printer? _selectedPrinter;

  @override
  void initState() {
    super.initState();
    fetchPrinters(widget.token).then((list) {
      setState(() {
        _printers = list;
        if (_printers.isNotEmpty) _selectedPrinter = _printers[0];
      });
    });
  }

  void _addSubcategory() {
    final name = _subcategoryController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _subcategories.add(name);
        _subcategoryController.clear();
      });
    }
  }

  void _createCategory() async {
    final body = {
      "title": _categoryNameController.text.trim(),
      "printer_id": _selectedPrinter?.id,
      "subcategories": _subcategories.map((e) => {"title": e}).toList(),
    };

    final response = await http.post(
      Uri.parse('https://sora-b.vercel.app/api/categories/create'), // change URL if needed
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      Navigator.pop(context);
      widget.onRefresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: ${response.body}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Yangi kategoriya qo‘shish", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),

            TextField(
              controller: _categoryNameController,
              decoration: const InputDecoration(labelText: "Kategoriya nomi"),
            ),

            const SizedBox(height: 10),
            DropdownButtonFormField<Printer>(
              decoration: const InputDecoration(labelText: "Printer tanlang"),
              items: _printers.map((printer) {
                return DropdownMenuItem(
                  value: printer,
                  child: Text(printer.name),
                );
              }).toList(),
              value: _selectedPrinter,
              onChanged: (value) => setState(() => _selectedPrinter = value),
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subcategoryController,
                    decoration: const InputDecoration(labelText: "Subkategoriya nomi"),
                  ),
                ),
                IconButton(
                  onPressed: _addSubcategory,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            // Subkategoriya ro'yxati
            if (_subcategories.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _subcategories.map((e) => Text("• $e")).toList(),
              ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createCategory,
              child: const Text("Yaratish"),
            ),
          ],
        ),
      ),
    );
  }
}

class EditCategoryModal extends StatefulWidget {
  final String token;
  final Category category;
  final VoidCallback onRefresh;

  const EditCategoryModal({
    super.key,
    required this.token,
    required this.category,
    required this.onRefresh,
  });

  @override
  State<EditCategoryModal> createState() => _EditCategoryModalState();
}

class _EditCategoryModalState extends State<EditCategoryModal> {
  late TextEditingController _titleController;
  late TextEditingController _subcategoryController;
  List<String> _subcategories = [];
  List<Printer> _printers = [];
  Printer? _selectedPrinter;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.category.title);
    _subcategoryController = TextEditingController();
    _subcategories = widget.category.subcategories.map((e) => e.title).toList();
    fetchPrinters(widget.token).then((list) {
      setState(() {
        _printers = list;
        _selectedPrinter = list.firstWhere(
              (printer) => printer.id == widget.category.printer.id,
          orElse: () => list.first,
        );
      });
    });
  }

  void _addSubcategory() {
    final name = _subcategoryController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _subcategories.add(name);
        _subcategoryController.clear();
      });
    }
  }

  void _removeSubcategory(String name) {
    setState(() {
      _subcategories.remove(name);
    });
  }

  Future<void> _updateCategory() async {
    final url = 'https://sora-b.vercel.app/api/categories/update/${widget.category.id}';

    final body = {
      "title": _titleController.text.trim(),
      "printer_id": _selectedPrinter?.id,
      "subcategories": _subcategories.map((e) => {"title": e}).toList(),
    };

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context);
      widget.onRefresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kategoriyani tahrirlash", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Kategoriya nomi"),
            ),

            const SizedBox(height: 10),
            DropdownButtonFormField<Printer>(
              decoration: const InputDecoration(labelText: "Printer tanlang"),
              items: _printers.map((printer) {
                return DropdownMenuItem(
                  value: printer,
                  child: Text(printer.name),
                );
              }).toList(),
              value: _selectedPrinter,
              onChanged: (value) => setState(() => _selectedPrinter = value),
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subcategoryController,
                    decoration: const InputDecoration(labelText: "Subkategoriya qo‘shish"),
                  ),
                ),
                IconButton(
                  onPressed: _addSubcategory,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            Wrap(
              spacing: 6,
              children: _subcategories.map((sub) {
                return Chip(
                  label: Text(sub),
                  onDeleted: () => _removeSubcategory(sub),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateCategory,
              child: const Text("Saqlash"),
            ),
          ],
        ),
      ),
    );
  }
}
