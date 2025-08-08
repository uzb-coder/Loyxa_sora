import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../../Tajriba.dart';

class PendingOrder {
  final String id;
  final String orderNumber;
  final String? formattedOrderNumber;
  final String? tableName;
  final String? waiterName;
  final double totalPrice;
  final String status;
  final String createdAt;
  final List<dynamic> items;
  final MixedPaymentDetails? mixedPaymentDetails;

  PendingOrder({
    required this.id,
    required this.orderNumber,
    this.formattedOrderNumber,
    this.tableName,
    this.waiterName,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.items,
    this.mixedPaymentDetails,
  });

  factory PendingOrder.fromJson(Map<String, dynamic> json) {
    return PendingOrder(
      id: json['_id'] ?? json['id'] ?? '',
      orderNumber: json['orderNumber'] ?? json['formatted_order_number'] ?? '',
      formattedOrderNumber: json['formatted_order_number'] ?? json['orderNumber'],
      tableName: json['table_number'] ??
          json['tableNumber'] ??
          json['table_id']?['name'] ??
          'N/A',
      waiterName: json['waiter_name'] ??
          json['waiterName'] ??
          json['user_id']?['first_name'] ??
          'N/A',
      totalPrice: (json['total_price'] ??
          json['finalTotal'] ??
          json['final_total'] ??
          0)
          .toDouble(),
      status: json['status'] ?? 'pending',
      createdAt:
      json['createdAt'] ?? json['completedAt'] ?? DateTime.now().toIso8601String(),
      items: json['items']?.map((item) {
        return {
          'name': item['name'] ?? 'N/A',
          'quantity': item['quantity'] ?? 0,
          'price': item['price'] ?? 0,
          'printer_ip': item['printer_ip'] ?? null,
        };
      }).toList() ??
          [],
      mixedPaymentDetails: json['mixedPaymentDetails'] != null
          ? MixedPaymentDetails.fromJson(json['mixedPaymentDetails'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'orderNumber': orderNumber,
      'formatted_order_number': formattedOrderNumber,
      'table_number': tableName,
      'waiter_name': waiterName,
      'total_price': totalPrice,
      'status': status,
      'createdAt': createdAt,
      'items': items,
      'mixedPaymentDetails': mixedPaymentDetails?.toJson(),
    };
  }
}

class MixedPaymentDetails {
  final Breakdown breakdown;
  final double cashAmount;
  final double cardAmount;
  final double totalAmount;
  final double changeAmount;
  final DateTime timestamp;

  MixedPaymentDetails({
    required this.breakdown,
    required this.cashAmount,
    required this.cardAmount,
    required this.totalAmount,
    required this.changeAmount,
    required this.timestamp,
  });

  factory MixedPaymentDetails.fromJson(Map<String, dynamic> json) {
    return MixedPaymentDetails(
      breakdown: Breakdown.fromJson(json['breakdown'] ?? {}),
      cashAmount: (json['cashAmount'] ?? 0).toDouble(),
      cardAmount: (json['cardAmount'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      changeAmount: (json['changeAmount'] ?? 0).toDouble(),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'breakdown': breakdown.toJson(),
      'cashAmount': cashAmount,
      'cardAmount': cardAmount,
      'totalAmount': totalAmount,
      'changeAmount': changeAmount,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class Breakdown {
  final String cashPercentage;
  final String cardPercentage;

  Breakdown({
    required this.cashPercentage,
    required this.cardPercentage,
  });

  factory Breakdown.fromJson(Map<String, dynamic> json) {
    return Breakdown(
      cashPercentage: json['cash_percentage'] ?? '0.0',
      cardPercentage: json['card_percentage'] ?? '0.0',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cash_percentage': cashPercentage,
      'card_percentage': cardPercentage,
    };
  }
}

class ApiService {
  static const String baseUrl = 'https://sora-b.vercel.app/api';
  String? _token;

  Future<bool> authenticate() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_code': '2004',
          'password': '2004',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> sendToPrinter(String printerIP, String orderId) async {
    try {
      final response = await http.post(
        Uri.parse('http://$printerIP:9100/'),
        headers: {
          'Content-Type': 'text/plain',
        },
        body: 'Order #$orderId Closed\n',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Printed to $printerIP');
      } else {
        print('Printer Error at $printerIP: ${response.body}');
      }
    } catch (e) {
      print('Error sending to printer $printerIP: $e');
    }
  }

  Future<List<PendingOrder>> fetchPendingOrders() async {
    if (_token == null) {
      final success = await authenticate();
      if (!success) return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/my-pending'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['orders'] is List) {
          return (data['orders'] as List)
              .map((orderJson) => PendingOrder.fromJson(orderJson))
              .toList();
        }
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<PendingOrder>> fetchClosedOrders() async {
    if (_token == null) {
      final success = await authenticate();
      if (!success) return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/pending-payments'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['pending_orders'] is List) {
          return (data['pending_orders'] as List)
              .map((orderJson) => PendingOrder.fromJson(orderJson))
              .toList();
        } else if (data is List) {
          return data.map((orderJson) => PendingOrder.fromJson(orderJson)).toList();
        }
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> closeOrder(String orderId, List<dynamic> items) async {
    if (_token == null) {
      final success = await authenticate();
      if (!success) return false;
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/orders/close/$orderId'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Send to printers
        final uniquePrinterIPs = items
            .map((item) => item['printer_ip'])
            .where((ip) => ip != null)
            .toSet()
            .toList();

        for (String printerIP in uniquePrinterIPs) {
          await sendToPrinter(printerIP, orderId);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> processPayment(String orderId, Map<String, dynamic> paymentData) async {
    if (_token == null) {
      final success = await authenticate();
      if (!success) return {'success': false, 'message': 'Authentication failed'};
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/kassir/payment/$orderId'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(paymentData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Payment processed successfully',
          'data': data,
        };
      }
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Payment processing failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing payment: $e',
      };
    }
  }
}

class UnifiedPendingPaymentsPage extends StatefulWidget {
  const UnifiedPendingPaymentsPage({super.key});

  @override
  _UnifiedPendingPaymentsPageState createState() => _UnifiedPendingPaymentsPageState();
}

class _UnifiedPendingPaymentsPageState extends State<UnifiedPendingPaymentsPage> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  String selectedDateRange = "open";
  String searchText = "";
  PendingOrder? selectedOrder;
  bool isPaymentModalVisible = false;
  bool isLoading = true;
  String? errorMessage;
  List<PendingOrder> openOrders = [];
  List<PendingOrder> closedOrders = [];
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final pendingOrders = await apiService.fetchPendingOrders();
      final closedOrdersData = await apiService.fetchClosedOrders();

      setState(() {
        openOrders = pendingOrders;
        closedOrders = closedOrdersData;
        isLoading = false;
        if (pendingOrders.isEmpty && closedOrdersData.isEmpty) {
          errorMessage = 'No orders found from API';
        }
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load orders: $e';
      });
    }
  }

  void handleDateRangeChange(String key) {
    setState(() {
      selectedDateRange = key;
      selectedOrder = null;
    });
  }

  void handlePrintReceipt() {
    if (selectedOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Avval zakazni tanlang!"), duration: Duration(seconds: 3)),
      );
      return;
    }
    print("Printing receipt for order ${selectedOrder!.formattedOrderNumber}");
  }

  void handleCloseOrder(int index) async {
    if (selectedOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Avval zakazni tanlang!"), duration: Duration(seconds: 3)),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final success = await apiService.closeOrder(selectedOrder!.id, selectedOrder!.items);
    setState(() {
      if (success) {
        final removedOrder = openOrders.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
              (context, animation) => _buildOrderCard(removedOrder, index, animation),
          duration: Duration(milliseconds: 100),
        );
        selectedOrder = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Order closed and removed!"), duration: Duration(seconds: 3)),
        );
      } else {
        errorMessage = 'Failed to close order';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to close order"), duration: Duration(seconds: 3)),
        );
      }
      isLoading = false;
    });
  }

  void handleOpenPaymentModal() {
    if (selectedOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Avval zakazni tanlang!"), duration: Duration(seconds: 3)),
      );
      return;
    }
    setState(() {
      isPaymentModalVisible = true;
    });
  }

  Future<Map<String, dynamic>> processPaymentHandler(Map<String, dynamic> apiPayload) async {
    setState(() {
      isLoading = true;
    });

    Map<String, dynamic> paymentData = {
      'orderId': selectedOrder?.id?.toString() ?? '',
    };

    if (apiPayload['paymentData'] != null && apiPayload['paymentData'] is Map) {
      (apiPayload['paymentData'] as Map).forEach((key, value) {
        paymentData[key.toString()] = value;
      });
    }

    final result = await apiService.processPayment(selectedOrder?.id ?? '', paymentData);
    setState(() {
      isLoading = false;
    });
    return result;
  }

  void handlePaymentSuccess(Map<String, dynamic> result) {
    if (selectedOrder != null) {
      final index = closedOrders.indexWhere((order) => order.id == selectedOrder!.id);
      if (index != -1) {
        closedOrders.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
              (context, animation) => _buildOrderCard(closedOrders[index], index, animation),
          duration: Duration(milliseconds: 300),
        );
      }
      setState(() {
        selectedOrder = null;
        isPaymentModalVisible = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('To\'lov muvaffaqiyatli qabul qilindi!')),
          );
          }
              _fetchData();
      }

  List<PendingOrder> getCurrentData() {
    List<PendingOrder> currentData = selectedDateRange == "open" ? openOrders : closedOrders;
    if (searchText.isNotEmpty) {
      currentData = currentData.where((order) {
        final searchLower = searchText.toLowerCase();
        return order.orderNumber.toLowerCase().contains(searchLower) ||
            order.formattedOrderNumber?.toLowerCase().contains(searchLower) == true ||
            order.tableName?.toLowerCase().contains(searchLower) == true ||
            order.waiterName?.toLowerCase().contains(searchLower) == true;
      }).toList();
    }
    return currentData;
  }

  Widget _buildOrderCard(PendingOrder order, int index, Animation<double> animation) {
    final isSelected = selectedOrder?.id == order.id;
    Color rowColor;
    if (isSelected) {
      rowColor = const Color(0xFFd4edda);
    } else if (selectedDateRange == "closed") {
      rowColor = const Color(0xFFffe6e6);
    } else {
      switch (order.status) {
        case "pending":
          rowColor = const Color(0xFFe6f7ff);
          break;
        case "preparing":
          rowColor = const Color(0xFFfff7e6);
          break;
        case "ready":
          rowColor = const Color(0xFFf6ffed);
          break;
        case "served":
          rowColor = const Color(0xFFf9f0ff);
          break;
        default:
          rowColor = const Color(0xFFf0f0f0);
      }
    }

    return SizeTransition(
      sizeFactor: animation,
      child: InkWell(
        onTap: () => setState(() => selectedOrder = order),
        child: Container(
          decoration: BoxDecoration(
            color: rowColor,
            border: isSelected ? Border.all(color: const Color(0xFF28a745), width: 2) : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: selectedDateRange == "open"
              ? _buildOpenOrderRow(order)
              : _buildClosedOrderRow(order),
        ),
      ),
    );
  }

  Widget _buildOpenOrderRow(PendingOrder order) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Column(
            children: [
              Text(
                DateFormat('dd.MM').format(DateTime.parse(order.createdAt)),
                style: const TextStyle(fontSize: 18),
              ),
              Text(
                DateFormat('HH:mm').format(DateTime.parse(order.createdAt)),
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 80,
          child: Text(
            order.formattedOrderNumber ?? order.orderNumber,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 150,
          child: Text(
            order.waiterName ?? "N/A",
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 100,
          child: Text(
            "Stol: ${order.tableName}",
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 120,
          child: Text(
            NumberFormat().format(order.totalPrice),
            style: const TextStyle(fontSize: 19),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat().format(order.totalPrice),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: _getStatusColor(order),
                ),
              ),
              Text(
                _getStatusText(order),
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClosedOrderRow(PendingOrder order) {
    return Row(
      children: [
        _buildDataCell(
          DateFormat('dd.MM HH:mm').format(DateTime.parse(order.createdAt)),
          flex: 2,
        ),
        _buildDataCell(order.orderNumber.toString(), flex: 2),
        _buildDataCell(order.tableName.toString(), flex: 1),
        _buildDataCell(order.waiterName.toString(), flex: 2),
        _buildDataCell(order.items.length.toString(), flex: 1),
        _buildDataCell(
          NumberFormat.currency(decimalDigits: 0, symbol: '').format(order.totalPrice) + " so'm",
          flex: 2,
        ),
      ],
    );
  }

  Widget _buildDataCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget renderSelectedOrderInfo() {
    if (selectedOrder == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text("Zakaz tanlang", style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    final isClosedOrder = selectedDateRange == "closed";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: isClosedOrder ? Colors.black : Colors.green, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${isClosedOrder ? "To'lov kutilmoqda" : "Ochiq zakaz"}: ${selectedOrder!.formattedOrderNumber ?? selectedOrder!.orderNumber}",
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Text("Stol: ${selectedOrder!.tableName}", style: const TextStyle(fontSize: 18, color: Colors.black)),
          const SizedBox(height: 4),
          Text("Afitsant: ${selectedOrder!.waiterName}", style: const TextStyle(fontSize: 16, color: Colors.black)),
          if (selectedOrder!.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text("Taomlar:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ...selectedOrder!.items.map<Widget>((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text("${item["name"] ?? "N/A"} - ${item["quantity"] ?? 0} dona",
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              );
            }).toList(),
          ],
          const SizedBox(height: 12),
          Text(
            "Jami: ${NumberFormat().format(selectedOrder!.totalPrice)} so'm",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          if (isClosedOrder && selectedOrder!.mixedPaymentDetails != null) ...[
            const SizedBox(height: 12),
            Text(
              "To'lov: Naqd ${NumberFormat().format(selectedOrder!.mixedPaymentDetails!.cashAmount)} so'm, Karta ${NumberFormat().format(selectedOrder!.mixedPaymentDetails!.cardAmount)} so'm",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (selectedOrder!.mixedPaymentDetails!.changeAmount > 0)
              Text(
                "Qaytim: ${NumberFormat().format(selectedOrder!.mixedPaymentDetails!.changeAmount)} so'm",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentData = getCurrentData();
    final dateRangeButtons = [
      {"key": "open", "label": "Ochiq\nzakazlar ${openOrders.length}"},
      {"key": "closed", "label": "Yopilgan\nzakazlar ${closedOrders.length}"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Zakazlar boshqaruvi"),
      ),
      body: Stack(
        children: [
          Row(
            children: [
              Container(
                width: 260,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFF999999), width: 2)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: dateRangeButtons.map((btn) {
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedDateRange == btn["key"]
                                      ? const Color(0xFF28a745)
                                      : const Color(0xFFf5f5f5),
                                  foregroundColor:
                                  selectedDateRange == btn["key"] ? Colors.white : Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(0),
                                    side: const BorderSide(color: Color(0xFF999999), width: 1),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () => handleDateRangeChange(btn["key"] as String),
                                child: Text(
                                  btn["label"] as String,
                                  textAlign: TextAlign.center,
                                  style:
                                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, height: 1.2),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: "Qidiruv",
                          suffixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onChanged: (value) => setState(() => searchText = value),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFdddddd), width: 2),
                        color: const Color(0xFFf8f8f8),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Text(
                            selectedDateRange == "closed" ? "To'lov\nKutilmoqda" : "Ochiq\nZakazlar",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Jami"),
                              Text(currentData.length.toString()),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: SingleChildScrollView(child: renderSelectedOrderInfo())),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFd4d0c8),
                        border: Border.all(color: const Color(0xFFdddddd), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        selectedDateRange == "closed"
                            ? "YOPILGAN ZAKAZLAR (TO'LOV KUTILMOQDA)"
                            : "OCHIQ ZAKAZLAR",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Table headers for closed orders
                    if (selectedDateRange == "closed")
                      Container(
                        color: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            _buildHeaderCell('Data', flex: 2),
                            _buildHeaderCell('Order', flex: 2),
                            _buildHeaderCell('Table', flex: 1),
                            _buildHeaderCell('Waiter', flex: 2),
                            _buildHeaderCell('Items', flex: 1),
                            _buildHeaderCell('Total', flex: 2),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : errorMessage != null
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(errorMessage!),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _fetchData, child: const Text("Refresh")),
                            ],
                          ),
                        )
                            : currentData.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                selectedDateRange == "open"
                                    ? "Ochiq zakazlar yo'q"
                                    : "To'lov kutayotgan zakazlar yo'q",
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                  onPressed: _fetchData, child: const Text("Refresh")),
                            ],
                          ),
                        )
                            : RefreshIndicator(
                          onRefresh: _fetchData,
                          child: AnimatedList(
                            key: _listKey,
                            initialItemCount: currentData.length,
                            itemBuilder: (context, index, animation) {
                              return _buildOrderCard(currentData[index], index, animation);
                            },
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: const Color(0xFFe8e8e8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildActionButton(
                                text: "Chop etish",
                                onPressed: handlePrintReceipt,
                                isEnabled: selectedOrder != null,
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                text: "O'chirish",
                                onPressed: () => print("Deleting order ${selectedOrder?.id}"),
                                isEnabled: selectedOrder != null,
                              ),
                              const SizedBox(width: 8),
                              if (selectedDateRange == "open")
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedOrder != null
                                        ? const Color(0xFF28a745)
                                        : const Color(0xFFf5f5f5),
                                    foregroundColor:
                                    selectedOrder != null ? Colors.white : Colors.black,
                                    minimumSize: const Size(120, 70),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: Color(0xFF999999), width: 2),
                                    ),
                                    elevation: 2,
                                    shadowColor: Colors.black.withOpacity(0.2),
                                  ),
                                  onPressed: selectedOrder != null
                                      ? () => handleCloseOrder(
                                      openOrders.indexWhere((order) => order.id == selectedOrder!.id))
                                      : null,
                                  child: const Text("Zakazni yopish",
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                                )
                              else if (selectedDateRange == "closed" && selectedOrder != null)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007bff),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(120, 70),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: Color(0xFF999999), width: 2),
                                    ),
                                    elevation: 2,
                                    shadowColor: Colors.black.withOpacity(0.2),
                                  ),
                                  onPressed: handleOpenPaymentModal,
                                  child: const Text("To'lovni qabul qilish",
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildActionButton(
                                  text: "Orqaga", onPressed: () => Navigator.pop(context)),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                  text: "Chiqish", onPressed: () => Navigator.pop(context)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isPaymentModalVisible && selectedOrder != null)
            PaymentModal(
              visible: isPaymentModalVisible,
              onClose: () => setState(() => isPaymentModalVisible = false),
              selectedOrder: selectedOrder?.toJson(),
              onPaymentSuccess: handlePaymentSuccess,
              processPayment: processPaymentHandler,
              isProcessing: isLoading,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
    bool isEnabled = true,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFf5f5f5),
        foregroundColor: Colors.black,
        minimumSize: const Size(120, 70),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF999999), width: 2),
        ),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.2),
      ),
      onPressed: isEnabled ? onPressed : null,
      child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
    );
  }

  Color _getStatusColor(PendingOrder order) {
    if (selectedDateRange == "closed") return const Color(0xFFdc3545);
    switch (order.status) {
      case "pending":
        return const Color(0xFF1890ff);
      case "preparing":
        return const Color(0xFFfa8c16);
      case "ready":
        return const Color(0xFF52c41a);
      case "served":
        return const Color(0xFF722ed1);
      default:
        return const Color(0xFF1890ff);
    }
  }

  String _getStatusText(PendingOrder order) {
    if (selectedDateRange == "closed") return "To'lov kerak";
    switch (order.status) {
      case "pending":
        return "Yangi";
      case "preparing":
        return "Tayyorlanmoqda";
      case "ready":
        return "Tayyor";
      case "served":
        return "Berildi";
      default:
        return order.status;
    }
  }
}

