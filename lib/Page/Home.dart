import 'dart:convert';
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
          .toList() ??
          [],
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

  // Real-time uchun yangi o'zgaruvchilar
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
    _realTimeTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkTableStatuses();
    });
  }

  Future<void> _checkTableStatuses() async {
    if (_token == null) return;

    try {
      Map<String, bool> newTableStatus = {};

      for (var table in _tables) {
        final response = await http.get(
          Uri.parse('https://sora-b.vercel.app/api/orders/table/${table.id}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        );

        if (response.statusCode == 200) {
          final List<dynamic> tableOrders = jsonDecode(response.body);
          bool isOccupied = tableOrders.any((order) => order['status'] == 'pending');
          newTableStatus[table.id] = isOccupied;
        } else {
          newTableStatus[table.id] = false;
        }
      }

      if (!_mapEquals(newTableStatus, _tableOccupiedStatus)) {
        setState(() {
          _tableOccupiedStatus = newTableStatus;
        });
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
      if (_token == null) {
        print("❌ Token olishda xatolik: Token null bo'lib qoldi");
      } else {
        print("✅ Token muvaffaqiyatli olindi: $_token");
        _loadInitialTables();
      }
    } catch (e) {
      print("❗ Token olishda xatolik: $e");
    }
  }

  Future<void> _loadInitialTables() async {
    setState(() {
      _isLoadingTables = true;
    });

    try {
      final stolController = StolController();
      final tables = await stolController.fetchTables();
      setState(() {
        _tables = tables;
        _isLoadingTables = false;
      });
      _checkTableStatuses();
    } catch (e) {
      setState(() {
        _isLoadingTables = false;
      });
      print("Stollarni yuklashda xatolik: $e");
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
    if (_token == null) {
      print("❌ Token topilmadi, iltimos qayta urinib ko'ring");
      return;
    }
    setState(() {
      _isLoadingOrders = true;
    });

    final String apiUrl = "https://sora-b.vercel.app/api/orders/table/$tableId";

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _selectedTableOrders = data
              .map((json) => Order.fromJson(json))
              .where((order) => order.status == 'pending')
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
    bool isOccupied = _tableOccupiedStatus[tableId] ?? false;

    if (isOccupied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text('Bu stol band! Yangi hisob ochib bo\'lmaydi.'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 3),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text('Faqat o\'zingiz yaratgan zakazni yopa olasiz!'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    print("Closing order ID: ${order.id}");
    try {
      setState(() {
        order.isProcessing = true;
      });

      bool success = await Zakazcontroller().closeOrder(order.id);
      print("Close order response: $success");

      if (success) {
        setState(() {
          _selectedTableOrders.removeWhere((o) => o.id == order.id);
        });

        _checkTableStatuses();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('Zakaz muvaffaqiyatli yopildi'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('Zakazni yopishda xatolik yuz berdi'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print("Close order error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xatolik yuz berdi: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() {
        order.isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth >= 600 && screenWidth <= 1200;
    final isMobile = screenWidth < 600;

    final maxWidth = isDesktop ? 1400.0 : screenWidth;
    final baseFontSize = isDesktop ? 15.0 : (isTablet ? 16.0 : 14.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isDesktop ? 75 : 65),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                offset: const Offset(0, 2),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF1E293B)),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            flexibleSpace: Center(
              child: Container(
                width: maxWidth,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 28 : 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 60),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3B82F6).withOpacity(0.1),
                            const Color(0xFF1D4ED8).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF3B82F6).withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              color: const Color(0xFF1D4ED8),
                              size: baseFontSize + 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.user.firstName,
                            style: TextStyle(
                              color: const Color(0xFF1E293B),
                              fontSize: baseFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          height: isDesktop ? 48 : 44,
                          decoration: BoxDecoration(
                            gradient: (_selectedTableName != null &&
                                !(_tableOccupiedStatus[_selectedTableId] ??
                                    false))
                                ? LinearGradient(
                              colors: [
                                Color(0xFF10B981),
                                Color(0xFF059669)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                                : LinearGradient(
                              colors: [
                                Color(0xFF6B7280),
                                Color(0xFF4B5563)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: ((_selectedTableName != null &&
                                    !(_tableOccupiedStatus[_selectedTableId] ??
                                        false))
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF6B7280))
                                    .withOpacity(0.3),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.add_circle_outline_rounded,
                                size: baseFontSize + 3),
                            label: Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                _selectedTableName != null
                                    ? "Yangi hisob : ${_selectedTableName} - Stol"
                                    : "Yangi hisob",
                                style: TextStyle(
                                  fontSize: baseFontSize - 1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              if (_selectedTableId != null) {
                                bool isOccupied =
                                    _tableOccupiedStatus[_selectedTableId] ??
                                        false;
                                if (isOccupied) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.warning_rounded,
                                              color: Colors.white),
                                          const SizedBox(width: 8),
                                          Text(
                                              '$_selectedTableName band! Yangi hisob ochib bo\'lmaydi.'),
                                        ],
                                      ),
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12)),
                                    ),
                                  );
                                } else {
                                  _showOrderScreenDialog(_selectedTableId!);
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'Avval stolni tanlang!'),
                                    backgroundColor: Colors.orange.shade600,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          height: isDesktop ? 48 : 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.check_circle_outline_rounded,
                                size: baseFontSize + 3),
                            label: Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                "Yopilgan hisoblar",
                                style: TextStyle(
                                  fontSize: baseFontSize - 1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OrderDetailsPage(
                                    waiterName: widget.user.firstName,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: Container(
          width: maxWidth,
          height: screenHeight - (isDesktop ? 75 : 65),
          child: Row(
            children: [
              Expanded(
                flex: isDesktop ? 3 : 3,
                child: Container(
                  margin: EdgeInsets.all(isDesktop ? 20 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        offset: const Offset(0, 4),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: _buildTablesGrid(baseFontSize, isDesktop, isTablet),
                ),
              ),
              Expanded(
                flex: isDesktop ? 2 : 2,
                child: Container(
                  margin: EdgeInsets.only(
                    top: isDesktop ? 20 : 12,
                    bottom: isDesktop ? 20 : 12,
                    right: isDesktop ? 20 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        offset: const Offset(0, 4),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: _buildOrderDetails(baseFontSize, isDesktop, isTablet),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTablesGrid(double fontSize, bool isDesktop, bool isTablet) {
    return Padding(
      padding: EdgeInsets.all(isDesktop ? 24 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.1),
                  const Color(0xFF1D4ED8).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.table_restaurant_rounded,
                    color: const Color(0xFF1D4ED8), size: fontSize + 4),
                const SizedBox(width: 12),
                Text(
                  'Stollar (Real-time)',
                  style: TextStyle(
                    fontSize: fontSize + 2,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Jonli',
                        style: TextStyle(
                          fontSize: fontSize - 3,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoadingTables
                ? Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF3B82F6),
                strokeWidth: 3,
              ),
            )
                : _tables.isEmpty
                ? Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text("Hech qanday stol topilmadi."),
              ),
            )
                : GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
                childAspectRatio: isDesktop ? 1.1 : 1.0,
                crossAxisSpacing: isDesktop ? 20 : 14,
                mainAxisSpacing: isDesktop ? 20 : 14,
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      gradient: isOccupied
                          ? LinearGradient(
                        colors: [
                          Colors.red.shade100,
                          Colors.red.shade200,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                          : isSelected
                          ? LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6)
                              .withOpacity(0.15),
                          const Color(0xFF1D4ED8)
                              .withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                          : LinearGradient(
                        colors: [
                          Colors.grey.shade50,
                          Colors.grey.shade100,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isOccupied
                            ? Colors.red.shade400
                            : isSelected
                            ? const Color(0xFF3B82F6)
                            : Colors.grey.shade300,
                        width: isOccupied || isSelected ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isOccupied
                              ? Colors.red.withOpacity(0.25)
                              : isSelected
                              ? const Color(0xFF3B82F6)
                              .withOpacity(0.25)
                              : Colors.grey.withOpacity(0.1),
                          offset: Offset(
                              0, isOccupied || isSelected ? 6 : 3),
                          blurRadius: isOccupied || isSelected ? 16 : 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: _buildTableCard(
                        table, fontSize, isSelected, isOccupied),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(
      StolModel table, double fontSize, bool isSelected, bool isOccupied) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isOccupied
                    ? [Colors.red.shade400, Colors.red.shade600]
                    : isSelected
                    ? [
                  const Color(0xFF3B82F6),
                  const Color(0xFF1D4ED8)
                ]
                    : [Colors.grey.shade300, Colors.grey.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: isOccupied
                      ? Colors.red.withOpacity(0.3)
                      : isSelected
                      ? const Color(0xFF3B82F6).withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Stack(
              children: [
                Icon(
                  Icons.table_bar_rounded,
                  size: fontSize + 8,
                  color: Colors.white,
                ),
                if (isOccupied)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: fontSize - 3,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Stol ${table.number}",
            style: TextStyle(
              fontSize: fontSize - 1,
              fontWeight: FontWeight.bold,
              color: isOccupied
                  ? Colors.red.shade700
                  : isSelected
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isOccupied ? Colors.red.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                isOccupied ? Colors.red.shade300 : Colors.green.shade300,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isOccupied
                        ? Colors.red.shade600
                        : Colors.green.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  isOccupied ? "Band" : "Bo'sh",
                  style: TextStyle(
                    fontSize: fontSize - 4,
                    color: isOccupied
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            "Sig'im: ${table.capacity}",
            style: TextStyle(
              fontSize: fontSize - 3,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(double fontSize, bool isDesktop, bool isTablet) {
    return Padding(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      child: _selectedTableId == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.point_of_sale_rounded,
                size: fontSize * 3.5,
                color: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Buyurtma ma'lumotlarini\nko'rish uchun stolni tanlang",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.1),
                  const Color(0xFF7C3AED).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded,
                    color: const Color(0xFF7C3AED), size: fontSize + 4),
                const SizedBox(width: 12),
                Text(
                  "Stol $_selectedTableName - Zakazlar",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize + 1,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_tableOccupiedStatus[_selectedTableId] ?? false)
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: (_tableOccupiedStatus[_selectedTableId] ??
                              false)
                              ? Colors.red.shade600
                              : Colors.green.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (_tableOccupiedStatus[_selectedTableId] ?? false)
                            ? 'Band'
                            : 'Bo\'sh',
                        style: TextStyle(
                          fontSize: fontSize - 3,
                          color: (_tableOccupiedStatus[_selectedTableId] ??
                              false)
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingOrders
                ? Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF8B5CF6),
                strokeWidth: 3,
              ),
            )
                : _selectedTableOrders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: fontSize * 2.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Bu stolda hech qanday\nzakaz topilmadi",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize - 1,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _selectedTableOrders.length,
              itemBuilder: (context, index) {
                final order = _selectedTableOrders[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        const Color(0xFFF8FAFC),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border:
                    Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: _buildOrderCard(
                      order, index, fontSize, isDesktop),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
      Order order, int index, double fontSize, bool isDesktop) {
    final isOwnOrder = order.userId == widget.user.id;

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6).withOpacity(0.1),
                      const Color(0xFF1D4ED8).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.2)),
                ),
                child: Text(
                  "Zakaz #${index + 1}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                    color: const Color(0xFF1D4ED8),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade200, Colors.amber.shade300],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: fontSize - 2,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Kutilmoqda',
                      style: TextStyle(
                        fontSize: fontSize - 2,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isOwnOrder) ...[
            _buildInfoRow(
                Icons.person_rounded, 'Hodim:', order.firstName, fontSize),
            const SizedBox(height: 6),
            _buildInfoRow(Icons.access_time_rounded, 'Vaqt:',
                _formatDateTime(order.createdAt), fontSize),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: fontSize,
                    color: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Mahsulotlar:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize - 1,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...order.items.map((item) => Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6),
                          const Color(0xFF1D4ED8)
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "${item.name ?? 'Noma\'lum mahsulot'} x${item.quantity}",
                      style: TextStyle(
                        fontSize: fontSize - 2,
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (item.price != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${NumberFormat('#,##0', 'uz').format(item.price! * item.quantity)} so'm",
                        style: TextStyle(
                          fontSize: fontSize - 2,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),
                ],
              ),
            )),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withOpacity(0.1),
                    const Color(0xFF059669).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border:
                Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.payments_rounded,
                        color: const Color(0xFF059669),
                        size: fontSize,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Jami:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "${NumberFormat('#,##0', 'uz').format(order.totalPrice)} so'm",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize + 1,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: fontSize,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Bu zakaz boshqa ofitsiantga tegishli",
                      style: TextStyle(
                        fontSize: fontSize - 1,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 44,
            child: order.isProcessing
                ? Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFF10B981),
                  strokeWidth: 2,
                ),
              ),
            )
                : isOwnOrder
                ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981),
                    const Color(0xFF059669)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _closeOrder(order),
                icon: Icon(Icons.check_circle_rounded,
                    size: fontSize),
                label: Text(
                  "Yopish",
                  style: TextStyle(
                    fontSize: fontSize - 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            )
                : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade400,
                    Colors.grey.shade500
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: null,
                icon: Icon(Icons.lock_rounded, size: fontSize),
                label: Text(
                  "Boshqa ofitsiant",
                  style: TextStyle(
                    fontSize: fontSize - 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
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

  Widget _buildInfoRow(
      IconData icon, String key, String value, double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF64748B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: const Color(0xFF475569), size: fontSize - 1),
          ),
          const SizedBox(width: 10),
          Text(
            key,
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: fontSize - 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: fontSize - 2,
                color: const Color(0xFF1E293B),
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

  final List<CartItem> _cart = [];
  final NumberFormat _currencyFormatter = NumberFormat('#,##0', 'uz_UZ');
  final CategoryaController _categoryController = CategoryaController();
  final OvqatController _productController = OvqatController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _initializeToken();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final categories = await _categoryController.fetchCategories().timeout(
        const Duration(seconds: 1),
      );

      final products = await _productController.fetchProducts().timeout(
        const Duration(seconds: 1),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth >= 600 && screenWidth <= 1200;

    final maxWidth = isDesktop ? 1600.0 : screenWidth;
    final baseFontSize = isDesktop ? 14.0 : (isTablet ? 16.0 : 14.0);
    final padding = isDesktop ? 20.0 : 16.0;

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Colors.transparent,
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
            child: Center(
              child: Container(
                width: maxWidth,
                height: screenHeight,
                padding: EdgeInsets.all(padding),
                child: Column(
                  children: [
                    _buildAppBar(baseFontSize, isDesktop),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: isDesktop ? 280 : (isTablet ? 250 : 200),
                            child: _buildCategoriesSection(baseFontSize, padding, isDesktop),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildProductsSection(baseFontSize, padding, isDesktop, isTablet),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBottomActions(baseFontSize, padding, isDesktop),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(double fontSize, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: isDesktop ? 16 : 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.teal.shade600, Colors.teal.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_cart,
                  color: Colors.teal.shade600,
                  size: fontSize + 4,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.tableId != null ? "Yangi hisob" : "Yangi hisob",
                    style: TextStyle(
                      fontSize: fontSize + 2,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Hodim: ${widget.user.firstName}",
                    style: TextStyle(
                      fontSize: fontSize - 1,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: fontSize + 6,
              color: Colors.white70,
            ),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Yopish',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(double fontSize, double padding, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              children: [
                Icon(
                  Icons.category,
                  color: Colors.teal.shade600,
                  size: fontSize + 4,
                ),
                const SizedBox(width: 8),
                Text(
                  'Kategoriyalar',
                  style: TextStyle(
                    fontSize: fontSize + 2,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!,
                style: TextStyle(color: Colors.red, fontSize: fontSize)))
                : _categories.isEmpty
                ? Center(
              child: Text(
                'Kategoriyalar topilmadi',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: fontSize,
                ),
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.only(
                left: padding,
                right: padding,
                bottom: padding,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildCategoryButton(category, fontSize, isDesktop),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(double fontSize, double padding, bool isDesktop, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              children: [
                Icon(
                  Icons.restaurant_menu,
                  color: Colors.teal.shade600,
                  size: fontSize + 4,
                ),
                const SizedBox(width: 8),
                Text(
                  'Mahsulotlar',
                  style: TextStyle(
                    fontSize: fontSize + 2,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: padding,
                right: padding,
                bottom: padding,
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!,
                  style: TextStyle(color: Colors.red, fontSize: fontSize)))
                  : _filteredProducts.isEmpty
                  ? Center(
                child: Text(
                  'Bu kategoriyada mahsulot yo\'q',
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Colors.grey.shade600,
                  ),
                ),
              )
                  : GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
                  childAspectRatio: isDesktop ? 1.0 : 0.9,
                  crossAxisSpacing: isDesktop ? 16 : 12,
                  mainAxisSpacing: isDesktop ? 16 : 12,
                ),
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  return _buildProductCard(product, fontSize, isDesktop);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(Category category, double fontSize, bool isDesktop) {
    final bool isSelected = _selectedCategoryId == category.id;
    return SizedBox(
      height: isDesktop ? 50 : 45,
      child: ElevatedButton(
        onPressed: () => _selectCategory(category.id, category.title),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.teal.shade600 : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.teal.shade700,
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? Colors.teal.shade600 : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              _getCategoryIcon(category.title),
              size: fontSize + 2,
              color: isSelected ? Colors.white : Colors.teal.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.title,
                style: TextStyle(
                  fontSize: fontSize,
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

  Widget _buildProductCard(Ovqat product, double fontSize, bool isDesktop) {
    final int quantityInCart = _getQuantityInCart(product);
    final double totalPrice = product.price * quantityInCart;

    return GestureDetector(
      onTap: () => _addToCart(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: quantityInCart > 0 ? Colors.teal.shade400 : Colors.grey.shade300,
            width: quantityInCart > 0 ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: quantityInCart > 0
                  ? Colors.teal.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              spreadRadius: quantityInCart > 0 ? 2 : 1,
              blurRadius: quantityInCart > 0 ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 12 : 8,
                vertical: isDesktop ? 10 : 8,
              ),
              decoration: BoxDecoration(
                color: Colors.teal.shade600,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Text(
                '${_currencyFormatter.format(product.price)} soʻm',
                style: TextStyle(
                  fontSize: fontSize - 1,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(isDesktop ? 12 : 8),
                child: Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 40,
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
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 12 : 8,
                  vertical: 4,
                ),
                child: Text(
                  'Jami: ${_currencyFormatter.format(totalPrice)} soʻm',
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isDesktop ? 12 : 8),
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
                        width: isDesktop ? 32 : 28,
                        height: isDesktop ? 32 : 28,
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.remove,
                          size: fontSize,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        '$quantityInCart',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () => _addToCart(product),
                    child: Container(
                      width: isDesktop ? 32 : 28,
                      height: isDesktop ? 32 : 28,
                      decoration: BoxDecoration(
                        color: Colors.teal.shade600,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.add,
                        size: fontSize,
                        color: Colors.white,
                      ),
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

  bool _isSubmitting = false;

  Future<void> _initializeToken() async {
    try {
      _token = await AuthService.getToken();
      if (_token == null) {
        await AuthService.loginAndPrintToken();
        _token = await AuthService.getToken();
      }
      if (_token == null) {
        print("❌ Token olishda xatolik: Token null bo'lib qoldi");
      } else {
        print("✅ Token muvaffaqiyatli olindi: $_token");
      }
    } catch (e) {
      print("❗ Token olishda xatolik: $e");
    }
  }

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
          'Authorization': 'Bearer $_token',
        },
        body: body,
      );

      print("✅ Printer ip olish uchun ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ : ${response.body}");
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        final String printerIP = responseData['printing']['results'][0]['printer_ip'] ?? '192.168.0.106';

        final Map<String, dynamic> orderData = {
          '_id': responseData['order']['id'],
        };

        await _printOrderDirectly(orderData, printerIP);

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


  Future<void> _printOrderDirectly(Map<String, dynamic> orderData, String printerIP) async {
    const int port = 9100;

    try {
      List<int> bytes = [];

      // ESC/POS commands
      List<int> reset() => [0x1B, 0x40]; // Initialize
      List<int> boldOn() => [0x1B, 0x45, 0x01];
      List<int> boldOff() => [0x1B, 0x45, 0x00];
      List<int> fontSize(int widthMultiplier, int heightMultiplier) => [0x1D, 0x21, (widthMultiplier - 1) << 4 | (heightMultiplier - 1)];
      List<int> alignCenter() => [0x1B, 0x61, 0x01];
      List<int> alignLeft() => [0x1B, 0x61, 0x00];
      List<int> cut() => [0x1D, 0x56, 0x00];

      bytes += reset();
      bytes += alignCenter();
      bytes += fontSize(2, 2);
      bytes += boldOn();
      bytes += _encodeText('--- Restoran Cheki ---\n\n');

      bytes += fontSize(1, 1);
      bytes += boldOff();
      bytes += _encodeText('Buyurtma: ${orderData['_id'] ?? '#001'}\n');
      bytes += _encodeText('Stol: ${widget.tableName ?? 'N/A'}\n');
      bytes += _encodeText('Hodim: ${widget.user.firstName}\n');
      bytes += _encodeText('Vaqt: ${DateFormat('d MMMM yyyy, HH:mm', 'uz').format(DateTime.now())}\n');
      bytes += _encodeText('------------------------------\n');

      bytes += boldOn();
      bytes += _encodeText('Mahsulotlar:\n');
      bytes += boldOff();

      bytes += alignLeft();
      for (var item in _cart) {
        String name = item.product.name.length > 18
            ? item.product.name.substring(0, 18)
            : item.product.name;
        String quantity = '${item.quantity}x';
        String line = name.padRight(18) + quantity.padLeft(5);
        bytes += _encodeText('$line\n');
      }

      bytes += alignCenter();
      bytes += _encodeText('------------------------------\n\n');
      bytes += cut();

      Socket socket = await Socket.connect(printerIP, port, timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      socket.destroy();
    } catch (e) {
      print('Printer xatoligi: $e');
    }
  }

  List<int> _encodeText(String text) {
    return text.codeUnits;
  }


  Widget _buildBottomActions(double fontSize, double padding, bool isDesktop) {
    final double total = _calculateTotal();
    final bool isCartEmpty = _cart.isEmpty;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
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
              icon: Icon(Icons.arrow_back, size: fontSize + 2),
              label: Text(
                'Bekor qilish',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: isDesktop ? 12 : 10),
                side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                foregroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)
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
                  ? SizedBox(
                width: fontSize + 2,
                height: fontSize + 2,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Icon(Icons.restaurant_menu, size: fontSize + 2),
              label: Text(
                _isSubmitting
                    ? 'Yuklanmoqda...'
                    : 'Zakaz berish (${_currencyFormatter.format(total)} soʻm)',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: (isCartEmpty || _isSubmitting)
                    ? Colors.grey.shade300
                    : Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: isDesktop ? 12 : 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)
                ),
                elevation: (isCartEmpty || _isSubmitting) ? 0 : 4,
                shadowColor: Colors.teal.shade200,
              ),
            ),
          ),
        ],
      ),
    );
  }
}