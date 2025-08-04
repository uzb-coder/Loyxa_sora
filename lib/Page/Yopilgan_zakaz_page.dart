import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthServices {
  static const String baseUrl = "https://sora-b.vercel.app/api";
  static const String userCode = "9090034564";
  static const String password = "0000";

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    print("✅ Token localda saqlandi");
  }

  static Future<String?> getTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> loginAndPrintToken() async {
    final Uri loginUrl = Uri.parse('$baseUrl/auth/login');

    print("Yuborilayotgan ma'lumot: user_code=$userCode, password=$password");

    try {
      final response = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_code': userCode, 'password': password}),
      );

      print("📥 Status Code: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String token = data['token'];
        await saveToken(token);
        print("✅ Token muvaffaqiyatli olindi: $token");
      } else {
        print(
          "❌ Login xatolik. Status: ${response.statusCode}, Body: ${response.body}",
        );
        throw Exception('Login xatolik: ${response.statusCode}');
      }
    } catch (e) {
      print("❗ Xatolik yuz berdi: $e");
      throw Exception('Login xatolik: $e');
    }
  }
}

class OrderService {
  final String baseUrl = "https://sora-b.vercel.app/api";
  String? _token;

  Future<void> _initializeToken() async {
    try {
      _token = await AuthServices.getTokens();
      if (_token == null) {
        await AuthServices.loginAndPrintToken();
        _token = await AuthServices.getTokens();
      }
      if (_token == null) {
        throw Exception('Token olishda xatolik: Token null bo\'lib qoldi');
      }
    } catch (e) {
      throw Exception('Token olishda xatolik: $e');
    }
  }

  Future<List<dynamic>> getPendingPayments() async {
    await _initializeToken();

    if (_token == null) {
      throw Exception('Token topilmadi, iltimos qayta urinib ko\'ring');
    }

    final url = Uri.parse('$baseUrl/orders/pending-payments');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print("✅ Json malumotlar ${response.body}");
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['pending_orders'] != null) {
          return List<dynamic>.from(data['pending_orders']);
        } else {
          return [];
        }
      } else {
        throw Exception('Xato: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print("❗ API xatoligi: $e");
      throw Exception('API xatoligi: $e');
    }
  }
}

class MainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ofitsiantlarni Tanlang',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 30,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        leading: Icon(Icons.restaurant_menu, color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent.shade100, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildWaiterButton(context, 'Nozima', Icons.person),
            _buildWaiterButton(context, 'Zilola', Icons.person),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiterButton(
    BuildContext context,
    String waiterName,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blueAccent.withOpacity(0.1),
            child: Icon(icon, color: Colors.blueAccent),
          ),
          title: Text(
            waiterName.toUpperCase(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          trailing: Icon(Icons.arrow_forward_ios, color: Colors.blueAccent),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderDetailsPage(waiterName: waiterName),
              ),
            );
          },
        ),
      ),
    );
  }
}

class OrderDetailsPage extends StatelessWidget {
  final String waiterName;

  const OrderDetailsPage({required this.waiterName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Ofitsiant : $waiterName',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            FutureBuilder<List<dynamic>>(
              future: OrderService().getPendingPayments(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Text(
                    'Xizmat haqi: Yuklanmoqda...',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  );
                } else if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return Text(
                    'Xizmat haqi: 0 so\'m',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  );
                }

                final filteredOrders =
                    snapshot.data!
                        .where(
                          (order) => order['waiterName']
                              .toString()
                              .toLowerCase()
                              .contains(waiterName.toLowerCase()),
                        )
                        .toList();
                final totalService = filteredOrders.fold<double>(
                  0,
                  (sum, order) =>
                      sum + (order['serviceAmount'] as num).toDouble(),
                );

                return Text(
                  'Ummumiy xizmat haqi: ${totalService.toStringAsFixed(0)} so\'m',
                  style: TextStyle(fontSize: 20, color: Colors.white70),
                );
              },
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent.shade100, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: PendingPaymentsPage(waiterName: waiterName),
      ),
    );
  }
}

class PendingPaymentsPage extends StatefulWidget {
  final String waiterName;

  const PendingPaymentsPage({required this.waiterName});

