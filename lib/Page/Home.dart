import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:io';

import '../Categorya.dart';
import '../Controller/Categorya_Controller.dart';
import '../Controller/StolController.dart';
import '../Controller/OvqatCOntroller.dart';
import '../Controller/ZakazController.dart';
import '../Controller/usersCOntroller.dart';
import '../Example.dart';
import '../Model/Categorya_Model.dart';
import '../Model/Ovqat_model.dart';
import '../Model/StolModel.dart';
import 'Yopilgan_zakaz_page.dart';

class CartItem {
  final Ovqat product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class Order {
  final String id;
  final String tableId;
  final String userId;
  final String firstName;
  final List<OrderItem> items;
  final double totalPrice;
  final String status;
  final String createdAt;
  bool isProcessing;

  Order({
    required this.id,
    required this.tableId,
    required this.userId,
    required this.firstName,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.isProcessing = false,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] ?? '',
      tableId: json['table_id']?.toString() ?? '',
      userId: json['user_id'] ?? '',
      firstName: json['waiter_name'] ?? json['first_name'] ?? '',
      items: (json['items'] as List?)
          ?.map((item) => OrderItem.fromJson(item))
          .toList() ?? [],
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      createdAt: json['createdAt'] ?? '',
      isProcessing: false,
    );
  }
}

class OrderItem {
  final String foodId;
  final String? name;
  final int quantity;
  final int? price;
  final String? categoryName;

  OrderItem({
    required this.foodId,
    required this.quantity,
    this.name,
    this.price,
    this.categoryName,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      foodId: json['food_id'] ?? '',
      quantity: json['quantity'] ?? 0,
      name: json['name'],
      price: json['price'],
      categoryName: json['category_name'],
    );
  }
}

class PosScreen extends StatefulWidget {
  final User user;

  const PosScreen({super.key, required this.user});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  String? _selectedTableName;
  String? _selectedTableId;
  List<Order> _selectedTableOrders = [];
  bool _isLoadingOrders = false;

  final String token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2ODhhYmQxZjVhN2VjODNlNjM1NTAxNzciLCJyb2xlIjoiYWZpdHNhbnQiLCJpYXQiOjE3NTQwMzIwMzMsImV4cCI6MTc1NDYzNjgzM30.T6JGpOvgTQ08yzKYEYd-5wYPpYWV7SQzb2PE4wEQIVw";

  void _handleTableTap(String tableName, String tableId) {
    setState(() {
      _selectedTableName = tableName;
      _selectedTableId = tableId;
    });
    _fetchOrdersForTable(tableId);
  }

