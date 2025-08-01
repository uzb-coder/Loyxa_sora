import 'package:flutter/material.dart';
import 'Categorya.dart';
import 'Controller/StolController.dart';

class TableListScreen extends StatelessWidget {
  final StolController stolControler = StolController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Stollar roʻyxati')),
      body: FutureBuilder<List<dynamic>>(
        future: stolControler.fetchTables(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Xatolik: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("Hech qanday stol topilmadi."));
          }

          final tables = snapshot.data!;

          return ListView.builder(
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final table = tables[index];

              return ListTile(
                leading: Icon(Icons.table_bar, size: 50),
                title: Text("Stol: ${table['name']}"),
                subtitle: Text("Holati: ${table['status']}"),
                onTap: () {
                },
              );
            },
          );
        },
      ),
    );
  }
}