  @override
  _PendingPaymentsPageState createState() => _PendingPaymentsPageState();
}

class _PendingPaymentsPageState extends State<PendingPaymentsPage> {
  final OrderService orderService = OrderService();
  Future<List<dynamic>>? pendingPayments;

  @override
  void initState() {
    super.initState();
    pendingPayments = orderService.getPendingPayments();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: pendingPayments,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Xato: ${snapshot.error}',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'Kutayotgan to\'lovlar topilmadi.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        final allOrders = snapshot.data!;
        final filteredOrders =
            allOrders
                .where(
                  (order) => order['waiterName']
                      .toString()
                      .toLowerCase()
                      .contains(widget.waiterName.toLowerCase()),
                )
                .toList();

        if (filteredOrders.isEmpty) {
          return Center(
            child: Text(
              '${widget.waiterName} uchun buyurtma topilmadi.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, // Four cards per row
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1.5, // Compact, less tall cards
          ),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final order = filteredOrders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }




  Future<void> _printOrderDirectly(Map<String, dynamic> orderData, String printerName) async {
    try {
      final List<int> bytes = [];

      // ESC/POS reset
      bytes.addAll([0x1B, 0x40]); // Initialize printer

      // Katta font (double height & width)
      bytes.addAll([0x1D, 0x21, 0x11]); // 0x11 = double width + double height

      bytes.addAll(utf8.encode('===== Buyurtma Cheki =====\n'));

      // Normal font
      bytes.addAll([0x1D, 0x21, 0x00]);

      bytes.addAll(utf8.encode('Buyurtma: ${orderData['orderNumber']}\n'));
      bytes.addAll(utf8.encode('Stol: ${orderData['tableNumber']}\n'));
      bytes.addAll(utf8.encode('Mahsulotlar: ${orderData['itemsCount']}\n'));
      bytes.addAll(utf8.encode('Xizmat: ${orderData['serviceAmount']} so\'m\n'));
      bytes.addAll(utf8.encode('Status: ${orderData['status']}\n'));
      bytes.addAll(utf8.encode('Sana: ${orderData['completedAt']}\n'));

      bytes.addAll(utf8.encode('------------------------------\n'));

      // Bold ON
      bytes.addAll([0x1B, 0x45, 0x01]);
      bytes.addAll(utf8.encode('JAMI: ${orderData['subtotal']} so\'m\n'));
      bytes.addAll(utf8.encode('YAKUNIY: ${orderData['finalTotal']} so\'m\n'));
      // Bold OFF
      bytes.addAll([0x1B, 0x45, 0x00]);

      bytes.addAll(utf8.encode('\n\n\n'));

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/print_${DateTime.now().millisecondsSinceEpoch}.bin');
      await tempFile.writeAsBytes(bytes);

      final result = await Process.run('powershell', [
        '-Command',
        'if (Get-Printer -Name "$printerName") { Get-Content -Encoding Byte "${tempFile.path}" | Out-Printer -Name "$printerName" } else { Write-Error "Printer topilmadi" }'
      ]);

      if (result.exitCode == 0) {
        print('✅ Chek printerga yuborildi');
      } else {
        print('❌ Xatolik: ${result.stderr}');
      }

      await tempFile.delete();
    } catch (e) {
      print('❗ Chop etishda xatolik: $e');
    }
  }

  Widget _buildOrderCard(dynamic order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 280,
        height: 100, // Add a fixed height to make the card taller
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt, color: Colors.blueAccent, size: 20),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '№ ${order['orderNumber']}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            _buildInfoRow(Icons.table_restaurant, 'Stol: ${order['tableNumber']}'),
            _buildInfoRow(Icons.fastfood, 'Mahsulot: ${order['itemsCount']}'),
            _buildInfoRow(Icons.monetization_on, 'Jami: ${order['subtotal']} so\'m'),
            _buildInfoRow(Icons.room_service, 'Xizmat: ${order['serviceAmount']} so\'m'),
            _buildInfoRow(Icons.account_balance_wallet, 'Yakuniy: ${order['finalTotal']} so\'m'),
            _buildInfoRow(Icons.check_circle, 'Holati: ${order['status']}', color: Colors.green),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.grey.shade600, size: 16),
          SizedBox(width: 2),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 18, color: color ?? Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
