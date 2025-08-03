import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
class OrderItem {
  final String name;
  final int price;
  final int quantity;

  OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'],
      price: json['price'],
      quantity: json['quantity'],
    );
  }
}

class Order {
  final String id;
  final String tableName;
  final String userFullName;
  final String status;
  final int totalPrice;
  final int finalTotal;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.tableName,
    required this.userFullName,
    required this.status,
    required this.totalPrice,
    required this.finalTotal,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final table = json['table_id'];
    final user = json['user_id'];
    final itemsJson = json['items'] as List;

    return Order(
      id: json['_id'],
      tableName: table != null ? table['display_name'] ?? '' : '',
      userFullName: user != null ? '${user['first_name']} ${user['last_name']}' : '',
      status: json['status'],
      totalPrice: json['total_price'],
      finalTotal: json['final_total'],
      items: itemsJson.map((item) => OrderItem.fromJson(item)).toList(),
    );
  }
}


class OrderController {
  final String baseUrl = "https://sora-b.vercel.app/api";
  final String token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2ODhhYmQxZjVhN2VjODNlNjM1NTAxNzciLCJyb2xlIjoiYWZpdHNhbnQiLCJpYXQiOjE3NTQwMzIwMzMsImV4cCI6MTc1NDYzNjgzM30.T6JGpOvgTQ08yzKYEYd-5wYPpYWV7SQzb2PE4wEQIVw";

  // Pending ordersni olish
  Future<List<Order>> getMyPendingOrders() async {
    final url = Uri.parse('$baseUrl/orders/my-pending');
    print('📤 GET: $url');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print('📥 Status: ${response.statusCode}');
    print('📥 Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List ordersJson = data['orders'];
      return ordersJson.map((json) => Order.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load pending orders');
    }
  }

  // Process Payment (Zakazni yopish)
  Future<bool> processPayment(String orderId) async {
    final url = Uri.parse('$baseUrl/orders/process-payment/$orderId');
    print('📤 POST: $url');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print('📥 Status: ${response.statusCode}');
    print('📥 Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } else {
      throw Exception('Failed to process payment');
    }
  }
}

class MyPendingOrdersPage extends StatefulWidget {
  @override
  _MyPendingOrdersPageState createState() => _MyPendingOrdersPageState();
}
class _MyPendingOrdersPageState extends State<MyPendingOrdersPage> {
  final OrderController _orderController = OrderController();
  late Future<List<Order>> _pendingOrders;

  @override
  void initState() {
    super.initState();
    _pendingOrders = _orderController.getMyPendingOrders();
  }

  Future<void> _processPayment(String orderId) async {
    try {
      final success = await _orderController.processPayment(orderId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Order Processed Successfully')),
        );
        setState(() {
          _pendingOrders = _orderController.getMyPendingOrders(); // Refresh list
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to process order')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Pending Orders'),
      ),
      body: FutureBuilder<List<Order>>(
        future: _pendingOrders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No pending orders.'));
          } else {
            final orders = snapshot.data!;
            return ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: EdgeInsets.all(8),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order ID: ${order.id}', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Table: ${order.tableName}'),
                        Text('User: ${order.userFullName}'),
                        Text('Status: ${order.status}'),
                        SizedBox(height: 8),
                        Text('Items:', style: TextStyle(decoration: TextDecoration.underline)),
                        ...order.items.map((item) => Text('${item.name} - ${item.quantity} x ${item.price} UZS')),
                        Divider(),
                        Text('Final Total: ${order.finalTotal} UZS', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () => _processPayment(order.id),
                          child: Text('Process Payment'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
