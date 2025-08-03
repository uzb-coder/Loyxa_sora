import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  Widget _buildOrderCard(dynamic order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt, color: Colors.blueAccent, size: 18),
                  SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      '№ ${order['orderNumber']}',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              _buildInfoRow(
                Icons.table_restaurant,
                'Stol: ${order['tableNumber']}',
              ),
              _buildInfoRow(Icons.fastfood, 'Mahsulot: ${order['itemsCount']}'),
              _buildInfoRow(
                Icons.monetization_on,
                'Jami: ${order['subtotal']}',
              ),
              _buildInfoRow(
                Icons.room_service,
                'Xizmat: ${order['serviceAmount']}',
              ),
              _buildInfoRow(
                Icons.account_balance_wallet,
                'Yakuniy: ${order['finalTotal']}',
              ),
              _buildInfoRow(
                Icons.check_circle,
                'Holati: ${order['status']}',
                color: Colors.green,
              ),    _buildInfoRow(
                Icons.calendar_month,
                'Sana: ${order['completedAt']}',
                color: Colors.blue,
              ),
            ],
          ),
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
