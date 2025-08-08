import 'package:flutter/material.dart';
import 'dart:math';


class TableModel {
  Offset position;
  Size size;
  final String id;
  String name;
  int capacity;
  int chairs;

  TableModel({
    required this.id,
    required this.position,
    required this.size,
    required this.name,
    required this.capacity,
    this.chairs = 4,
  });
}

class StollarniJoylashuv extends StatefulWidget {
  @override
  _TableEditorScreenState createState() => _TableEditorScreenState();
}

class _TableEditorScreenState extends State<StollarniJoylashuv> {
  List<TableModel> tables = [];
  int _tableCounter = 1;

  void _addNewTable() {
    final nameController = TextEditingController();
    final capacityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Yangi stol yaratish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: InputDecoration(labelText: "Stol nomi")),
              TextField(controller: capacityController, decoration: InputDecoration(labelText: "Nechi kishilik"), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final capacity = int.tryParse(capacityController.text) ?? 4;
                if (name.isEmpty) return;
                setState(() {
                  tables.add(TableModel(
                    id: _tableCounter.toString(),
                    name: name,
                    capacity: capacity,
                    chairs: capacity,
                    position: Offset(100, 100),
                    size: Size(120, 80),
                  ));
                  _tableCounter++;
                });
                Navigator.pop(context);
              },
              child: Text("Qo‘shish"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Bekor qilish"),
            ),
          ],
        );
      },
    );
  }

  void _openEditModal(TableModel table) {
    final nameController = TextEditingController(text: table.name);
    final capacityController = TextEditingController(text: table.capacity.toString());
    final chairsController = TextEditingController(text: table.chairs.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Stol ma'lumotlari", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              TextField(controller: nameController, decoration: InputDecoration(labelText: "Stol nomi")),
              TextField(controller: capacityController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Nechi kishilik")),
              TextField(controller: chairsController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Stullar soni")),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        tables.removeWhere((t) => t.id == table.id);
                      });
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.delete),
                    label: Text("O‘chirish"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        table.name = nameController.text.trim();
                        table.capacity = int.tryParse(capacityController.text) ?? table.capacity;
                        table.chairs = int.tryParse(chairsController.text) ?? table.chairs;
                      });
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.save),
                    label: Text("Saqlash"),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableWithChairs(TableModel table) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _openEditModal(table),
          child: Container(
            width: table.size.width,
            height: table.size.height,
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(table.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("${table.capacity} kishilik", style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                table.size = Size(
                  (table.size.width + details.delta.dx).clamp(60.0, 300.0),
                  (table.size.height + details.delta.dy).clamp(60.0, 300.0),
                );
              });
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black), shape: BoxShape.circle),
              child: Icon(Icons.drag_handle, size: 14),
            ),
          ),
        ),
        ..._buildChairsOutside(table),
      ],
    );
  }

  List<Widget> _buildChairsOutside(TableModel table) {
    List<Widget> chairs = [];
    final double radius = max(table.size.width, table.size.height) / 2 + 25;
    final Offset center = Offset(table.size.width / 2, table.size.height / 2);

    for (int i = 0; i < table.chairs; i++) {
      final angle = 2 * pi * i / table.chairs;
      final double dx = center.dx + radius * cos(angle) - 10;
      final double dy = center.dy + radius * sin(angle) - 10;

      chairs.add(Positioned(
        left: dx,
        top: dy,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle, border: Border.all(color: Colors.black)),
        ),
      ));
    }

    return chairs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Restoran stollari"),
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_forward),
            tooltip: "Ko‘rish",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TablePreviewScreen(tables: tables),
                ),
              );
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewTable,
        child: Icon(Icons.add),
        tooltip: 'Yangi stol qo‘shish',
      ),
      body: Stack(
        children: tables.map((table) {
          return Positioned(
            left: table.position.dx,
            top: table.position.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  table.position += details.delta;
                });
              },
              child: _buildTableWithChairs(table),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class TablePreviewScreen extends StatelessWidget {
  final List<TableModel> tables;

  const TablePreviewScreen({super.key, required this.tables});

  List<Widget> _buildChairsOutside(TableModel table) {
    List<Widget> chairs = [];
    final double radius = max(table.size.width, table.size.height) / 2 + 25;
    final Offset center = Offset(table.size.width / 2, table.size.height / 2);

    for (int i = 0; i < table.chairs; i++) {
      final angle = 2 * pi * i / table.chairs;
      final double dx = center.dx + radius * cos(angle) - 10;
      final double dy = center.dy + radius * sin(angle) - 10;

      chairs.add(Positioned(
        left: dx,
        top: dy,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black),
          ),
        ),
      ));
    }

    return chairs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Joylashtirilgan stollar")),
      body: Stack(
        children: tables.map((table) {
          return Positioned(
            left: table.position.dx,
            top: table.position.dy,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Stol
                Container(
                  width: table.size.width,
                  height: table.size.height,
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(table.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text("${table.capacity} kishilik", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                // Dumaloq stullar
                ..._buildChairsOutside(table),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
