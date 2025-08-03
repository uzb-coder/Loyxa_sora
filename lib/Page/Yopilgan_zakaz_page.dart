import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OrderService {
  final String baseUrl = "https://sora-b.vercel.app/api";
  final String token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2ODhhYmQxZjVhN2VjODNlNjM1NTAxNzciLCJyb2xlIjoiYWZpdHNhbnQiLCJpYXQiOjE3NTQwMzIwMzMsImV4cCI6MTc1NDYzNjgzM30.T6JGpOvgTQ08yzKYEYd-5wYPpYWV7SQzb2PE4wEQIVw";

  Future<List<dynamic>> getPendingPayments() async {
    final url = Uri.parse('$baseUrl/orders/pending-payments');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['pending_orders'] != null) {
        return List<dynamic>.from(data['pending_orders']);
      } else {
        return [];
      }
    } else {
      throw Exception('Xato: ${response.statusCode}');
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
            fontSize: 22,
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
            onPressed: () {
              // Yangilash funksiyasini qo'shish mumkin
            },
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

  Widget _buildWaiterButton(BuildContext context, String waiterName, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
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
              'Buyurtmalar: $waiterName',
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  );
                } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(
                    'Xizmat haqi: 0 so\'m',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  );
                }

                final filteredOrders = snapshot.data!
                    .where((order) =>
                    order['waiterName']
                        .toString()
                        .toLowerCase()
                        .contains(waiterName.toLowerCase()))
                    .toList();
                final totalService = filteredOrders.fold<double>(
                  0,
                      (sum, order) => sum + (order['serviceAmount'] as num).toDouble(),
                );

                return Text(
                  'Xizmat haqi: ${totalService.toStringAsFixed(0)} so\'m',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
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
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              // Filtrlash funksiyasini qo'shish mumkin
            },
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
            child: CircularProgressIndicator(
              color: Colors.blueAccent,
            ),
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
        final filteredOrders = allOrders
            .where((order) =>
            order['waiterName']
                .toString()
                .toLowerCase()
                .contains(widget.waiterName.toLowerCase()))
            .toList();

        if (filteredOrders.isEmpty) {
          return Center(
            child: Text(
              '${widget.waiterName} uchun buyurtma topilmadi.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(12),
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
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt, color: Colors.blueAccent, size: 20),
                SizedBox(width: 6),
                Text(
                  'Buyurtma: ${order['orderNumber']}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            _buildInfoRow(Icons.table_restaurant, 'Stol: ${order['tableNumber']}'),
            _buildInfoRow(Icons.fastfood, 'Mahsulotlar: ${order['itemsCount']}'),
            _buildInfoRow(Icons.monetization_on, 'Jami: ${order['subtotal']} so\'m'),
            _buildInfoRow(Icons.room_service, 'Xizmat haqi: ${order['serviceAmount']} so\'m'),
            _buildInfoRow(Icons.account_balance_wallet, 'Yakuniy jami: ${order['finalTotal']} so\'m'),
            _buildInfoRow(Icons.check_circle, 'Holati: ${order['status']}', color: Colors.green),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.grey.shade600, size: 18),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}