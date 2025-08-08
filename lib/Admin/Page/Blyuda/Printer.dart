import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // 🆕 Qo‘shildi
import 'package:data_table_2/data_table_2.dart';

class Printer {
  final String id;
  final String name;
  final String ip;
  final String status;
  final String lastChecked;

  Printer({
    required this.id,
    required this.name,
    required this.ip,
    required this.status,
    required this.lastChecked,
  });

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      id: json['_id'],
      name: json['name'],
      ip: json['ip'],
      status: json['status'],
      lastChecked: json['lastChecked'],
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'ip': ip,
    'status': status,
    'lastChecked': lastChecked,
  };
}

class PrinterTablePage extends StatefulWidget {
  final String token;
  const PrinterTablePage({super.key, required this.token});

  @override
  State<PrinterTablePage> createState() => _PrinterTablePageState();
}

class _PrinterTablePageState extends State<PrinterTablePage> {
  List<Printer> printers = [];
  bool isLoading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCacheAndFetch(); // 🔄
  }

  Future<void> loadCacheAndFetch() async {
    await loadCachedPrinters(); // 🆕
    fetchPrinters(); // serverdan fon rejimida yangilaydi
  }

  Future<void> loadCachedPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('cached_printers');
    if (jsonString != null) {
      final List list = jsonDecode(jsonString);
      setState(() {
        printers = list.map((e) => Printer.fromJson(e)).toList();
        isLoading = false;
      });
    }
  }

  Future<void> savePrintersToCache(List<Printer> printers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(printers.map((p) => p.toJson()).toList());
    await prefs.setString('cached_printers', jsonString);
  }

  Future<void> fetchPrinters() async {
    final url = Uri.parse('https://sora-b.vercel.app/api/printers');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['printers'];
      final newPrinters = list.map((json) => Printer.fromJson(json)).toList();
      setState(() {
        printers = newPrinters;
        isLoading = false;
      });
      savePrintersToCache(newPrinters); // 🆕
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> createPrinter() async {
    final name = _nameController.text.trim();
    final ip = _ipController.text.trim();

    if (name.isEmpty || ip.isEmpty) return;

    final url = Uri.parse('https://sora-b.vercel.app/api/printers');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name, 'ip': ip}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      Navigator.pop(context);
      _nameController.clear();
      _ipController.clear();
      fetchPrinters();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Printer yaratishda xatolik yuz berdi")),
      );
    }
  }

  Future<void> updatePrinter(String id) async {
    final name = _nameController.text.trim();
    final ip = _ipController.text.trim();

    if (name.isEmpty || ip.isEmpty) return;

    final url = Uri.parse('https://sora-b.vercel.app/api/printers/$id');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name, 'ip': ip}),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context);
      _nameController.clear();
      _ipController.clear();
      fetchPrinters();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Printer yangilanishida xatolik yuz berdi")),
      );
    }
  }

  Future<void> deletePrinter(String id) async {
    final url = Uri.parse('https://sora-b.vercel.app/api/printers/$id');
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );

    if (response.statusCode == 200) {
      fetchPrinters();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Printerni o'chirishda xatolik yuz berdi")),
      );
    }
  }

  void showPrinterDialog({String? id, String? initialName, String? initialIp}) {
    _nameController.text = initialName ?? '';
    _ipController.text = initialIp ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        alignment: Alignment.center, // Markazda chiqadi
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          id == null ? "Yangi Printer qo'shish" : "Printerni tahrirlash",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: SizedBox(
          width: 400, // Kattaroq bo'lishi uchun
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Printer nomi",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: "IP manzili",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            onPressed: () =>
            id == null ? createPrinter() : updatePrinter(id),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Saqlash",style: TextStyle(color: Colors.black),),
          ),
        ],
      ),
    );
  }


  void confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("O'chirishni tasdiqlaysizmi?"),
        content: const Text("Bu printerni butunlay o'chirasiz."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deletePrinter(id);
            },
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Printerlar ro'yxati"),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: () => showPrinterDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Bo'lim qo'shish",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3), // Ko‘k rang
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : printers.isEmpty
                  ? const Center(child: Text("Printerlar topilmadi"))
                  : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(12),
                child: DataTable2(
                  columnSpacing: 12,
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFE0E0E0)),
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  columns: const [
                    DataColumn(label: Text("Nomi")),
                    DataColumn(label: Text("IP manzili")),
                    DataColumn(label: Text("Holati")),
                    DataColumn(label: Text("Amallar")),
                  ],
                  rows: printers.map((printer) {
                    return DataRow(cells: [
                      DataCell(Text(printer.name)),
                      DataCell(Text(printer.ip)),
                      DataCell(Text(printer.status)),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF2196F3)),
                            onPressed: () => showPrinterDialog(
                              id: printer.id,
                              initialName: printer.name,
                              initialIp: printer.ip,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => confirmDelete(printer.id),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