class PaymentModal extends StatefulWidget {
  final bool visible;
  final VoidCallback onClose;
  final Map<String, dynamic>? selectedOrder;
  final Function(Map<String, dynamic>) onPaymentSuccess;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) processPayment;
  final bool isProcessing;

  const PaymentModal({
    Key? key,
    required this.visible,
    required this.onClose,
    this.selectedOrder,
    required this.onPaymentSuccess,
    required this.processPayment,
    required this.isProcessing,
  }) : super(key: key);

  @override
  _PaymentModalState createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  String _paymentMethod = 'cash';
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _paymentAmountController = TextEditingController();
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _cardAmountController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(decimalDigits: 0, symbol: '');
  double _paymentAmount = 0;
  double _changeAmount = 0;
  double _cashAmount = 0;
  double _cardAmount = 0;

  @override
  void initState() {
    super.initState();
    _resetForm();
  }

  @override
  void didUpdateWidget(covariant PaymentModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && widget.selectedOrder != oldWidget.selectedOrder) {
      _resetForm();
    }
  }

  double get _orderTotal {
    return (widget.selectedOrder?['total_price'] ??
        widget.selectedOrder?['finalTotal'] ??
        widget.selectedOrder?['final_total'] ??
        0)
        .toDouble();
  }

  void _resetForm() {
    if (widget.selectedOrder == null) return;
    final total = _orderTotal;
    setState(() {
      _paymentMethod = 'cash';
      _paymentAmount = total;
      _changeAmount = 0;
      _cashAmount = total / 2;
      _cardAmount = total / 2;
      _notesController.clear();
      _paymentAmountController.text = total.toStringAsFixed(0);
      _cashAmountController.text = (total / 2).toStringAsFixed(0);
      _cardAmountController.text = (total / 2).toStringAsFixed(0);
    });
  }

  void _handlePaymentMethodChange(String? method) {
    if (method == null) return;
    setState(() {
      _paymentMethod = method;
      if (method == 'cash') {
        _paymentAmount = _orderTotal;
        _paymentAmountController.text = _orderTotal.toStringAsFixed(0);
        _changeAmount = 0;
      } else if (['card', 'click'].contains(method)) {
        _paymentAmount = _orderTotal;
        _paymentAmountController.text = _orderTotal.toStringAsFixed(0);
        _changeAmount = 0;
      } else if (method == 'mixed') {
        _cashAmount = (_orderTotal / 2).roundToDouble();
        _cardAmount = _orderTotal - _cashAmount;
        _cashAmountController.text = _cashAmount.toStringAsFixed(0);
        _cardAmountController.text = _cardAmount.toStringAsFixed(0);
        _changeAmount = 0;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    Map<String, dynamic> paymentData = {
      'paymentMethod': _paymentMethod,
      'notes': _notesController.text,
    };

    if (_paymentMethod == 'mixed') {
      final totalAmount = _cashAmount + _cardAmount;
      if (_cashAmount <= 0 || _cardAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aralash to\'lov uchun naqd va karta summasi 0 dan katta bo\'lishi kerak!')),
        );
        return;
      }
      if (totalAmount < _orderTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'To\'lov summasi yetarli emas! Kerak: ${_currencyFormat.format(_orderTotal)}, Kiritildi: ${_currencyFormat.format(totalAmount)}')),
        );
        return;
      }
      paymentData['mixedPayment'] = {
        'cashAmount': _cashAmount,
        'cardAmount': _cardAmount,
        'totalAmount': totalAmount,
        'changeAmount': _changeAmount,
      };
      paymentData['paymentAmount'] = totalAmount;
      paymentData['changeAmount'] = _changeAmount;
    } else {
      if (_paymentAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('To\'lov summasi 0 dan katta bo\'lishi kerak!')),
        );
        return;
      }
      if (_paymentMethod == 'cash' && _paymentAmount < _orderTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Naqd to\'lov summasi yetarli emas! Kerak: ${_currencyFormat.format(_orderTotal)}, Kiritildi: ${_currencyFormat.format(_paymentAmount)}')),
        );
        return;
      }
      paymentData['paymentAmount'] = _paymentAmount;
      paymentData['changeAmount'] = _changeAmount;
    }

    final apiPayload = {
      'orderId': widget.selectedOrder!['_id'] ?? widget.selectedOrder!['id'],
      'paymentData': paymentData,
    };

    final result = await widget.processPayment(apiPayload);
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To\'lov muvaffaqiyatli qabul qilindi!')),
      );
      _resetForm();
      widget.onClose();
      widget.onPaymentSuccess(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'To\'lov qabul qilishda xatolik!')),
      );
    }
  }

  Widget _buildMixedPaymentValidation() {
    final total = _cashAmount + _cardAmount;
    final isValid = total >= _orderTotal;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? const Color(0xFFd4edda) : const Color(0xFFf8d7da),
        border: Border.all(color: isValid ? const Color(0xFFc3e6cb) : const Color(0xFFf5c6cb)),
        borderRadius: BorderRadius.circular(4),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Jami to\'lov:'),
              Text('${_currencyFormat.format(total)} so\'m', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kerakli summa:'),
              Text('${_currencyFormat.format(_orderTotal)} so\'m'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(total >= _orderTotal ? '✅ Yetarli' : '❌ Yetarli emas'),
              Text(
                _currencyFormat.format(total - _orderTotal),
                style: TextStyle(color: total >= _orderTotal ? Colors.green : Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFf0f8f0),
        border: Border.all(color: const Color(0xFFb7eb8f)),
        borderRadius: BorderRadius.circular(6),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Zakaz summasi:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${_currencyFormat.format(_orderTotal)} so\'m', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          if (_paymentMethod == 'mixed') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Naqd:'),
                Text('${_currencyFormat.format(_cashAmount)} so\'m'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Karta:'),
                Text('${_currencyFormat.format(_cardAmount)} so\'m'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Jami to\'lov:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${_currencyFormat.format(_cashAmount + _cardAmount)} so\'m',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('To\'lov usuli:'),
                Text(_paymentMethod == 'cash'
                    ? '💵 Naqd'
                    : _paymentMethod == 'card'
                    ? '💳 Karta'
                    : '📱 Click'),
              ],
            ),
          ],
          if (_changeAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Qaytim:', style: TextStyle(color: Color(0xFF52c41a), fontWeight: FontWeight.bold)),
                Text('${_currencyFormat.format(_changeAmount)} so\'m',
                    style: const TextStyle(color: Color(0xFF52c41a), fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    const Text('💰 TO\'LOV QABUL QILISH',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Zakaz #${widget.selectedOrder?['formatted_order_number'] ?? widget.selectedOrder?['orderNumber']}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFf8f9fa), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Zakaz summasi:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${_currencyFormat.format(_orderTotal)} so\'m',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF28a745))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('To\'lov usuli', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: [
                    ChoiceChip(
                      label: const Text('💵 Naqd'),
                      selected: _paymentMethod == 'cash',
                      onSelected: (selected) {
                        if (selected) _handlePaymentMethodChange('cash');
                      },
                    ),
                    ChoiceChip(
                      label: const Text('💳 Karta'),
                      selected: _paymentMethod == 'card',
                      onSelected: (selected) {
                        if (selected) _handlePaymentMethodChange('card');
                      },
                    ),
                    ChoiceChip(
                      label: const Text('📱 Click'),
                      selected: _paymentMethod == 'click',
                      onSelected: (selected) {
                        if (selected) _handlePaymentMethodChange('click');
                      },
                    ),
                    ChoiceChip(
                      label: const Text('🔄 Aralash'),
                      selected: _paymentMethod == 'mixed',
                      onSelected: (selected) {
                        if (selected) _handlePaymentMethodChange('mixed');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_paymentMethod != 'mixed')
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('To\'lov summasi'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _paymentAmountController,
                              keyboardType: TextInputType.number,
                              enabled: !['card', 'click'].contains(_paymentMethod),
                              decoration: const InputDecoration(hintText: 'Summa', border: OutlineInputBorder()),
                              validator: (value) {
                                final amount = double.tryParse(value ?? '') ?? 0;
                                if (amount <= 0) return 'To\'lov summasi 0 dan katta bo\'lishi kerak!';
                                if (_paymentMethod == 'cash' && amount < _orderTotal) {
                                  return 'Naqd to\'lov summasi yetarli emas!';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                final amount = double.tryParse(value ?? '') ?? 0;
                                setState(() {
                                  _paymentAmount = amount;
                                  if (_paymentMethod == 'cash') {
                                    _changeAmount = (amount - _orderTotal).clamp(0, double.infinity);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_paymentMethod == 'cash')
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Qaytim'),
                              const SizedBox(height: 8),
                              TextFormField(
                                enabled: false,
                                initialValue: _changeAmount.toStringAsFixed(0),
                                decoration: const InputDecoration(hintText: 'Qaytim', border: OutlineInputBorder()),
                              ),
                            ],
                          ),
                        )
                      else if (['card', 'click'].contains(_paymentMethod))
                        Expanded(
                          flex: 6,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFe6f7ff),
                              border: Border.all(color: const Color(0xFF91d5ff)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _paymentMethod == 'card' ? '💳 Karta to\'lov - aniq summa' : '📱 Click to\'lov - aniq summa',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF0050b3)),
                            ),
                          ),
                        ),
                    ],
                  ),
                if (_paymentMethod == 'mixed') ...[
                  const Divider(),
                  const Text('Aralash to\'lov (Naqd + Karta)'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Naqd summa'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _cashAmountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'Naqd', border: OutlineInputBorder()),
                              validator: (value) {
                                final amount = double.tryParse(value ?? '') ?? 0;
                                if (amount <= 0) return 'Naqd summa 0\'dan katta bo\'lishi kerak!';
                                return null;
                              },
                              onChanged: (value) {
                                final amount = double.tryParse(value ?? '') ?? 0;
                                setState(() {
                                  _cashAmount = amount;
                                  final total = amount + _cardAmount;
                                  _changeAmount = (total - _orderTotal).clamp(0, double.infinity);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Karta summa'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _cardAmountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'Karta', border: OutlineInputBorder()),
                              validator: (value) {
                                final amount = double.tryParse(value ?? '') ?? 0;
                                if (amount <= 0) return 'Karta summa 0\'dan katta bo\'lishi kerak!';
                                return null;
                              },
                              onChanged: (value) {
                                final amount = double.tryParse(value ?? '') ?? 0;
                                setState(() {
                                  _cardAmount = amount;
                                  final total = _cashAmount + amount;
                                  _changeAmount = (total - _orderTotal).clamp(0, double.infinity);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Qaytim'),
                            const SizedBox(height: 8),
                            TextFormField(
                              enabled: false,
                              initialValue: _changeAmount.toStringAsFixed(0),
                              decoration: const InputDecoration(hintText: 'Qaytim', border: OutlineInputBorder()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMixedPaymentValidation(),
                ],
                const SizedBox(height: 16),
                const Text('Izohlar'),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  maxLength: 200,
                  decoration: const InputDecoration(
                      hintText: 'To\'lov haqida qo\'shimcha ma\'lumot...', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                _buildPaymentSummary(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _resetForm();
                          widget.onClose();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('❌ Bekor qilish'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.isProcessing ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF28a745),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(widget.isProcessing ? '⏳ Qayta ishlanmoqda...' : '✅ To\'lovni qabul qilish'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _paymentAmountController.dispose();
    _cashAmountController.dispose();
    _cardAmountController.dispose();
    super.dispose();
  }
}