  Future<void> _fetchOrdersForTable(String tableId) async {
    setState(() {
      _isLoadingOrders = true;
    });

    final String apiUrl = "https://sora-b.vercel.app/api/orders/table/$tableId";

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _selectedTableOrders = data
              .map((json) => Order.fromJson(json))
              .where((order) =>
          order.userId == widget.user.id && // Filter by current user
              order.status == 'pending') // Show only pending orders
              .toList();
          _isLoadingOrders = false;
        });
      } else {
        setState(() {
          _selectedTableOrders = [];
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      setState(() {
        _selectedTableOrders = [];
        _isLoadingOrders = false;
      });
      print("Xatolik: $e");
    }
  }

  void _showOrderScreenDialog(String tableId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          child: OrderScreenContent(
            tableId: tableId,
            tableName: _selectedTableName,
            user: widget.user,
            onOrderCreated: () {
              _fetchOrdersForTable(tableId);
            },
          ),
        );
      },
    );
  }

  Future<void> _closeOrder(Order order) async {
    if (order.userId != widget.user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu zakazni faqat uni yaratgan afitsant yopa oladi!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() {
        order.isProcessing = true;
      });

      bool success = await Zakazcontroller().closeOrder(order.id);

      if (success) {
        setState(() {
          _selectedTableOrders.removeWhere((o) => o.id == order.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zakaz muvaffaqiyatli yopildi')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik yuz berdi: $e')),
      );
    } finally {
      setState(() {
        order.isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseFontSize = MediaQuery.of(context).textScaler.scale(14.0);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width <= 1200;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 4,
        title: Text(
          "${widget.user.firstName}",
          style: TextStyle(color: Colors.black87, fontSize: baseFontSize * 1.1),
        ),
        actions: [
          SizedBox(
            width: isMobile ? 180 : isTablet ? 200 : 220,
            child: ElevatedButton.icon(
              icon: Icon(Icons.add_circle_outline, size: baseFontSize * 1.5),
              label: Text(
                _selectedTableName != null
                    ? "Yangi hisob (Stol $_selectedTableName)"
                    : "Yangi hisob",
                style: TextStyle(fontSize: baseFontSize * 1.1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedTableName != null ? Colors.teal.shade600 : Colors.teal,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: baseFontSize * 0.5,
                  vertical: baseFontSize * 0.9,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: _selectedTableName != null ? 4 : 2,
              ),
              onPressed: () {
                if (_selectedTableId != null) {
                  _showOrderScreenDialog(_selectedTableId!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Avval stolni tanlang!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ),
          SizedBox(width: baseFontSize * 0.5),
          SizedBox(
            width: isMobile ? 180 : isTablet ? 200 : 220,
            child: ElevatedButton.icon(
              icon: Icon(Icons.check_circle_outline, size: baseFontSize * 1.5),
              label: Text(
                "Yopilgan hisoblar",
                style: TextStyle(fontSize: baseFontSize * 1.1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: baseFontSize * 1.5,
                  vertical: baseFontSize * 0.9,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OrderDetailsPage(waiterName: widget.user.firstName,)),
                );
              },
            ),
          ),
          SizedBox(width: baseFontSize * 0.5),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildTablesGrid(baseFontSize, constraints),
              ),
              Expanded(
                flex: 2,
                child: _buildOrderDetails(baseFontSize, constraints),
              ),
            ],
          );
        },
      ),
    );
  }

  final StolController stolControler = StolController();

  Widget _buildTablesGrid(double fontSize, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width <= 1200;

    return Padding(
      padding: EdgeInsets.all(fontSize * 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stollar',
            style: TextStyle(
              fontSize: fontSize * 1.1,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: fontSize * 0.5),
          Expanded(
            child: FutureBuilder<List<StolModel>>(
              future: stolControler.fetchTables(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text("Xatolik: ${snapshot.error}"));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Hech qanday stol topilmadi."));
                }

                final List<StolModel> tables = snapshot.data!;
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: fontSize * 1.5,
                    mainAxisSpacing: fontSize * 1.5,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (_, index) {
                    final table = tables[index];
                    final isSelected = _selectedTableId == table.id;

                    return GestureDetector(
                      onTap: () {
                        if (_selectedTableId == table.id) {
                          _showOrderScreenDialog(table.id);
                        } else {
                          _handleTableTap(table.name, table.id);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.greenAccent.withOpacity(0.3) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.green : Colors.grey,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _buildTableCard(table, fontSize, context),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(StolModel table, double fontSize, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Text(
            "Stol - ${table.number}",
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "Holati: ${table.status}",
            style: TextStyle(fontSize: fontSize * 0.8, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            "Sig'im: ${table.capacity}",
            style: TextStyle(fontSize: fontSize * 0.8, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Future<void> _printCheck(Order order) async {
    const String printerIP = '192.168.0.106';
    const int port = 9100;

    try {
      StringBuffer receipt = StringBuffer();
      String centerText(String text, int width) => text
          .padLeft((width - text.length) ~/ 2 + text.length)
          .padRight(width);

      receipt.writeln(centerText('--- Restoran Cheki ---', 32));
      receipt.writeln();
      receipt.writeln(centerText('Buyurtma: ${order.id}', 32));
      receipt.writeln();
      receipt.writeln(centerText('Stol: ${_selectedTableName ?? 'N/A'}', 32));
      receipt.writeln();
      receipt.writeln(centerText('Hodim: ${order.firstName}', 32));
      receipt.writeln();
      receipt.writeln(
        centerText(
          'Vaqt: ${DateFormat('d MMMM yyyy, HH:mm', 'uz').format(DateTime.now())}',
          32,
        ),
      );
      receipt.writeln();
      receipt.writeln(centerText('--------------------', 32));
      receipt.writeln();
      receipt.writeln(centerText('Mahsulotlar:', 32));
      receipt.writeln();

      for (var item in order.items) {
        String name = item.name != null && item.name!.length > 18
            ? item.name!.substring(0, 18)
            : item.name ?? 'Noma\'lum mahsulot';
        String quantity = '${item.quantity}x';
        receipt.writeln('${name.padRight(18)}$quantity');
        receipt.writeln();
      }

      receipt.writeln(centerText('--------------------', 32));
      receipt.writeln('\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n');
      receipt.write('\x1D\x56\x00');

      Socket socket = await Socket.connect(
        printerIP,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.write(receipt.toString());
      await socket.flush();
      socket.destroy();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Chek printerga yuborildi!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Printer xatoligi: $e')),
      );
    }
  }

  void _showCheckPreviewDialog(Order order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final baseFontSize = MediaQuery.of(context).textScaler.scale(15.0);

        return AlertDialog(
          titlePadding: EdgeInsets.only(top: baseFontSize * 1.2),
          contentPadding: EdgeInsets.symmetric(
            horizontal: baseFontSize * 0.7,
            vertical: baseFontSize * 0.5,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: baseFontSize * 3.5,
                color: Colors.teal.shade700,
              ),
              SizedBox(height: baseFontSize * 0.8),
              Text(
                'Restoran Cheki',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: baseFontSize * 1.5,
                  color: Colors.black87,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: baseFontSize * 0.6),
            ],
          ),
          content: Container(
            width: 320,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: Card(
              elevation: 6,
              color: const Color(0xFFFAFAFA),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(baseFontSize * 0.8),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Buyurtma: ${order.id}',
                        style: TextStyle(
                          fontSize: baseFontSize * 0.95,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: baseFontSize * 0.6),
                      Text(
                        'Stol: ${_selectedTableName ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: baseFontSize * 0.95,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: baseFontSize * 0.6),
                      Text(
                        'Hodim: ${order.firstName}',
                        style: TextStyle(
                          fontSize: baseFontSize * 0.95,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: baseFontSize * 0.6),
                      Text(
                        'Vaqt: ${DateFormat('d MMMM yyyy, HH:mm', 'uz').format(DateTime.now())}',
                        style: TextStyle(
                          fontSize: baseFontSize * 0.95,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: baseFontSize * 0.6),
                      Divider(thickness: 1.5, height: baseFontSize * 1.2, color: Colors.teal.shade100),
                      SizedBox(height: baseFontSize * 0.3),
                      Text(
                        'Mahsulotlar:',
                        style: TextStyle(
                          fontSize: baseFontSize * 1.05,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                          color: Colors.teal.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: baseFontSize * 0.3),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2.5),
                          1: FlexColumnWidth(1),
                        },
                        children: order.items.map((item) {
                          String name = item.name != null && item.name!.length > 18
                              ? item.name!.substring(0, 18)
                              : item.name ?? 'Noma\'lum';
                          return TableRow(
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: baseFontSize * 0.15),
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: baseFontSize * 0.85,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: baseFontSize * 0.15),
                                child: Text(
                                  '${item.quantity}x',
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: baseFontSize * 0.85,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                      SizedBox(height: baseFontSize * 0.3),
                      Divider(thickness: 1.5, height: baseFontSize * 1.2, color: Colors.teal.shade100),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Bekor qilish',
                style: TextStyle(
                  fontSize: baseFontSize * 0.9,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _printCheck(order);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: baseFontSize * 1.2,
                  vertical: baseFontSize * 0.8,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
              ),
              child: Text(
                'Chop etish',
                style: TextStyle(
                  fontSize: baseFontSize * 0.9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  final Zakazcontroller zakazController = Zakazcontroller();

  Widget _buildOrderDetails(double baseFontSize, BoxConstraints constraints) {
    return Container(
      color: Colors.grey[50],
      padding: EdgeInsets.all(baseFontSize * 0.5),
      child: _selectedTableId == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.point_of_sale_rounded,
              size: baseFontSize * 4,
              color: Colors.grey,
            ),
            SizedBox(height: baseFontSize * 0.5),
            Text(
              "Buyurtma ma'lumotlarini\nko'rish uchun stolni tanlang",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: baseFontSize * 0.9,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.table_bar_rounded, color: Colors.teal.shade600),
              SizedBox(width: 8),
              Text(
                "Stol $_selectedTableName - Zakazlar",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: baseFontSize * 1.2,
                  color: Colors.teal.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: baseFontSize * 0.5),
          Expanded(
            child: _isLoadingOrders
                ? const Center(child: CircularProgressIndicator())
                : _selectedTableOrders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: baseFontSize * 3,
                    color: Colors.grey,
                  ),
                  SizedBox(height: baseFontSize * 0.5),
                  Text(
                    "Bu stolda hech qanday\nzakaz topilmadi",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: baseFontSize * 0.9,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _selectedTableOrders.length,
              itemBuilder: (context, index) {
                final order = _selectedTableOrders[index];
                return Card(
                  elevation: 3,
                  margin: EdgeInsets.only(bottom: baseFontSize * 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(baseFontSize * 0.8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Zakaz #${index + 1}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: baseFontSize * 1.0,
                                color: Colors.teal.shade700,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Kutilmoqda',
                                style: TextStyle(
                                  fontSize: baseFontSize * 0.7,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: baseFontSize * 0.4),
                        _buildInfoRow(
                          Icons.person,
                          'ID:',
                          order.id,
                          baseFontSize,
                        ),
                        SizedBox(height: baseFontSize * 0.4),
                        _buildInfoRow(
                          Icons.person,
                          'Hodim:',
                          order.firstName,
                          baseFontSize,
                        ),
                        SizedBox(height: baseFontSize * 0.2),
                        _buildInfoRow(
                          Icons.access_time,
                          'Vaqt:',
                          _formatDateTime(order.createdAt),
                          baseFontSize,
                        ),
                        SizedBox(height: baseFontSize * 0.4),
                        Text(
                          "Mahsulotlar:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: baseFontSize * 0.9,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: baseFontSize * 0.2),
                        ...order.items.map((item) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade300,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${item.name ?? 'Noma\'lum mahsulot'} x${item.quantity}",
                                  style: TextStyle(
                                    fontSize: baseFontSize * 0.8,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              if (item.price != null)
                                Text(
                                  "${NumberFormat('#,##0', 'uz').format(item.price! * item.quantity)} so'm",
                                  style: TextStyle(
                                    fontSize: baseFontSize * 0.8,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                            ],
                          ),
                        )),
                        Divider(height: baseFontSize * 1.2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Jami:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: baseFontSize * 1.0,
                              ),
                            ),
                            Text(
                              "${NumberFormat('#,##0', 'uz').format(order.totalPrice)} so'm",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: baseFontSize * 1.0,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: baseFontSize * 0.5),
                        Row(
                          children: [
                            order.isProcessing == true
                                ? const Center(child: CircularProgressIndicator())
                                : ElevatedButton.icon(
                              onPressed: () => _closeOrder(order),
                              icon: Icon(Icons.check, size: baseFontSize * 0.9),
                              label: Text(
                                "Yopish",
                                style: TextStyle(fontSize: baseFontSize * 0.8),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade600,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  Widget _buildInfoRow(IconData icon, String key, String value, double fontSize) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: fontSize * 1.0),
        SizedBox(width: fontSize * 0.3),
        Text(
          key,
          style: TextStyle(color: Colors.grey[700], fontSize: fontSize * 0.8),
        ),
        SizedBox(width: fontSize * 0.3),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: fontSize * 0.8,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class OrderScreenContent extends StatefulWidget {
  final User user;
  final String? tableId;
  final VoidCallback? onOrderCreated;
  final String? tableName;

  const OrderScreenContent({
    super.key,
    this.tableId,
    required this.user,
    this.onOrderCreated,
    this.tableName,
  });

  @override
  State<OrderScreenContent> createState() => _OrderScreenContentState();
}

class _OrderScreenContentState extends State<OrderScreenContent> {
  String? _selectedCategoryId;
  String _selectedCategoryName = '';
  List<Category> _categories = [];
  List<Ovqat> _allProducts = [];
  List<Ovqat> _filteredProducts = [];
  bool _isLoading = true;
  String? _error;

  final List<CartItem> _cart = [];
  final NumberFormat _currencyFormatter = NumberFormat('#,##0', 'uz_UZ');
  final CategoryaController _categoryController = CategoryaController();
  final OvqatController _productController = OvqatController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final categories = await _categoryController.fetchCategories().timeout(
        const Duration(seconds: 5),
      );

      final products = await _productController.fetchProducts().timeout(
        const Duration(seconds: 5),
      );

      if (mounted) {
        setState(() {
          _categories = categories;
          _allProducts = products;
          _isLoading = false;

          if (categories.isNotEmpty) {
            _selectedCategoryId = categories.first.id;
            _selectedCategoryName = categories.first.title;
            _filterProductsByCategory();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Ma\'lumotlarni yuklashda xatolik: $e';
        });
      }
    }
  }

  void _filterProductsByCategory() {
    setState(() {
      _filteredProducts = _selectedCategoryId != null
          ? _allProducts.where((product) => product.categoryId == _selectedCategoryId).toList()
          : [];
    });
  }

  void _selectCategory(String categoryId, String categoryName) {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedCategoryName = categoryName;
      _filterProductsByCategory();
    });
  }

  void _addToCart(Ovqat product) {
    setState(() {
      final existingItem = _cart.firstWhere(
            (item) => item.product.id == product.id,
        orElse: () => CartItem(product: product),
      );
      if (_cart.contains(existingItem)) {
        existingItem.quantity++;
      } else {
        _cart.add(CartItem(product: product));
      }
    });
  }

  void _updateQuantity(CartItem cartItem, int change) {
    setState(() {
      cartItem.quantity += change;
      if (cartItem.quantity <= 0) {
        _cart.remove(cartItem);
      }
    });
  }

  double _calculateTotal() {
    return _cart.fold(0, (total, item) => total + item.product.price * item.quantity);
  }

  int _getQuantityInCart(Ovqat product) {
    return _cart
        .firstWhere(
          (item) => item.product.id == product.id,
      orElse: () => CartItem(product: product, quantity: 0),
    )
        .quantity;
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'ichimliklar':
        return Icons.local_bar;
      case 'shirinliklar':
        return Icons.bakery_dining;
      case 'taomlar':
        return Icons.dinner_dining;
      default:
        return Icons.restaurant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseFontSize = screenWidth * 0.04;
    final padding = (screenWidth * 0.04).clamp(12.0, 20.0);

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: Theme.of(context).textTheme.apply(
          fontSizeFactor: screenWidth * 0.003,
          bodyColor: Colors.black87,
          displayColor: Colors.black87,
        ),
      ),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.teal.shade600, Colors.teal.shade50],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                children: [
                  _buildAppBar(baseFontSize),
                  SizedBox(height: padding * 0.5),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: screenWidth * 0.3,
                          child: _buildCategoriesSection(baseFontSize, padding),
                        ),
                        SizedBox(width: padding),
                        Expanded(
                          child: _buildProductsSection(baseFontSize, padding, screenWidth),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: padding * 0.5),
                  _buildBottomActions(baseFontSize, padding),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.shopping_cart, color: Colors.white, size: fontSize * 1.2),
            SizedBox(width: fontSize * 0.5),
            Text(
              widget.tableId != null ? "Hodim: ${widget.user.firstName}" : "Yangi hisob",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: const [
                  Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          icon: Icon(Icons.close, size: fontSize * 1.4, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Yopish',
        ),
      ],
    );
  }

  Widget _buildCategoriesSection(double fontSize, double padding) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategoriyalar',
          style: TextStyle(
            fontSize: fontSize * 1.1,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: const [
              Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
            ],
          ),
        ),
        SizedBox(height: padding * 0.5),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
              : _categories.isEmpty
              ? const Center(
            child: Text('Kategoriyalar topilmadi', style: TextStyle(color: Colors.white)),
          )
              : ListView.builder(
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return Padding(
                padding: EdgeInsets.only(bottom: padding * 0.5),
                child: _buildCategoryButton(category, fontSize, padding),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductsSection(double fontSize, double padding, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mahsulotlar',
          style: TextStyle(
            fontSize: fontSize * 1.1,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: const [
              Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
            ],
          ),
        ),
        SizedBox(height: padding * 0.5),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Padding(
              padding: EdgeInsets.all(padding * 0.5),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
                  : _filteredProducts.isEmpty
                  ? Center(
                child: Text(
                  'Bu kategoriyada mahsulot yo\'q',
                  style: TextStyle(fontSize: fontSize * 0.8, color: Colors.white),
                ),
              )
                  : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  return _buildProductCard(product, fontSize, padding);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryButton(Category category, double fontSize, double padding) {
    final bool isSelected = _selectedCategoryId == category.id;
    return SizedBox(
      height: fontSize * 3,
      child: ElevatedButton(
        onPressed: () => _selectCategory(category.id, category.title),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.teal.shade700 : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.teal.shade700,
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: padding * 0.4, vertical: padding * 0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              _getCategoryIcon(category.title),
              size: fontSize * 0.9,
              color: isSelected ? Colors.white : Colors.teal.shade700,
            ),
            SizedBox(width: padding * 0.3),
            Expanded(
              child: Text(
                category.title,
                style: TextStyle(
                  fontSize: fontSize * 0.85,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Ovqat product, double fontSize, double padding) {
    final int quantityInCart = _getQuantityInCart(product);
    final double totalPrice = product.price * quantityInCart;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: padding * 0.5, vertical: padding * 0.4),
            decoration: BoxDecoration(
              color: Colors.teal.shade600,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Text(
              '${_currencyFormatter.format(product.price)} soʻm',
              style: TextStyle(
                fontSize: fontSize * 0.9,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(padding * 0.5),
              child: Text(
                product.name,
                style: TextStyle(
                  fontSize: fontSize * 1.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (quantityInCart > 0)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: padding * 0.5, vertical: padding * 0.2),
              child: Text(
                'Jami: ${_currencyFormatter.format(totalPrice)} soʻm',
                style: TextStyle(
                  fontSize: fontSize * 0.6,
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(padding * 0.4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (quantityInCart > 0)
                  GestureDetector(
                    onTap: () => _updateQuantity(
                      _cart.firstWhere((item) => item.product.id == product.id),
                      -1,
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.remove, size: fontSize * 0.8, color: Colors.red.shade700),
                    ),
                  ),
                if (quantityInCart > 0) SizedBox(width: padding * 0.5),
                if (quantityInCart > 0)
                  Text(
                    '$quantityInCart',
                    style: TextStyle(
                      fontSize: fontSize * 0.9,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                if (quantityInCart > 0) SizedBox(width: padding * 0.5),
                GestureDetector(
                  onTap: () => _addToCart(product),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade600,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.add, size: fontSize * 0.8, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isSubmitting = false;
  final String token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2ODhhYmQxZjVhN2VjODNlNjM1NTAxNzciLCJyb2xlIjoiYWZpdHNhbnQiLCJpYXQiOjE3NTQwMzIwMzMsImV4cCI6MTc1NDYzNjgzM30.T6JGpOvgTQ08yzKYEYd-5wYPpYWV7SQzb2PE4wEQIVw";

  Future<void> _createOrderAndPrint() async {
    if (_isSubmitting || _cart.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    const String apiUrl = "https://sora-b.vercel.app/api/orders/create";

    final List<Map<String, dynamic>> items = _cart.map((item) {
      return {'food_id': item.product.id, 'quantity': item.quantity};
    }).toList();

    final body = jsonEncode({
      'table_id': widget.tableId,
      'user_id': widget.user.id,
      'first_name': widget.user.firstName,
      'items': items,
      'total_price': _calculateTotal(),
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final orderData = jsonDecode(response.body);

        await _printOrderDirectly(orderData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Zakaz yaratildi!!!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        if (widget.onOrderCreated != null) {
          widget.onOrderCreated!();
        }

        Navigator.of(context).pop();
      } else {
        throw Exception('API xatoligi: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Xatolik: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _printOrderDirectly(Map<String, dynamic> orderData) async {
    const String printerIP = '192.168.0.106';
    const int port = 9100;

    try {
      StringBuffer receipt = StringBuffer();
      String centerText(String text, int width) => text
          .padLeft((width - text.length) ~/ 2 + text.length)
          .padRight(width);

      receipt.writeln(centerText('--- Restoran Cheki ---', 32));
      receipt.writeln();
      receipt.writeln(centerText('Buyurtma: ${orderData['_id'] ?? 'N/A'}', 32));
      receipt.writeln();
      receipt.writeln(centerText('Stol: ${widget.tableName ?? 'N/A'}', 32));
      receipt.writeln();
      receipt.writeln(centerText('Hodim: ${widget.user.firstName}', 32));
      receipt.writeln();
      receipt.writeln(
        centerText(
          'Vaqt: ${DateFormat('d MMMM yyyy, HH:mm', 'uz').format(DateTime.now())}',
          32,
        ),
      );
      receipt.writeln();
      receipt.writeln(centerText('--------------------', 32));
      receipt.writeln();
      receipt.writeln(centerText('Mahsulotlar:', 32));
      receipt.writeln();

      for (var item in _cart) {
        String name = item.product.name.length > 18
            ? item.product.name.substring(0, 18)
            : item.product.name;
        String quantity = '${item.quantity}x';
        receipt.writeln('${name.padRight(18)}$quantity');
        receipt.writeln();
      }

      receipt.writeln(centerText('--------------------', 32));
      receipt.writeln('\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n');
      receipt.write('\x1D\x56\x00');

      Socket socket = await Socket.connect(
        printerIP,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.write(receipt.toString());
      await socket.flush();
      socket.destroy();
    } catch (e) {
      print('Printer xatoligi: $e');
    }
  }

  Widget _buildBottomActions(double fontSize, double padding) {
    final double total = _calculateTotal();
    final bool isCartEmpty = _cart.isEmpty;

    return Container(
      padding: EdgeInsets.all(padding * 0.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (!isCartEmpty) ...[
            Container(
              padding: EdgeInsets.all(padding * 0.4),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart, color: Colors.teal.shade600, size: fontSize * 1.0),
                  SizedBox(width: padding * 0.2),
                  Text(
                    '${_cart.length} xil mahsulot',
                    style: TextStyle(
                      fontSize: fontSize * 0.8,
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_cart.fold(0, (sum, item) => sum + item.quantity)} dona',
                    style: TextStyle(
                      fontSize: fontSize * 0.8,
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: padding * 0.4),
          ],
          Container(
            padding: EdgeInsets.all(padding * 0.1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade100, Colors.teal.shade50],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.teal.shade300, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Umumiy summa:',
                      style: TextStyle(
                        fontSize: fontSize * 0.4,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_currencyFormatter.format(total)} soʻm',
                      style: TextStyle(
                        fontSize: fontSize * 1.0,
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (!isCartEmpty)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.attach_money,
                      color: Colors.white,
                      size: fontSize * 1.3,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: padding * 0.5),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back, size: fontSize * 0.9),
                  label: Text(
                    'Bekor qilish',
                    style: TextStyle(
                      fontSize: fontSize * 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: padding * 0.6),
                    side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                    foregroundColor: Colors.grey.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              SizedBox(width: padding * 0.6),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (isCartEmpty || _isSubmitting) ? null : _createOrderAndPrint,
                  icon: _isSubmitting
                      ? SizedBox(
                    width: fontSize,
                    height: fontSize,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Icon(Icons.restaurant_menu, size: fontSize * 1.0),
                  label: Text(
                    _isSubmitting ? 'Yuklanmoqda...' : 'Zakaz berish',
                    style: TextStyle(
                      fontSize: fontSize * 0.9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (isCartEmpty || _isSubmitting)
                        ? Colors.grey.shade300
                        : Colors.teal.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: padding * 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: (isCartEmpty || _isSubmitting) ? 0 : 4,
                    shadowColor: Colors.teal.shade200,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ZakazDetailPage extends StatefulWidget {
  final String tableId;
  final User user;
  final List<CartItem> cartItems;
  final double total;
  final VoidCallback? onOrderCreated;

  const ZakazDetailPage({
    super.key,
    required this.tableId,
    required this.user,
    required this.cartItems,
    required this.total,
    this.onOrderCreated,
  });

  @override
  _ZakazDetailPageState createState() => _ZakazDetailPageState();
}

class _ZakazDetailPageState extends State<ZakazDetailPage> {
  final NumberFormat _currencyFormatter = NumberFormat('#,##0', 'uz_UZ');
  final String token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2ODhhYmQxZjVhN2VjODNlNjM1NTAxNzciLCJyb2xlIjoiYWZpdHNhbnQiLCJpYXQiOjE3NTQwMzIwMzMsImV4cCI6MTc1NDYzNjgzM30.T6JGpOvgTQ08yzKYEYd-5wYPpYWV7SQzb2PE4wEQIVw";

  bool _isSubmitting = false;

  Future<void> createOrder(BuildContext context) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    const String apiUrl = "https://sora-b.vercel.app/api/orders/create";

    final List<Map<String, dynamic>> items = widget.cartItems.map((item) {
      return {'food_id': item.product.id, 'quantity': item.quantity};
    }).toList();

    final body = jsonEncode({
      'table_id': widget.tableId,
      'user_id': widget.user.id,
      'first_name': widget.user.firstName,
      'items': items,
      'total_price': widget.total,
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Zakaz muvaffaqiyatli yuborildi!'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onOrderCreated != null) {
          widget.onOrderCreated!();
        }

        Navigator.of(context).pop();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Xatolik: ${response.statusCode} - ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Xatolik: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zakaz Tasdiqlash'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: Colors.teal.shade600, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              'Hodim: ${widget.user.firstName} ${widget.user.lastName}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shopping_cart, color: Colors.teal.shade600, size: 24),
                            const SizedBox(width: 10),
                            const Text(
                              'Zakaz mahsulotlari:',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.cartItems.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = widget.cartItems[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.restaurant,
                                      color: Colors.teal.shade600,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_currencyFormatter.format(item.product.price)} so\'m × ${item.quantity}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.teal.shade200),
                                    ),
                                    child: Text(
                                      '${_currencyFormatter.format(item.product.price * item.quantity)} so\'m',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  color: Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Umumiy summa:',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_currencyFormatter.format(widget.total)} so\'m',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Orqaga'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: BorderSide(color: Colors.teal.shade600, width: 2),
                          foregroundColor: Colors.teal.shade600,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () => createOrder(context),
                        icon: _isSubmitting
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Icon(Icons.check_circle),
                        label: Text(_isSubmitting ? 'Yuklanmoqda...' : 'Zakazni tasdiqlash'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}