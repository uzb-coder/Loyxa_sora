import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'Kassir/Page/Kassr_page.dart';




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
      print('Login xatosi: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      print('Autentifikatsiya xatosi: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPendingOrders() async {
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
        print('Qaytgan ma\'lumot: $data'); // Log qo‘shish
        return List<Map<String, dynamic>>.from(data['pending_orders'] ?? []);
      }
      print('Buyurtmalarni olish xatosi: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      print('Buyurtmalarni olish xatosi: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> processPayment(String orderId, Map<String, dynamic> paymentData) async {
    if (_token == null) {
      final success = await authenticate();
      if (!success) return {'success': false, 'message': 'Autentifikatsiya xatosi'};
    }

    try {
      print('Yuborilayotgan paymentData: $paymentData'); // Log qilish
      final response = await http.post(
        Uri.parse('$baseUrl/kassir/payment/$orderId'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(paymentData),
      );

      print('Server javobi: ${response.body}'); // Server javobini log qilish
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'To‘lov muvaffaqiyatli qayta ishlandi',
          'data': data,
        };
      }
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'To‘lovni qayta ishlashda xatolik: ${response.statusCode} - ${response.body}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'To‘lovni qayta ishlashda xatolik: $e',
      };
    }
  }
}



class PendingOrdersPage extends StatefulWidget {
  @override
  _PendingOrdersPageState createState() => _PendingOrdersPageState();
}

class _PendingOrdersPageState extends State<PendingOrdersPage> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  bool isPaymentModalVisible = false;
  Map<String, dynamic>? selectedOrder;
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    setState(() {
      isLoading = true;
    });

    final fetchedOrders = await apiService.fetchPendingOrders();
    setState(() {
      orders = fetchedOrders;
      isLoading = false;
    });
  }

  void handlePaymentSuccess(Map<String, dynamic> result) {
    if (selectedOrder != null) {
      final index = orders.indexWhere((order) => order['_id'] == selectedOrder!['_id']);
      if (index != -1) {
        print('O‘chirilayotgan zakaz ID: ${selectedOrder!['_id']}'); // Log qo‘shish
        final removedOrder = orders.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
              (context, animation) => _buildOrderRow(removedOrder, index, animation),
          duration: Duration(milliseconds: 300),
        );
      } else {
        print('Xato: Zakaz topilmadi, ID: ${selectedOrder!['_id']}'); // Log qo‘shish
      }
      // Ro‘yxatni serverdan yangilash
      loadOrders().then((_) {
        setState(() {
          selectedOrder = null;
          isPaymentModalVisible = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('To‘lov muvaffaqiyatli qabul qilindi!')),
        );
      });
    }
  }

  Future<Map<String, dynamic>> processPaymentHandler(Map<String, dynamic> apiPayload) async {
    setState(() {
      isLoading = true;
    });

    // paymentData ni Map<String, dynamic> sifatida aniq shakllantirish
    Map<String, dynamic> paymentData = {
      'orderId': selectedOrder?['_id']?.toString() ?? '', // selectedOrder dan orderId ni olamiz
    };

    // paymentData ga boshqa maydonlarni qo'shish
    if (apiPayload['paymentData'] != null && apiPayload['paymentData'] is Map) {
      (apiPayload['paymentData'] as Map).forEach((key, value) {
        paymentData[key.toString()] = value; // Kalitlarni String ga aylantirish
      });
    } else {
      print('Xato: paymentData noto‘g‘ri formatda yoki null: $apiPayload');
      paymentData['error'] = 'Invalid payment data format';
    }

    print('Yuborilayotgan paymentData: $paymentData'); // Log qilish
    final result = await apiService.processPayment(selectedOrder?['_id']?.toString() ?? '', paymentData);
    setState(() {
      isLoading = false;
    });
    return result;
  }

  Widget _buildOrderRow(Map<String, dynamic> order, int index, Animation<double> animation) {
    final isSelected = selectedOrder != null && selectedOrder!['_id'] == order['_id'];
    return SizeTransition(
      sizeFactor: animation,
      child: InkWell(
        onTap: () {
          setState(() {
            selectedOrder = order;
            isPaymentModalVisible = true;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            color: isSelected ? Color(0xFFd4edda) : Colors.white,
          ),
          child: Row(
            children: [
              _buildDataCell(
                DateFormat('dd.MM HH:mm').format(DateTime.parse(order['completedAt'].toString())),
                flex: 2,
              ),
              _buildDataCell(order['orderNumber'].toString(), flex: 2),
              _buildDataCell(order['tableNumber'].toString(), flex: 1),
              _buildDataCell(order['waiterName'].toString(), flex: 2),
              _buildDataCell(order['itemsCount'].toString(), flex: 1),
              _buildDataCell(
                NumberFormat.currency(decimalDigits: 0, symbol: '').format(order['finalTotal']) + " so'm",
                flex: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
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

  Widget renderSelectedOrderInfo() {
    if (selectedOrder == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text("Zakaz tanlang", style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "To'lov kutilmoqda: ${selectedOrder!['formatted_order_number'] ?? selectedOrder!['orderNumber']}",
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Text("Stol: ${selectedOrder!['tableNumber']}", style: const TextStyle(fontSize: 18, color: Colors.black)),
          const SizedBox(height: 4),
          Text("Afitsant: ${selectedOrder!['waiterName']}", style: const TextStyle(fontSize: 16, color: Colors.black)),
          if (selectedOrder!['items'] != null && selectedOrder!['items'].isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text("Taomlar:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ...selectedOrder!['items'].map<Widget>((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text("${item['name'] ?? 'N/A'} - ${item['quantity'] ?? 0} dona",
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              );
            }).toList(),
          ],
          const SizedBox(height: 12),
          Text(
            "Jami: ${NumberFormat.currency(decimalDigits: 0, symbol: '').format(selectedOrder!['finalTotal'])} so'm",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pending Orders')),
      body: Stack(
        children: [
          Row(
            children: [
              // Yon oyna (Sidebar)
              Container(
                width: 260,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFF999999), width: 2)),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFdddddd), width: 2),
                        color: const Color(0xFFf8f8f8),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Tanlangan Zakaz",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Jami buyurtmalar"),
                              Text(orders.length.toString()),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: SingleChildScrollView(child: renderSelectedOrderInfo())),
                  ],
                ),
              ),
              // Asosiy content
              Expanded(
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      color: Colors.grey[300],
                      padding: EdgeInsets.symmetric(vertical: 10),
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
                    // Table Body AnimatedList
                    Expanded(
                      child: isLoading
                          ? Center(child: CircularProgressIndicator())
                          : orders.isEmpty
                          ? Center(child: Text('To‘lov kutayotgan zakazlar yo‘q'))
                          : RefreshIndicator(
                        onRefresh: loadOrders,
                        child: AnimatedList(
                          key: _listKey,
                          initialItemCount: orders.length,
                          itemBuilder: (context, index, animation) {
                            return _buildOrderRow(orders[index], index, animation);
                          },
                        ),
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
              onClose: () => setState(() {
                isPaymentModalVisible = false;
                selectedOrder = null;
              }),
              selectedOrder: selectedOrder,
              onPaymentSuccess: handlePaymentSuccess,
              processPayment: processPaymentHandler,
              isProcessing: isLoading,
            ),
        ],
      ),
    );
  }
}