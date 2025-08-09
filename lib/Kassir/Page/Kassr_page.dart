import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PendingOrder {
  final String id;
  final String orderNumber;
  final String? formattedOrderNumber;
  final String? tableName;
  final String? waiterName;
  final double totalPrice;
  final String status;
  final String createdAt;
  final List<Map<String, dynamic>> items;
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
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? json['formatted_order_number']?.toString() ?? '',
      formattedOrderNumber: json['formatted_order_number']?.toString() ?? json['orderNumber']?.toString(),
      tableName: json['table_number']?.toString() ??
          json['tableNumber']?.toString() ??
          json['table_id']?['name']?.toString() ??
          'N/A',
      waiterName: json['waiter_name']?.toString() ??
          json['waiterName']?.toString() ??
          json['user_id']?['first_name']?.toString() ??
          'N/A',
      totalPrice: (json['total_price'] ?? json['finalTotal'] ?? json['final_total'] ?? 0).toDouble(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['createdAt']?.toString() ?? json['completedAt']?.toString() ?? DateTime.now().toIso8601String(),
      items: (json['items'] as List<dynamic>?)?.map((item) => {
        'name': item['name']?.toString() ?? 'N/A',
        'quantity': item['quantity'] ?? 0,
        'price': item['price'] ?? 0,
        'printer_ip': item['printer_ip']?.toString(),
      }).toList() ?? [],
      mixedPaymentDetails: json['mixedPaymentDetails'] != null
          ? MixedPaymentDetails.fromJson(json['mixedPaymentDetails'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
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

  factory MixedPaymentDetails.fromJson(Map<String, dynamic> json) => MixedPaymentDetails(
    breakdown: Breakdown.fromJson(json['breakdown'] as Map<String, dynamic>? ?? {}),
    cashAmount: (json['cashAmount'] ?? 0).toDouble(),
    cardAmount: (json['cardAmount'] ?? 0).toDouble(),
    totalAmount: (json['totalAmount'] ?? 0).toDouble(),
    changeAmount: (json['changeAmount'] ?? 0).toDouble(),
    timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'breakdown': breakdown.toJson(),
    'cashAmount': cashAmount,
    'cardAmount': cardAmount,
    'totalAmount': totalAmount,
    'changeAmount': changeAmount,
    'timestamp': timestamp.toIso8601String(),
  };
}

class Breakdown {
  final String cashPercentage;
  final String cardPercentage;

  Breakdown({
    required this.cashPercentage,
    required this.cardPercentage,
  });

  factory Breakdown.fromJson(Map<String, dynamic> json) => Breakdown(
    cashPercentage: json['cash_percentage']?.toString() ?? '0.0',
    cardPercentage: json['card_percentage']?.toString() ?? '0.0',
  );

  Map<String, dynamic> toJson() => {
    'cash_percentage': cashPercentage,
    'card_percentage': cardPercentage,
  };
}

class ApiService {
  static const String baseUrl = 'https://sora-b.vercel.app/api';
  String? _token;
  static final Map<String, List<PendingOrder>> _cache = {};

  Future<void> sendToPrinter(String printerIP, String orderId) async {
    try {
      final response = await http.post(
        Uri.parse('http://$printerIP:9100/'),
        headers: {'Content-Type': 'text/plain'},
        body: 'Order #$orderId Closed\n',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Printed to $printerIP');
      } else {
        debugPrint('Printer Error at $printerIP: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending to printer $printerIP: $e');
    }
  }

  Future<List<PendingOrder>> fetchPendingOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // 🧠 tokenni olish
    const cacheKey = 'pending_orders';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/my-pending'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orders = (data is Map && data['orders'] is List
            ? data['orders'] as List
            : data is List
            ? data
            : [])
            .map((orderJson) => PendingOrder.fromJson(orderJson as Map<String, dynamic>))
            .toList();
        _cache[cacheKey] = orders;
        return orders;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching pending orders: $e');
      return [];
    }
  }

  Future<List<PendingOrder>> fetchClosedOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // 🧠 tokenni olish
    const cacheKey = 'closed_orders';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }


    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/pending-payments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orders = (data is Map && data['pending_orders'] is List
            ? data['pending_orders'] as List
            : data is List
            ? data
            : [])
            .map((orderJson) => PendingOrder.fromJson(orderJson as Map<String, dynamic>))
            .toList();
        _cache[cacheKey] = orders;
        return orders;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching closed orders: $e');
      return [];
    }
  }

  Future<bool> closeOrder(String orderId, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // 🧠 tokenni olish


    try {
      final response = await http.put(
        Uri.parse('$baseUrl/orders/close/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final uniquePrinterIPs = items
            .map((item) => item['printer_ip'] as String?)
            .where((ip) => ip != null)
            .toSet()
            .toList();
        await Future.wait(uniquePrinterIPs.map((ip) => sendToPrinter(ip!, orderId)));
        _cache.clear(); // Invalidate cache
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error closing order: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> processPayment(String orderId, Map<String, dynamic> paymentData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // 🧠 tokenni olish

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/kassir/payment/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(paymentData),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _cache.clear(); // Invalidate cache
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Payment processed successfully',
          'data': data,
        };
      }
      return {
        'success': false,
        'message': data['message']?.toString() ?? 'Payment processing failed',
      };
    } catch (e) {
      debugPrint('Error processing payment: $e');
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
  State<UnifiedPendingPaymentsPage> createState() => _UnifiedPendingPaymentsPageState();
}

class _UnifiedPendingPaymentsPageState extends State<UnifiedPendingPaymentsPage> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  String selectedDateRange = 'open';
  String searchText = '';
  Timer? _debounce;
  PendingOrder? selectedOrder;
  bool isPaymentModalVisible = false;
  bool isLoading = true;
  String? errorMessage;
  List<PendingOrder> openOrders = [];
  List<PendingOrder> closedOrders = [];
  final ApiService apiService = ApiService();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchData(showLoading: true);
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) => _pollData());
  }

  Future<void> _pollData() async {
    ApiService._cache.clear();
    await _fetchData(showLoading: false);
  }

  Future<void> _fetchData({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final pendingOrders = await apiService.fetchPendingOrders();
      final closedOrdersData = await apiService.fetchClosedOrders();

      if (!mounted) return;

      setState(() {
        _updateList(openOrders, pendingOrders, selectedDateRange == 'open');
        _updateList(closedOrders, closedOrdersData, selectedDateRange == 'closed');
        if (showLoading) {
          isLoading = false;
        }
        if (openOrders.isEmpty && closedOrders.isEmpty) {
          errorMessage = 'No orders found';
        } else {
          errorMessage = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (showLoading) {
          isLoading = false;
        }
        errorMessage = 'Failed to load orders: $e';
      });
    }
  }

  void _updateList(List<PendingOrder> current, List<PendingOrder> newData, bool isSelected) {
    if (!isSelected) {
      current.clear();
      current.addAll(newData);
      return;
    }

    // Remove removed orders
    Map<String, int> currentIds = {};
    for (int i = 0; i < current.length; i++) {
      currentIds[current[i].id] = i;
    }

    List<int> toRemove = [];
    for (var entry in currentIds.entries) {
      if (!newData.any((o) => o.id == entry.key)) {
        toRemove.add(entry.value);
      }
    }
    toRemove.sort((a, b) => b.compareTo(a)); // Remove from end to start

    for (var index in toRemove) {
      var removed = current.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
            (context, animation) => _buildOrderCard(removed, index, animation),
        duration: const Duration(milliseconds: 300),
      );
    }

    // Add new orders at the end
    for (var order in newData) {
      if (!currentIds.containsKey(order.id)) {
        current.add(order);
        _listKey.currentState?.insertItem(
          current.length - 1,
          duration: const Duration(milliseconds: 300),
        );
      }
    }
  }

  void _handleDateRangeChange(String key) {
    if (!mounted) return;
    setState(() {
      selectedDateRange = key;
      selectedOrder = null;
      searchText = '';
    });
  }

  void _handleSearch(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => searchText = value);
    });
  }

  void _handlePrintReceipt() {
    if (selectedOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avval zakazni tanlang!'), duration: Duration(seconds: 2)),
      );
      return;
    }
    debugPrint('Printing receipt for order ${selectedOrder!.formattedOrderNumber}');
  }

  void _handleCloseOrder(int index) async {
    if (selectedOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avval zakazni tanlang!'), duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() => isLoading = true);

    final success = await apiService.closeOrder(selectedOrder!.id, selectedOrder!.items);
    if (!mounted) return;
    setState(() {
      if (success) {
        final removedOrder = openOrders.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
              (context, animation) => _buildOrderCard(removedOrder, index, animation),
          duration: const Duration(milliseconds: 200),
        );
        selectedOrder = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order closed!'), duration: Duration(seconds: 2)),
        );
      } else {
        errorMessage = 'Failed to close order';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to close order'), duration: Duration(seconds: 2)),
        );
      }
      isLoading = false;
    });
    _fetchData(showLoading: false);
  }

  void _handleOpenPaymentModal() {
    if (selectedOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avval zakazni tanlang!'), duration: Duration(seconds: 2)),
      );
      return;
    }
    setState(() => isPaymentModalVisible = true);
  }

  Future<Map<String, dynamic>> _processPaymentHandler(Map<String, dynamic> apiPayload) async {
    setState(() => isLoading = true);
    final result = await apiService.processPayment(selectedOrder!.id, apiPayload['paymentData'] as Map<String, dynamic>);
    if (!mounted) return result;
    setState(() => isLoading = false);
    return result;
  }

  void _handlePaymentSuccess(Map<String, dynamic> result) {
    if (!mounted || selectedOrder == null) return;
    final index = closedOrders.indexWhere((order) => order.id == selectedOrder!.id);
    if (index != -1) {
      final removedOrder = closedOrders.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
            (context, animation) => _buildOrderCard(removedOrder, index, animation),
        duration: const Duration(milliseconds: 200),
      );
    }
    setState(() {
      selectedOrder = null;
      isPaymentModalVisible = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("To'lov muvaffaqiyatli qabul qilindi!"), duration: Duration(seconds: 2)),
    );
    _fetchData(showLoading: false);
  }

  List<PendingOrder> _getCurrentData() {
    final currentData = selectedDateRange == 'open' ? openOrders : closedOrders;
    if (searchText.isEmpty) return currentData;
    final searchLower = searchText.toLowerCase();
    return currentData.where((order) {
      return order.orderNumber.toLowerCase().contains(searchLower) ||
          order.formattedOrderNumber?.toLowerCase().contains(searchLower) == true ||
          order.tableName?.toLowerCase().contains(searchLower) == true ||
          order.waiterName?.toLowerCase().contains(searchLower) == true ||
          NumberFormat().format(order.totalPrice).contains(searchLower);
    }).toList();
  }

  Widget _buildOrderCard(PendingOrder order, int index, Animation<double> animation) {
    final isSelected = selectedOrder?.id == order.id;
    final rowColor = isSelected
        ? const Color(0xFFd4edda)
        : selectedDateRange == 'closed'
        ? const Color(0xFFffe6e6)
        : _getStatusColor(order);

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
          child: selectedDateRange == 'open' ? _buildOpenOrderRow(order) : _buildClosedOrderRow(order),
        ),
      ),
    );
  }

  Widget _buildOpenOrderRow(PendingOrder order) {
    final createdAt = DateTime.parse(order.createdAt);
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Column(
            children: [
              Text(DateFormat('dd.MM').format(createdAt), style: const TextStyle(fontSize: 18)),
              Text(DateFormat('HH:mm').format(createdAt), style: const TextStyle(fontSize: 18)),
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
            order.waiterName ?? 'N/A',
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(
          width: 100,
          child: Text(
            'Stol: ${order.tableName}',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
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
    final createdAt = DateTime.parse(order.createdAt);
    return Row(
      children: [
        _buildDataCell(DateFormat('dd.MM.yy').format(createdAt), flex: 1),
        _buildDataCell(DateFormat('HH:mm').format(createdAt), flex: 1),
        _buildDataCell(order.formattedOrderNumber ?? order.orderNumber, flex: 1),
        _buildDataCell(order.tableName ?? 'N/A', flex: 1),
        _buildDataCell(order.waiterName ?? 'N/A', flex: 1),
        _buildDataCell(order.items.length.toString(), flex: 1),
        _buildDataCell('${NumberFormat().format(order.totalPrice)} so\'m', flex: 2),
      ],
    );
  }

  Widget _buildDataCell(String text, {int flex = 1}) => Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
    ),
  );

  Widget _buildHeaderCell(String text, {int flex = 1}) => Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    ),
  );

  Widget _renderSelectedOrderInfo() {
    if (selectedOrder == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text('Zakaz tanlang', style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    final isClosedOrder = selectedDateRange == 'closed';
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
            '${isClosedOrder ? "To'lov kutilmoqda" : "Ochiq zakaz"}: ${selectedOrder!.formattedOrderNumber ?? selectedOrder!.orderNumber}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Stol: ${selectedOrder!.tableName}', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text('Afitsant: ${selectedOrder!.waiterName}', style: const TextStyle(fontSize: 16)),
          if (selectedOrder!.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Taomlar:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ...selectedOrder!.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${item["name"] ?? "N/A"} - ${item["quantity"] ?? 0} dona',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            )),
          ],
          const SizedBox(height: 12),
          Text(
            'Jami: ${NumberFormat().format(selectedOrder!.totalPrice)} so\'m',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (isClosedOrder && selectedOrder!.mixedPaymentDetails != null) ...[
            const SizedBox(height: 12),
            Text(
              'To\'lov: Naqd ${NumberFormat().format(selectedOrder!.mixedPaymentDetails!.cashAmount)} so\'m, '
                  'Karta ${NumberFormat().format(selectedOrder!.mixedPaymentDetails!.cardAmount)} so\'m',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (selectedOrder!.mixedPaymentDetails!.changeAmount > 0)
              Text(
                'Qaytim: ${NumberFormat().format(selectedOrder!.mixedPaymentDetails!.changeAmount)} so\'m',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentData = _getCurrentData();
    final dateRangeButtons = [
      {'key': 'open', 'label': 'Ochiq\nzakazlar ${openOrders.length}'},
      {'key': 'closed', 'label': 'Yopilgan\nzakazlar ${closedOrders.length}'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zakazlar boshqaruvi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ApiService._cache.clear();
              _fetchData(showLoading: true);
            },
          ),
        ],
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
                        children: dateRangeButtons.map((btn) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedDateRange == btn['key']
                                    ? const Color(0xFF28a745)
                                    : const Color(0xFFf5f5f5),
                                foregroundColor: selectedDateRange == btn['key'] ? Colors.white : Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(0),
                                  side: const BorderSide(color: Color(0xFF999999), width: 1),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => _handleDateRangeChange(btn['key'] as String),
                              child: Text(
                                btn['label'] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, height: 1.2),
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Qidiruv',
                          suffixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onChanged: _handleSearch,
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
                            selectedDateRange == 'closed' ? "To'lov\nKutilmoqda" : "Ochiq\nZakazlar",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Jami'),
                              Text(currentData.length.toString()),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: SingleChildScrollView(child: _renderSelectedOrderInfo())),
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
                        selectedDateRange == 'closed'
                            ? "YOPILGAN ZAKAZLAR (TO'LOV KUTILMOQDA)"
                            : "OCHIQ ZAKAZLAR",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (selectedDateRange == 'closed')
                      Container(
                        color: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            _buildHeaderCell('Sana', flex: 1),
                            _buildHeaderCell('Vaqt', flex: 1),
                            _buildHeaderCell('Zakaz', flex: 1),
                            _buildHeaderCell('Stol', flex: 1),
                            _buildHeaderCell('Ofitsiant', flex: 1),
                            _buildHeaderCell('Taomlar', flex: 1),
                            _buildHeaderCell('Jami', flex: 2),
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
                              ElevatedButton(onPressed: () {
                                ApiService._cache.clear();
                                _fetchData(showLoading: true);
                              }, child: const Text('Refresh')),
                            ],
                          ),
                        )
                            : currentData.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selectedDateRange == 'open'
                                    ? Icons.restaurant_menu
                                    : Icons.payment,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                selectedDateRange == 'open'
                                    ? "Hozircha ochiq zakazlar yo'q"
                                    : "To'lov kutayotgan zakazlar yo'q",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  ApiService._cache.clear();
                                  _fetchData(showLoading: true);
                                },
                                child: const Text('Yangilash'),
                              ),
                            ],
                          ),
                        )
                            : RefreshIndicator(
                          onRefresh: () async {
                            ApiService._cache.clear();
                            await _fetchData(showLoading: false);
                          },
                          child: AnimatedList(
                            key: _listKey,
                            initialItemCount: currentData.length,
                            itemBuilder: (context, index, animation) =>
                                _buildOrderCard(currentData[index], index, animation),
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
                                text: 'Chop etish',
                                onPressed: _handlePrintReceipt,
                                isEnabled: selectedOrder != null,
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                text: "O'chirish",
                                onPressed: () => debugPrint('Deleting order ${selectedOrder?.id}'),
                                isEnabled: selectedOrder != null,
                              ),
                              const SizedBox(width: 8),
                              if (selectedDateRange == 'open')
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedOrder != null
                                        ? const Color(0xFF28a745)
                                        : const Color(0xFFf5f5f5),
                                    foregroundColor: selectedOrder != null ? Colors.white : Colors.black,
                                    minimumSize: const Size(120, 70),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: Color(0xFF999999), width: 2),
                                    ),
                                    elevation: 2,
                                    shadowColor: Colors.black.withOpacity(0.2),
                                  ),
                                  onPressed: selectedOrder != null
                                      ? () => _handleCloseOrder(
                                    openOrders.indexWhere((order) => order.id == selectedOrder!.id),
                                  )
                                      : null,
                                  child: const Text(
                                    "Zakazni yopish",
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                  ),
                                )
                              else if (selectedDateRange == 'closed' && selectedOrder != null)
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
                                  onPressed: _handleOpenPaymentModal,
                                  child: const Text(
                                    "To'lovni qabul qilish",
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildActionButton(text: 'Orqaga', onPressed: () => Navigator.pop(context)),
                              const SizedBox(width: 8),
                              _buildActionButton(text: 'Выход', onPressed: () => Navigator.pop(context)),
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
              selectedOrder: selectedOrder!.toJson(),
              onPaymentSuccess: _handlePaymentSuccess,
              processPayment: _processPaymentHandler,
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
  }) =>
      ElevatedButton(
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

  Color _getStatusColor(PendingOrder order) {
    if (selectedDateRange == 'closed') return const Color(0xFFdc3545);
    switch (order.status) {
      case 'pending':
        return const Color(0xFF1890ff);
      case 'preparing':
        return const Color(0xFFfa8c16);
      case 'ready':
        return const Color(0xFF52c41a);
      case 'served':
        return const Color(0xFF722ed1);
      default:
        return const Color(0xFF1890ff);
    }
  }

  String _getStatusText(PendingOrder order) {
    if (selectedDateRange == 'closed') return "To'lov kerak";
    switch (order.status) {
      case 'pending':
        return 'Yangi';
      case 'preparing':
        return 'Tayyorlanmoqda';
      case 'ready':
        return 'Tayyor';
      case 'served':
        return 'Berildi';
      default:
        return order.status;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }
}

class PaymentModal extends StatefulWidget {
  final bool visible;
  final VoidCallback onClose;
  final Map<String, dynamic> selectedOrder;
  final Function(Map<String, dynamic>) onPaymentSuccess;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) processPayment;
  final bool isProcessing;

  const PaymentModal({
    super.key,
    required this.visible,
    required this.onClose,
    required this.selectedOrder,
    required this.onPaymentSuccess,
    required this.processPayment,
    required this.isProcessing,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
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

  double get _orderTotal => (widget.selectedOrder['total_price'] ??
      widget.selectedOrder['finalTotal'] ??
      widget.selectedOrder['final_total'] ??
      0)
      .toDouble();

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

  void _resetForm() {
    final total = _orderTotal;
    setState(() {
      _paymentMethod = 'cash';
      _paymentAmount = total;
      _changeAmount = 0;
      _cashAmount = total / 2;
      _cardAmount = total / 2;
      _notesController.clear();
      _paymentAmountController.text = _currencyFormat.format(total);
      _cashAmountController.text = _currencyFormat.format(total / 2);
      _cardAmountController.text = _currencyFormat.format(total / 2);
    });
  }

  void _handlePaymentMethodChange(String? method) {
    if (method == null || !mounted) return;
    setState(() {
      _paymentMethod = method;
      final total = _orderTotal;
      if (method == 'cash' || method == 'card' || method == 'click') {
        _paymentAmount = total;
        _paymentAmountController.text = _currencyFormat.format(total);
        _changeAmount = 0;
      } else if (method == 'mixed') {
        _cashAmount = total / 2;
        _cardAmount = total / 2;
        _cashAmountController.text = _currencyFormat.format(_cashAmount);
        _cardAmountController.text = _currencyFormat.format(_cardAmount);
        _changeAmount = 0;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || !mounted) return;

    final paymentData = <String, dynamic>{
      'paymentMethod': _paymentMethod,
      'notes': _notesController.text,
    };

    if (_paymentMethod == 'mixed') {
      final totalAmount = _cashAmount + _cardAmount;
      if (_cashAmount <= 0 || _cardAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aralash to'lov uchun naqd va karta summasi 0 dan katta bo'lishi kerak!")),
        );
        return;
      }
      if (totalAmount < _orderTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "To'lov summasi yetarli emas! Kerak: ${_currencyFormat.format(_orderTotal)}, Kiritildi: ${_currencyFormat.format(totalAmount)}",
            ),
          ),
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
          const SnackBar(content: Text("To'lov summasi 0 dan katta bo'lishi kerak!")),
        );
        return;
      }
      if (_paymentMethod == 'cash' && _paymentAmount < _orderTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Naqd to'lov summasi yetarli emas! Kerak: ${_currencyFormat.format(_orderTotal)}, Kiritildi: ${_currencyFormat.format(_paymentAmount)}",
            ),
          ),
        );
        return;
      }
      paymentData['paymentAmount'] = _paymentAmount;
      paymentData['changeAmount'] = _changeAmount;
    }

    final result = await widget.processPayment({'paymentData': paymentData});
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("To'lov muvaffaqiyatli qabul qilindi!"), duration: Duration(seconds: 2)),
      );
      _resetForm();
      widget.onClose();
      widget.onPaymentSuccess(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? "To'lov qabul qilishda xatolik!")),
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
              const Text("Jami to'lov:"),
              Text('${_currencyFormat.format(total)} so\'m', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Kerakli summa:"),
              Text('${_currencyFormat.format(_orderTotal)} so\'m'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isValid ? '✅ Yetarli' : '❌ Yetarli emas'),
              Text(
                _currencyFormat.format(total - _orderTotal),
                style: TextStyle(color: isValid ? Colors.green : Colors.red),
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
                Text(
                  '${_currencyFormat.format(_cashAmount + _cardAmount)} so\'m',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("To'lov usuli:"),
                Text(
                  _paymentMethod == 'cash'
                      ? '💵 Naqd'
                      : _paymentMethod == 'card'
                      ? '💳 Karta'
                      : '📱 Click',
                ),
              ],
            ),
          ],
          if (_changeAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Qaytim:', style: TextStyle(color: Color(0xFF52c41a), fontWeight: FontWeight.bold)),
                Text(
                  '${_currencyFormat.format(_changeAmount)} so\'m',
                  style: const TextStyle(color: Color(0xFF52c41a), fontWeight: FontWeight.bold),
                ),
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
                    const Text("💰 TO'LOV QABUL QILISH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Zakaz #${widget.selectedOrder['formatted_order_number'] ?? widget.selectedOrder['orderNumber']}',
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
                      Text(
                        '${_currencyFormat.format(_orderTotal)} so\'m',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF28a745)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text("To'lov usuli", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: [
                    ChoiceChip(
                      label: const Text('💵 Naqd'),
                      selected: _paymentMethod == 'cash',
                      onSelected: (selected) => _handlePaymentMethodChange('cash'),
                    ),
                    ChoiceChip(
                      label: const Text('💳 Karta'),
                      selected: _paymentMethod == 'card',
                      onSelected: (selected) => _handlePaymentMethodChange('card'),
                    ),
                    ChoiceChip(
                      label: const Text('📱 Click'),
                      selected: _paymentMethod == 'click',
                      onSelected: (selected) => _handlePaymentMethodChange('click'),
                    ),
                    ChoiceChip(
                      label: const Text('🔄 Aralash'),
                      selected: _paymentMethod == 'mixed',
                      onSelected: (selected) => _handlePaymentMethodChange('mixed'),
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
                            const Text("To'lov summasi"),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _paymentAmountController,
                              keyboardType: TextInputType.number,
                              enabled: !['card', 'click'].contains(_paymentMethod),
                              decoration: const InputDecoration(hintText: 'Summa', border: OutlineInputBorder()),
                              validator: (value) {
                                final amount = double.tryParse(value?.replaceAll(',', '') ?? '') ?? 0;
                                if (amount <= 0) return "To'lov summasi 0 dan katta bo'lishi kerak!";
                                if (_paymentMethod == 'cash' && amount < _orderTotal) {
                                  return "Naqd to'lov summasi yetarli emas!";
                                }
                                return null;
                              },
                              onChanged: (value) {
                                final amount = double.tryParse(value.replaceAll(',', '') ?? '') ?? 0;
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
                                initialValue: _currencyFormat.format(_changeAmount),
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
                              _paymentMethod == 'card' ? "💳 Karta to'lov - aniq summa" : "📱 Click to'lov - aniq summa",
                              style: const TextStyle(fontSize: 12, color: Color(0xFF0050b3)),
                            ),
                          ),
                        ),
                    ],
                  ),
                if (_paymentMethod == 'mixed') ...[
                  const Divider(),
                  const Text("Aralash to'lov (Naqd + Karta)"),
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
                                final amount = double.tryParse(value?.replaceAll(',', '') ?? '') ?? 0;
                                if (amount <= 0) return "Naqd summa 0'dan katta bo'lishi kerak!";
                                return null;
                              },
                              onChanged: (value) {
                                final amount = double.tryParse(value.replaceAll(',', '') ?? '') ?? 0;
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
                                final amount = double.tryParse(value?.replaceAll(',', '') ?? '') ?? 0;
                                if (amount <= 0) return "Karta summa 0'dan katta bo'lishi kerak!";
                                return null;
                              },
                              onChanged: (value) {
                                final amount = double.tryParse(value.replaceAll(',', '') ?? '') ?? 0;
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
                              initialValue: _currencyFormat.format(_changeAmount),
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
                    hintText: "To'lov haqida qo'shimcha ma'lumot...",
                    border: OutlineInputBorder(),
                  ),
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
                        child: const Text("❌ Bekor qilish"),
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
                        child: Text(widget.isProcessing ? "⏳ Qayta ishlanmoqda..." : "✅ To'lovni qabul qilish"),
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