import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ClientPage extends StatefulWidget {
  final String token;
  const ClientPage({super.key, required this.token});

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  List<dynamic> _clients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse("https://sora-b.vercel.app/api/clients/list"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          _clients = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Server xatosi: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Tarmoqda xatolik yuz berdi: $e";
        _isLoading = false;
      });
    }
  }

  Future<bool> _createClient({
    required String name,
    required String phone,
    required int discount,
    required String cardNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("https://sora-b.vercel.app/api/clients/create"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "name": name,
          "phone": phone,
          "discount": discount,
          "card_number": cardNumber,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        final body = response.body;
        print("Xatolik: ${response.statusCode} - $body");
        return false;
      }
    } catch (e) {
      print("Xatolik: $e");
      return false;
    }
  }

  Future<bool> _updateClient({
    required String id,
    required String name,
    required String phone,
    required int discount,
    required String cardNumber,
  }) async {
    print("Update client id: $id"); // ID ni tekshirish
    try {
      final response = await http.put(
        Uri.parse("https://sora-b.vercel.app/api/clients/update/$id"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "name": name,
          "phone": phone,
          "discount": discount,
          "card_number": cardNumber,
        }),
      );

      print("Update response status: ${response.statusCode}");
      print("Update response body: ${response.body}");

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Update xatolik: $e");
      return false;
    }
  }

  Future<bool> _deleteClient(String id) async {
    print("Delete client id: $id"); // ID ni tekshirish
    try {
      final response = await http.delete(
        Uri.parse("https://sora-b.vercel.app/api/clients/delete/$id"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
      );

      print("Delete response status: ${response.statusCode}");
      print("Delete response body: ${response.body}");

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Delete xatolik: $e");
      return false;
    }
  }

  Future<void> _showAddClientModal() async {
    final _formKey = GlobalKey<FormState>();

    String name = '';
    String phone = '';
    String discount = '';
    String cardNumber = '';

    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text("Yangi mijoz qo'shish"),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(labelText: "Ism"),
                        onChanged: (val) => name = val,
                        validator:
                            (val) =>
                                val == null || val.isEmpty
                                    ? "Ism kiriting"
                                    : null,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(labelText: "Telefon"),
                        keyboardType: TextInputType.phone,
                        onChanged: (val) => phone = val,
                        validator:
                            (val) =>
                                val == null || val.isEmpty
                                    ? "Telefon kiriting"
                                    : null,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: "Chegirma (%)",
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => discount = val,
                        validator: (val) {
                          if (val == null || val.isEmpty)
                            return "Chegirma kiriting";
                          final number = int.tryParse(val);
                          if (number == null) return "Faqat raqam kiriting";
                          if (number < 0 || number > 100)
                            return "0 dan 100 gacha raqam kiriting";
                          return null;
                        },
                      ),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: "Karta raqami",
                        ),
                        onChanged: (val) => cardNumber = val,
                        validator:
                            (val) =>
                                val == null || val.isEmpty
                                    ? "Karta raqami kiriting"
                                    : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Bekor qilish"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        setStateModal(() {
                          isLoading = true;
                        });
                        final success = await _createClient(
                          name: name,
                          phone: phone,
                          discount: int.parse(discount),
                          cardNumber: cardNumber,
                        );
                        setStateModal(() {
                          isLoading = false;
                        });
                        if (success) {
                          Navigator.of(context).pop();
                          _fetchClients(); // Ro'yxatni yangilash
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Mijoz muvaffaqiyatli qo'shildi"),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Xatolik yuz berdi")),
                          );
                        }
                      }
                    },
                    child: const Text("Yaratish"),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditClientModal(Map<String, dynamic> client) async {
    final _formKey = GlobalKey<FormState>();

    String name = client['name'] ?? '';
    String phone = client['phone'] ?? '';
    String discount = (client['discount']?.toString() ?? '0');
    String cardNumber = client['card_number'] ?? '';

    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text("Mijozni tahrirlash"),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: name,
                        decoration: const InputDecoration(labelText: "Ism"),
                        onChanged: (val) => name = val,
                        validator:
                            (val) =>
                                val == null || val.isEmpty
                                    ? "Ism kiriting"
                                    : null,
                      ),
                      TextFormField(
                        initialValue: phone,
                        decoration: const InputDecoration(labelText: "Telefon"),
                        keyboardType: TextInputType.phone,
                        onChanged: (val) => phone = val,
                        validator:
                            (val) =>
                                val == null || val.isEmpty
                                    ? "Telefon kiriting"
                                    : null,
                      ),
                      TextFormField(
                        initialValue: discount,
                        decoration: const InputDecoration(
                          labelText: "Chegirma (%)",
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => discount = val,
                        validator: (val) {
                          if (val == null || val.isEmpty)
                            return "Chegirma kiriting";
                          final number = int.tryParse(val);
                          if (number == null) return "Faqat raqam kiriting";
                          if (number < 0 || number > 100)
                            return "0 dan 100 gacha raqam kiriting";
                          return null;
                        },
                      ),
                      TextFormField(
                        initialValue: cardNumber,
                        decoration: const InputDecoration(
                          labelText: "Karta raqami",
                        ),
                        onChanged: (val) => cardNumber = val,
                        validator:
                            (val) =>
                                val == null || val.isEmpty
                                    ? "Karta raqami kiriting"
                                    : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Bekor qilish"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        setStateModal(() {
                          isLoading = true;
                        });

                        final success = await _updateClient(
                          id: client['_id'],
                          name: name,
                          phone: phone,
                          discount: int.parse(discount),
                          cardNumber: cardNumber,
                        );

                        setStateModal(() {
                          isLoading = false;
                        });

                        if (success) {
                          Navigator.of(context).pop();
                          _fetchClients();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Mijoz muvaffaqiyatli yangilandi"),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Yangilashda xatolik yuz berdi"),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text("Saqlash"),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(String id) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("O'chirishni tasdiqlang"),
            content: const Text("Mijozni o'chirmoqchimisiz?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Bekor qilish"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("O'chirish"),
              ),
            ],
          ),
    );

    if (result == true) {
      final success = await _deleteClient(id);
      if (success) {
        _fetchClients();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Mijoz o'chirildi")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("O'chirishda xatolik yuz berdi")),
        );
      }
    }
  }

  DataTable _buildDataTable() {
    return DataTable(
      columnSpacing: 24,
      headingRowColor: MaterialStateProperty.all(Colors.grey.shade300),
      columns: const [
        DataColumn(label: Text("Ism")),
        DataColumn(label: Text("Telefon")),
        DataColumn(label: Text("Chegirma")),
        DataColumn(label: Text("Karta raqami")),
        DataColumn(label: Text("Harakatlar")),
      ],
      rows:
          _clients.map((client) {
            return DataRow(
              cells: [
                DataCell(Text(client['name']?.toString() ?? '')),
                DataCell(Text(client['phone']?.toString() ?? '')),
                DataCell(Text("${client['discount']?.toString() ?? '0'}%")),
                DataCell(Text(client['card_number']?.toString() ?? '')),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Tahrirlash',
                        onPressed: () {
                          _showEditClientModal(client);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'O\'chirish',
                        onPressed: () {
                          _confirmDelete(client['_id']);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ElevatedButton.icon(
              onPressed: _showAddClientModal,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Foydalanuvchi yaratish",
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: _buildDataTable(),
              ),
            ),
          );
        },
      ),
      /// 🟢 Quyidagisi qo‘shildi:
      floatingActionButton: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).pop(); // Yoki logout funksiyasi
        },
        label: const Text("Выход"),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(120, 70),
          backgroundColor: const Color(0xFFF5F5F5),
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.grey, width: 2),
          ),
          shadowColor: Colors.black.withOpacity(0.2),
          elevation: 6,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),

    );
  }

}
