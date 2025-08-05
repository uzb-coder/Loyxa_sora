import 'dart:convert';
import 'package:charset_converter/charset_converter.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';

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

// Asosiy rang sxemasi
class AppColors {
  static const primary = Color(0xFF0D5720);
  static const primaryLight = Color(0xFF0F6B28);
  static const primaryDark = Color(0xFF094019);
  static const secondary = Color(0xFF1B8332);
  static const accent = Color(0xFF22C55E);
  static const surface = Color(0xFFF8FAF9);
  static const white = Colors.white;
  static const grey = Color(0xFF6B7280);
  static const lightGrey = Color(0xFFF3F4F6);
  static const error = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);
}

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
  String? _token;

  Timer? _realTimeTimer;
  List<StolModel> _tables = [];
  Map<String, bool> _tableOccupiedStatus = {};
  bool _isLoadingTables = false;

  @override
  void initState() {
    super.initState();
    _initializeToken();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _realTimeTimer?.cancel();
    super.dispose();
  }

  void _startRealTimeUpdates() {
    _realTimeTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkTableStatuses();
    });
  }

  Future<void> _checkTableStatuses() async {
    if (_token == null) return;

    try {
      Map<String, bool> newTableStatus = {};

      await Future.wait(_tables.map((table) async {
        try {
          final response = await http.get(
            Uri.parse('https://sora-b.vercel.app/api/orders/table/${table.id}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
          ).timeout(const Duration(seconds: 2));

          if (response.statusCode == 200) {
            final List<dynamic> tableOrders = jsonDecode(response.body);
            bool isOccupied = tableOrders.any((order) => order['status'] == 'pending');
            newTableStatus[table.id] = isOccupied;
          } else {
            newTableStatus[table.id] = false;
          }
        } catch (e) {
          newTableStatus[table.id] = _tableOccupiedStatus[table.id] ?? false;
        }
      }));

      if (!_mapEquals(newTableStatus, _tableOccupiedStatus)) {
        if (mounted) {
          setState(() {
            _tableOccupiedStatus = newTableStatus;
          });
        }
      }
    } catch (e) {
      print("Stollar holatini tekshirishda xatolik: $e");
    }
  }

  bool _mapEquals(Map<String, bool> map1, Map<String, bool> map2) {
    if (map1.length != map2.length) return false;
    for (var key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }

  Future<void> _initializeToken() async {
    try {
      _token = await AuthService.getToken();
      if (_token == null) {
        await AuthService.loginAndPrintToken();
        _token = await AuthService.getToken();
      }
      if (_token != null) {
        _loadInitialTables();
      }
    } catch (e) {
      print("Token olishda xatolik: $e");
    }
  }

  Future<void> _loadInitialTables() async {
    if (mounted) {
      setState(() => _isLoadingTables = true);
    }

    try {
      final stolController = StolController();
      final tables = await stolController.fetchTables().timeout(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _tables = tables;
          _isLoadingTables = false;
        });
        _checkTableStatuses();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTables = false);
      }
    }
  }

  void _handleTableTap(String tableName, String tableId) {
    setState(() {
      _selectedTableName = tableName;
      _selectedTableId = tableId;
    });
    _fetchOrdersForTable(tableId);
  }

  Future<void> _fetchOrdersForTable(String tableId) async {
    if (_token == null) return;

    setState(() => _isLoadingOrders = true);

    try {
      final response = await http.get(
        Uri.parse("https://sora-b.vercel.app/api/orders/table/$tableId"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _selectedTableOrders = data
                .map((json) => Order.fromJson(json))
                .where((order) => order.status == 'pending')
                .toList();
            _isLoadingOrders = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedTableOrders = [];
            _isLoadingOrders = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedTableOrders = [];
          _isLoadingOrders = false;
        });
      }
    }
  }

  void _showOrderScreenDialog(String tableId) {
    bool isOccupied = _tableOccupiedStatus[tableId] ?? false;

    if (isOccupied) {
      _showSnackBar('Bu stol band! Yangi hisob ochib bo\'lmaydi.', AppColors.error);
      return;
    }

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
              _checkTableStatuses();
            },
          ),
        );
      },
    );
  }

  Future<void> _closeOrder(Order order) async {
    if (order.userId != widget.user.id) {
      _showSnackBar('Faqat o\'zingiz yaratgan zakazni yopa olasiz!', AppColors.error);
      return;
    }

    try {
      setState(() => order.isProcessing = true);

      bool success = await Zakazcontroller().closeOrder(order.id);

      if (success) {
        setState(() {
          _selectedTableOrders.removeWhere((o) => o.id == order.id);
        });
        _checkTableStatuses();
        _showSnackBar('Zakaz muvaffaqiyatli yopildi', AppColors.accent);
      } else {
        _showSnackBar('Zakazni yopishda xatolik yuz berdi', AppColors.error);
      }
    } catch (e) {
      _showSnackBar('Xatolik yuz berdi: $e', AppColors.error);
    } finally {
      if (mounted) {
        setState(() => order.isProcessing = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth >= 600 && screenWidth <= 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Softer off-white background
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isDesktop ? 70 : 60),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.user.firstName,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildHeaderButton(
                  onPressed: () {
                    if (_selectedTableId != null) {
                      bool isOccupied = _tableOccupiedStatus[_selectedTableId] ?? false;
                      if (isOccupied) {
                        _showSnackBar('$_selectedTableName band! Yangi hisob ochib bo\'lmaydi.', AppColors.error);
                      } else {
                        _showOrderScreenDialog(_selectedTableId!);
                      }
                    } else {
                      _showSnackBar('Avval stolni tanlang!', AppColors.warning);
                    }
                  },
                  icon: Icons.add_circle_outline,
                  label: _selectedTableName != null
                      ? "Yangi hisob : $_selectedTableName - Stol"
                      : "Yangi hisob",
                  isPrimary: true,
                ),
                const SizedBox(width: 12),
                _buildHeaderButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailsPage(waiterName: widget.user.firstName),
                      ),
                    );
                  },
                  icon: Icons.check_circle_outline,
                  label: "Yopilgan hisoblar",
                  isPrimary: false,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: _buildTablesGrid(isDesktop, isTablet),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: _buildOrderDetails(isDesktop),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primary : AppColors.secondary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: AppColors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildTablesGrid(bool isDesktop, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_restaurant, color: AppColors.white, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Stollar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Jonli',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _isLoadingTables
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              )
                  : _tables.isEmpty
                  ? const Center(
                child: Text(
                  "Hech qanday stol topilmadi.",
                  style: TextStyle(color: AppColors.grey),
                ),
              )
                  : GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _tables.length,
                itemBuilder: (_, index) {
                  final table = _tables[index];
                  final isSelected = _selectedTableId == table.id;
                  final isOccupied = _tableOccupiedStatus[table.id] ?? false;

                  return GestureDetector(
                    onTap: () {
                      if (_selectedTableId == table.id && !isOccupied) {
                        _showOrderScreenDialog(table.id);
                      } else {
                        _handleTableTap(table.name, table.id);
                      }
                    },
                    child: _buildTableCard(table, isSelected, isOccupied),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(StolModel table, bool isSelected, bool isOccupied) {
    Color cardColor;
    Color textColor;
    Color statusColor;
    String statusText;

    if (isOccupied) {
      cardColor = AppColors.error.withOpacity(0.1);
      textColor = AppColors.error;
      statusColor = AppColors.error;
      statusText = "Band";
    } else if (isSelected) {
      cardColor = Colors.green.withOpacity(0.1); // Red for selected table
      textColor = Colors.green ; // Red text for selected table
      statusColor = AppColors.accent;
      statusText = "Tanlangan";
    } else {
      cardColor = AppColors.lightGrey;
      textColor = AppColors.grey;
      statusColor = AppColors.accent;
      statusText = "Bo'sh";
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOccupied ? AppColors.error : (isSelected ? Colors.red : AppColors.lightGrey),
          width: isOccupied || isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: textColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.table_bar,
                size: 28,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Stol ${table.number}",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor, width: 1),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Status: ${table.status}",
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: _selectedTableId == null
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.point_of_sale,
              size: 64,
              color: AppColors.grey,
            ),
            SizedBox(height: 16),
            Text(
              "Buyurtma ma'lumotlarini\nko'rish uchun stolni tanlang",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  "Stol $_selectedTableName - Zakazlar",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_tableOccupiedStatus[_selectedTableId] ?? false)
                        ? AppColors.error
                        : AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (_tableOccupiedStatus[_selectedTableId] ?? false) ? 'Band' : 'Bo\'sh',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _isLoadingOrders
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              )
                  : _selectedTableOrders.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: AppColors.grey),
                    SizedBox(height: 12),
                    Text(
                      "Bu stolda hech qanday\nzakaz topilmadi",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: AppColors.grey),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _selectedTableOrders.length,
                itemBuilder: (context, index) {
                  final order = _selectedTableOrders[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: _buildOrderCard(order, index),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, int index) {
    final isOwnOrder = order.userId == widget.user.id;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Zakaz #${index + 1}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Kutilmoqda',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isOwnOrder) ...[
              _buildInfoRow(Icons.person, 'Hodim:', order.firstName),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.access_time, 'Vaqt:', _formatDateTime(order.createdAt)),
              const SizedBox(height: 16),
              const Text(
                "Mahsulotlar:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              ...order.items.map((item) => Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${item.name ?? 'Noma\'lum mahsulot'} x${item.quantity}",
                        style: const TextStyle(fontSize: 14, color: AppColors.primary),
                      ),
                    ),
                    if (item.price != null)
                      Text(
                        "${NumberFormat('#,##0', 'uz').format(item.price! * item.quantity)} so'm",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payments, color: AppColors.accent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Jami:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "${NumberFormat('#,##0', 'uz').format(order.totalPrice)} so'm",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, size: 20, color: AppColors.error),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Bu zakaz boshqa ofitsiantga tegishli",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 44,
              child: order.isProcessing
                  ? Container(
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              )
                  : isOwnOrder
                  ? ElevatedButton.icon(
                onPressed: () => _closeOrder(order),
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text(
                  "Yopish",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
                  : ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.lock, size: 18),
                label: const Text(
                  "Boshqa ofitsiant",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.grey,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildInfoRow(IconData icon, String key, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Text(
            key,
            style: const TextStyle(
              color: AppColors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
  String? _token;
  bool _isSubmitting = false;

  final List<CartItem> _cart = [];
  final NumberFormat _currencyFormatter = NumberFormat('#,##0', 'uz_UZ');

  @override
  void initState() {
    super.initState();
    _loadData();
    _initializeToken();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Parallel loading for better performance
      final results = await Future.wait([
        CategoryaController().fetchCategories().timeout(const Duration(seconds: 3)),
        OvqatController().fetchProducts().timeout(const Duration(seconds: 3)),
      ]);

      final categories = results[0] as List<Category>;
      final products = results[1] as List<Ovqat>;

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
          _error = 'Ma\'lumotlarni yuklashda xatolik yuz berdi';
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
      final existingItemIndex = _cart.indexWhere((item) => item.product.id == product.id);
      if (existingItemIndex >= 0) {
        _cart[existingItemIndex].quantity++;
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
    final existingItem = _cart.where((item) => item.product.id == product.id);
    return existingItem.isEmpty ? 0 : existingItem.first.quantity;
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

  Future<void> _initializeToken() async {
    try {
      _token = await AuthService.getToken();
      if (_token == null) {
        await AuthService.loginAndPrintToken();
        _token = await AuthService.getToken();
      }
    } catch (e) {
      print("Token olishda xatolik: $e");
    }
  }

  Future<void> _createOrderAndPrint() async {
    if (_isSubmitting || _cart.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
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

      final response = await http.post(
        Uri.parse("https://sora-b.vercel.app/api/orders/create"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> printers = responseData['printing']['results'] ?? [];

        if (printers.isNotEmpty) {
          final List<String> printerIPs = printers
              .map<String>((printer) => printer['printer_ip'].toString())
              .toList();

          final Map<String, dynamic> orderData = {
            '_id': responseData['order']['id'],
            'tableName': widget.tableName ?? 'N/A',
            'cart': _cart.map((item) => {
              'product': {'name': item.product.name},
              'quantity': item.quantity
            }).toList(),
          };

          await _printOrderToAllPrinters(orderData, printerIPs);
        }

        _showSnackBar('Zakaz yaratildi!', AppColors.accent);
        widget.onOrderCreated?.call();
        Navigator.of(context).pop();
      } else {
        throw Exception('API xatoligi: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Xatolik yuz berdi: $e', AppColors.error);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _printOrderToAllPrinters(Map<String, dynamic> orderData, List<String> printerIPs) async {
    const int port = 9100;
    List<int> bytes = [];

    // ESC/POS commands
    List<int> reset() => [0x1B, 0x40];
    List<int> boldOn() => [0x1B, 0x45, 0x01];
    List<int> boldOff() => [0x1B, 0x45, 0x00];
    List<int> fontSize(int widthMultiplier, int heightMultiplier) =>
        [0x1D, 0x21, (widthMultiplier - 1) << 4 | (heightMultiplier - 1)];
    List<int> alignCenter() => [0x1B, 0x61, 0x01];
    List<int> cut() => [0x1D, 0x56, 0x00];
    List<int> feedLines(int n) => [0x1B, 0x64, n];
    List<int> selectCodePage(int page) => [0x1B, 0x74, page];

    bytes += reset();
    bytes += selectCodePage(17);

    // Header
    bytes += alignCenter();
    bytes += fontSize(1, 1);
    bytes += boldOn();

    String tableName = orderData['tableName'] ?? 'N/A';
    String headerText = 'Mahsulotlar - Stol: $tableName';
    bytes += _encodeCP1251('$headerText\n');
    bytes += boldOff();
    bytes += _encodeCP1251('--------------------------------\n');

    // Products header
    bytes += fontSize(2, 1);
    bytes += _encodeCP1251('Nomi'.padRight(16) + 'Soni\n');
    bytes += _encodeCP1251('----------------------\n');

    // Products list
    List<dynamic> cartItems = orderData['cart'] ?? [];
    for (var item in cartItems) {
      String name = item['product']['name'].toString();
      String quantity = '${item['quantity']}x';
      name = name.length > 16 ? name.substring(0, 16) : name.padRight(16);
      bytes += _encodeCP1251('$name$quantity\n');
    }

    bytes += _encodeCP1251('--------------------\n');
    bytes += feedLines(4);
    bytes += cut();

    // Send to all printers
    for (String printerIP in printerIPs) {
      try {
        Socket socket = await Socket.connect(printerIP, port, timeout: const Duration(seconds: 3));
        socket.add(bytes);
        await socket.flush();
        await socket.close();
        print('✅ Print yuborildi: $printerIP');
      } catch (e) {
        print('Print error: $printerIP -> $e');
      }
    }
  }

  List<int> _encodeCP1251(String text) {
    const cpMap = {
      0x0401: 0xA8, // Ё
      0x0451: 0xB8, // ё
    };

    List<int> encoded = [];
    for (var rune in text.runes) {
      if (rune >= 0x0410 && rune <= 0x042F) {
        encoded.add(rune - 0x0410 + 0xC0);
      } else if (rune >= 0x0430 && rune <= 0x044F) {
        encoded.add(rune - 0x0430 + 0xE0);
      } else if (cpMap.containsKey(rune)) {
        encoded.add(cpMap[rune]!);
      } else if (rune < 128) {
        encoded.add(rune);
      } else {
        encoded.add(0x3F);
      }
    }
    return encoded;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth >= 600 && screenWidth <= 1200;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(isDesktop),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: isDesktop ? 280 : (isTablet ? 250 : 200),
                    child: _buildCategoriesSection(isDesktop),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildProductsSection(isDesktop, isTablet),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildBottomActions(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart, color: AppColors.white, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Yangi hisob",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  Text(
                    "Hodim: ${widget.user.firstName}",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 28, color: AppColors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(bool isDesktop) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.category, color: AppColors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Kategoriyalar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
                : _error != null
                ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            )
                : _categories.isEmpty
                ? const Center(
              child: Text(
                'Kategoriyalar topilmadi',
                style: TextStyle(color: AppColors.grey),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildCategoryButton(category, isDesktop),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(bool isDesktop, bool isTablet) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.restaurant_menu, color: AppColors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Mahsulotlar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
                  : _error != null
                  ? Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              )
                  : _filteredProducts.isEmpty
                  ? const Center(
                child: Text(
                  'Bu kategoriyada mahsulot yo\'q',
                  style: TextStyle(color: AppColors.grey),
                ),
              )
                  : GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  return _buildProductCard(product, isDesktop);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(Category category, bool isDesktop) {
    final bool isSelected = _selectedCategoryId == category.id;
    return SizedBox(
      height: isDesktop ? 48 : 44,
      child: ElevatedButton(
        onPressed: () => _selectCategory(category.id, category.title),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? AppColors.primary : AppColors.white,
          foregroundColor: isSelected ? AppColors.white : AppColors.primary,
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.lightGrey,
            width: 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              _getCategoryIcon(category.title),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Ovqat product, bool isDesktop) {
    final int quantityInCart = _getQuantityInCart(product);
    final double totalPrice = product.price * quantityInCart;

    return GestureDetector(
      onTap: () => _addToCart(product),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: quantityInCart > 0 ? AppColors.primary : AppColors.lightGrey,
            width: quantityInCart > 0 ? 2 : 1,
          ),
          boxShadow: quantityInCart > 0
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              offset: const Offset(0, 2),
              blurRadius: 8,
            )
          ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(9),
                  topRight: Radius.circular(9),
                ),
              ),
              child: Text(
                '${_currencyFormatter.format(product.price)} soʻm',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Jami: ${_currencyFormatter.format(totalPrice)} soʻm',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (quantityInCart > 0) ...[
                    GestureDetector(
                      onTap: () {
                        _updateQuantity(
                          _cart.firstWhere((item) => item.product.id == product.id),
                          -1,
                        );
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.remove, size: 16, color: AppColors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        '$quantityInCart',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () => _addToCart(product),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.add, size: 16, color: AppColors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(bool isDesktop) {
    final double total = _calculateTotal();
    final bool isCartEmpty = _cart.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 200 : 150),
            child: OutlinedButton.icon(
              onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text(
                'Bekor qilish',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                side: const BorderSide(color: AppColors.grey),
                foregroundColor: AppColors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 300 : 250),
            child: ElevatedButton.icon(
              onPressed: (isCartEmpty || _isSubmitting) ? null : _createOrderAndPrint,
              icon: _isSubmitting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
                  : const Icon(Icons.restaurant_menu, size: 18),
              label: Text(
                _isSubmitting
                    ? 'Yuklanmoqda...'
                    : 'Zakaz berish (${_currencyFormatter.format(total)} soʻm)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: (isCartEmpty || _isSubmitting)
                    ? AppColors.grey
                    : AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}