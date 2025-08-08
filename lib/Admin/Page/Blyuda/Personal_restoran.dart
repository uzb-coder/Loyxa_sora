import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PersonalRestoran extends StatefulWidget {
  final String token;
  const PersonalRestoran({super.key, required this.token});

  @override
  State<PersonalRestoran> createState() => _UserPageState();
}

class _UserPageState extends State<PersonalRestoran> {
  List<dynamic> users = [];

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    final res = await http.get(
      Uri.parse("https://sora-b.vercel.app/api/users"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
    );
    if (res.statusCode == 200) {
      setState(() {
        users = json.decode(res.body);
      });
    } else {
      print("Xatolik: ${res.statusCode}");
    }
  }

  Future<void> addUser(Map<String, dynamic> userData) async {
    final res = await http.post(
      Uri.parse("https://sora-b.vercel.app/api/users"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: json.encode(userData),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      Navigator.pop(context);
      fetchUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foydalanuvchini qo‘shishda xatolik')),
      );
    }
  }

  Future<void> updateUser(String id, Map<String, dynamic> userData) async {
    final res = await http.put(
      Uri.parse("https://sora-b.vercel.app/api/users/$id"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: json.encode(userData),
    );
    if (res.statusCode == 200) {
      Navigator.pop(context);
      fetchUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foydalanuvchini yangilashda xatolik')),
      );
    }
  }

  Future<void> deleteUser(String id) async {
    final res = await http.delete(
      Uri.parse("https://sora-b.vercel.app/api/users/$id"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
    );
    if (res.statusCode == 200) {
      fetchUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foydalanuvchini o‘chirishda xatolik')),
      );
    }
  }

  void _openAddUserModal() {
    _openUserModal();
  }

  void _openEditUserModal(Map<String, dynamic> user) {
    _openUserModal(editUser: user);
  }

  void _openUserModal({Map<String, dynamic>? editUser}) {
    String firstName = editUser?['first_name'] ?? '';
    String lastName = editUser?['last_name'] ?? '';
    String password = '';
    String userCode = editUser?['user_code'] ?? '';
    String selectedRole = editUser?['role'] ?? 'kassir';
    String percentage = (editUser != null && editUser['percent'] != null)
        ? editUser['percent'].toString()
        : '';
    Map<String, bool> permissions = {
      'chek': false,
      'atkaz': false,
      'hisob': false,
    };

    if (editUser != null && editUser['permissions'] != null) {
      List<dynamic> perms = editUser['permissions'];
      for (var key in permissions.keys.toList()) {
        permissions[key] = perms.contains(key);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(editUser == null ? "Foydalanuvchi qo‘shish" : "Foydalanuvchini tahrirlash"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: TextEditingController(text: firstName),
                      decoration: const InputDecoration(labelText: 'Ism'),
                      onChanged: (v) => firstName = v,
                    ),
                    TextField(
                      controller: TextEditingController(text: lastName),
                      decoration: const InputDecoration(labelText: 'Familiya'),
                      onChanged: (v) => lastName = v,
                    ),
                    TextField(
                      decoration: InputDecoration(
                          labelText: editUser == null ? 'Parol' : 'Yangi parol (ixtiyoriy)'),
                      onChanged: (v) => password = v,
                      obscureText: true,
                    ),
                    TextField(
                      controller: TextEditingController(text: userCode),
                      decoration: const InputDecoration(labelText: 'Foydalanuvchi kodi'),
                      onChanged: (v) => userCode = v,
                    ),
                    DropdownButton<String>(
                      value: selectedRole,
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedRole = val);
                        }
                      },
                      items: ['admin', 'kassir', 'ofitsant', 'buxgalter']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                    ),
                    if (selectedRole == 'ofitsant')
                      TextField(
                        controller: TextEditingController(text: percentage),
                        decoration: const InputDecoration(labelText: 'Foiz (%)'),
                        onChanged: (v) => percentage = v,
                        keyboardType: TextInputType.number,
                      ),
                    const SizedBox(height: 10),
                    if (selectedRole != 'ofitsant')
                      Column(
                        children: permissions.keys.map((key) {
                          return CheckboxListTile(
                            title: Text(key),
                            value: permissions[key],
                            onChanged: (v) {
                              setModalState(() => permissions[key] = v!);
                            },
                          );
                        }).toList(),
                      )
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    final selectedPermissions = permissions.entries
                        .where((e) => e.value)
                        .map((e) => e.key)
                        .toList();

                    final userData = {
                      "first_name": firstName,
                      "last_name": lastName,
                      "role": selectedRole,
                      "user_code": userCode,
                      "is_active": true,
                    };

                    if (password.isNotEmpty) {
                      userData["password"] = password;
                    }

                    if (selectedRole != 'ofitsant' && selectedPermissions.isNotEmpty) {
                      userData['permissions'] = selectedPermissions;
                    }

                    if (selectedRole == 'ofitsant' && percentage.isNotEmpty) {
                      userData['percent'] = double.parse(percentage);
                    }

                    if (editUser == null) {
                      addUser(userData);
                    } else {
                      updateUser(editUser['_id'], userData);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Saqlash"),
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
      backgroundColor: Colors.white, // Oq fon
      appBar: AppBar(
        backgroundColor: Colors.grey[200],
        title: const Text(
          "Foydalanuvchilar",
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              onPressed: _openAddUserModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Foydalanuvchi qo‘shish"),
            ),
          ),
        ],
      ),
      body: users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey[300]),
              dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                    (Set<MaterialState> states) {
                  if (states.contains(MaterialState.selected)) {
                    return Colors.grey[200];
                  }
                  return null; // default for unselected rows
                },
              ),
              dividerThickness: 1,
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Ism', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Familiya', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Rol', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Kod', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Ruxsatlar', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Amallar', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: users.map((user) {
                return DataRow(cells: [
                  DataCell(Text(user['first_name'] ?? '')),
                  DataCell(Text(user['last_name'] ?? '')),
                  DataCell(Text(user['role'] ?? '')),
                  DataCell(Text(user[''] ?? 'yashirin')),
                  DataCell(Text(
                    (user['permissions'] != null && user['permissions'] is List)
                        ? (user['permissions'] as List).join(', ')
                        : '',
                  )),
                  DataCell(Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          _openEditUserModal(user);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Tasdiqlash'),
                              content: const Text('Foydalanuvchini o‘chirilsinmi?'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                  },
                                  child: const Text('Bekor qilish'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    deleteUser(user['_id']);
                                  },
                                  child: const Text('O‘chirish'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
