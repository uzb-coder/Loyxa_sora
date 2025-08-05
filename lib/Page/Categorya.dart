import 'package:flutter/material.dart';
import '../Controller/Categorya_Controller.dart';
import '../Model/Categorya_Model.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late Future<List<Category>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = CategoryaController().fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kategoriyalar")),
      body: FutureBuilder<List<Category>>(
        future: _categories,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Xatolik: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Kategoriya topilmadi"));
          }

          final categories = snapshot.data!;

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text(category.title),
                  children: category.subcategories.map((subcategory) {
                    return ListTile(
                      title: Text(subcategory),
                      onTap: () {
                        // Subkategoriya bosilganda nima bo'lishini shu yerda yozasiz
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$subcategory bosildi')),
                        );
                      },
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
