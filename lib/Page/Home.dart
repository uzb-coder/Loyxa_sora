  import 'package:flutter/material.dart';
  import 'package:intl/intl.dart';
  import 'dart:io';

import '../Controller/StolController.dart';

  class Product {
    final int id;
    final String name;
    final double price;
    final String category;

    Product({required this.id, required this.name, required this.price, required this.category});
  }

  class CartItem {
    final Product product;
    int quantity;

    CartItem({required this.product, this.quantity = 1});
  }

  class PosScreen extends StatefulWidget {
    const PosScreen({super.key});

    @override
    State<PosScreen> createState() => _PosScreenState();
  }

  class _PosScreenState extends State<PosScreen> {
    final List<Map<String, dynamic>> _tables = List.generate(
      6,
          (index) => {
        'id': index + 1,
        'status': (index == 0 || index == 2 || index == 4) ? 'pending' : 'free',
      },
    );

    final Map<int, Map<String, dynamic>> _orders = {
      1: {
        'orderId': '#004',
        'sum': 12000.0,
        'status': 'pending',
        'items': [
          {'name': 'Tor', 'price': 3000, 'quantity': 1},
          {'name': 'Shirinlik ', 'price': 9000, 'quantity': 1},
          {'name': 'Kofe ', 'price': 9000, 'quantity': 1},
          {'name': 'Cola', 'price': 9000, 'quantity': 1},
        ],
      },
      6: {
        'orderId': '#006',
        'sum': 55000.0,
        'status': 'pending',
        'items': [
          {'name': 'Osh', 'price': 30000, 'quantity': 1},
          {'name': 'Achichuk salat', 'price': 5000, 'quantity': 1},
          {'name': 'Choy (limonli)', 'price': 5000, 'quantity': 1},
          {'name': 'Non (patir)', 'price': 5000, 'quantity': 1},
        ],
      },
    };

    int? _selectedTableId;

    void _handleTableTap(int tableId) {
      setState(() {
        _selectedTableId = tableId;
      });
    }

    void _showOrderScreenDialog(int? tableId) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog.fullscreen(
            child: OrderScreenContent(tableId: tableId),
          );
        },
      );
    }

    void _showTableSelectionWarning() {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Stol tanlanmagan"),
            content: const Text("Yangi hisob ochish uchun avval stolni tanlang."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Yopish"),
              ),
            ],
          );
        },
      );
    }




    Future<void> _printCheck(Map<String, dynamic> order) async {
      const String printerIP = '192.168.0.106';
      const int port = 9100;

      try {
        StringBuffer receipt = StringBuffer();
        String centerText(String text, int width) => text.padLeft((width - text.length) ~/ 2 + text.length).padRight(width);
        receipt.writeln(centerText('--- Restoran Cheki ---', 32));
        receipt.writeln(); // One blank line after restaurant name
        receipt.writeln(centerText('Buyurtma: ${order['orderId']}', 32));
        receipt.writeln(); // One blank line after order number
        receipt.writeln(centerText('Stol: $_selectedTableId', 32));
        receipt.writeln(); // One blank line after table number
        receipt.writeln(centerText('Vaqt: ${DateFormat('d MMMM yyyy, HH:mm', 'uz').format(DateTime.now())}', 32));
        receipt.writeln(); // One blank line after time
        receipt.writeln(centerText('--------------------', 32));
        receipt.writeln(); // One blank line before products header
        receipt.writeln(centerText('Mahsulotlar:', 32));
        receipt.writeln(); // One blank line after products header
        for (var item in order['items'] as List) {
          String name = item['name'].toString().length > 18 ? item['name'].toString().substring(0, 18) : item['name'].toString();
          String price = '${item['price'].toInt()} so\'m';
          String quantity = '${item['quantity'] ?? 1}x';
          receipt.writeln('${name.padRight(18)}${quantity.padRight(4)} $price');
          receipt.writeln(); // One blank line after each product
        }
        receipt.writeln(centerText('--------------------', 32));
        receipt.writeln(); // One blank line before total
        String total = '${order['sum'].toInt()} so\'m';
        receipt.writeln(centerText('Jami: $total', 32));
        receipt.writeln('\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n'); // 20 newlines for large gap before cut
        receipt.write('\x1D\x56\x00'); // Paper cut command

        Socket socket = await Socket.connect(printerIP, port, timeout: const Duration(seconds: 5));
        socket.write(receipt.toString());
        await socket.flush();
        socket.destroy();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Chek printerga yuborildi!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Xatolik: $e')),
        );
      }
    }

    void _showCheckPreviewDialog(Map<String, dynamic>? order) {
      if (order == null) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          final baseFontSize = MediaQuery.of(context).textScaler.scale(15.0);

          return AlertDialog(
            titlePadding: EdgeInsets.only(top: baseFontSize * 1.2),
            contentPadding: EdgeInsets.symmetric(horizontal: baseFontSize * 0.7, vertical: baseFontSize * 0.5),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              children: [
                Icon(Icons.receipt_long_rounded, size: baseFontSize * 3.5, color: Colors.teal.shade700),
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
                SizedBox(height: baseFontSize * 0.6), // One line spacing after restaurant name
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
                          'Buyurtma: ${order['orderId']}',
                          style: TextStyle(fontSize: baseFontSize * 0.95, fontFamily: 'Courier', fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: baseFontSize * 0.6), // One line spacing after order number
                        Text(
                          'Stol: $_selectedTableId',
                          style: TextStyle(fontSize: baseFontSize * 0.95, fontFamily: 'Courier', fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: baseFontSize * 0.6), // One line spacing after table number
                        Text(
                          'Vaqt: ${DateFormat('d MMMM yyyy, HH:mm', 'uz').format(DateTime.now())}',
                          style: TextStyle(fontSize: baseFontSize * 0.95, fontFamily: 'Courier', fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: baseFontSize * 0.6), // One line spacing before divider
                        Divider(thickness: 1.5, height: baseFontSize * 1.2, color: Colors.teal.shade100),
                        SizedBox(height: baseFontSize * 0.3), // One line spacing before products header
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
                        SizedBox(height: baseFontSize * 0.3), // One line spacing after products header
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2.5),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(2),
                          },
                          children: (order['items'] as List).map((item) {
                            String name = item['name'].toString().length > 18 ? item['name'].toString().substring(0, 18) : item['name'].toString();
                            String price = '${item['price'].toInt()} so\'m';
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
                                    '${item['quantity'] ?? 1}x',
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      fontSize: baseFontSize * 0.85,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: baseFontSize * 0.15),
                                  child: Text(
                                    price,
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
                          }).toList().asMap().entries.map((entry) {
                            int index = entry.key;
                            TableRow row = entry.value;
                            return [
                              row,
                              if (index < (order['items'] as List).length - 1)
                                TableRow(
                                  children: [
                                    SizedBox(height: baseFontSize * 0.6), // One line spacing after each product
                                    SizedBox(height: baseFontSize * 0.6),
                                    SizedBox(height: baseFontSize * 0.6),
                                  ],
                                ),
                            ];
                          }).expand((element) => element).toList(),
                        ),
                        SizedBox(height: baseFontSize * 0.3), // One line spacing after product list
                        Divider(thickness: 1.5, height: baseFontSize * 1.2, color: Colors.teal.shade100),
                        SizedBox(height: baseFontSize * 0.3), // One line spacing before total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Jami:',
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: baseFontSize * 1.4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${order['sum'].toInt()} so\'m',
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: baseFontSize * 1.4,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: baseFontSize * 0.6), // One line spacing after total
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
                  style: TextStyle(fontSize: baseFontSize * 0.9, color: Colors.grey.shade700),
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
                  padding: EdgeInsets.symmetric(horizontal: baseFontSize * 1.2, vertical: baseFontSize * 0.8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                ),
                child: Text(
                  'Chop etish',
                  style: TextStyle(fontSize: baseFontSize * 0.9, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      );
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
            DateFormat('d MMMM yyyy, EEEE HH:mm', 'uz').format(DateTime.now()),
            style: TextStyle(color: Colors.black87, fontSize: baseFontSize * 1.1),
          ),
          actions: [
            SizedBox(
              width: isMobile ? 180 : isTablet ? 200 : 220,
              child: ElevatedButton.icon(
                icon: Icon(Icons.add_circle_outline, size: baseFontSize * 1.5),
                label: Text("Yangi hisob", style: TextStyle(fontSize: baseFontSize * 1.1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: baseFontSize * 0.5, vertical: baseFontSize * 0.9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                onPressed: () {
                  if (_selectedTableId != null) {
                    _showOrderScreenDialog(_selectedTableId);
                  } else {
                    _showTableSelectionWarning();
                  }
                },
              ),
            ),
            SizedBox(width: baseFontSize * 0.5),
            SizedBox(
              width: isMobile ? 180 : isTablet ? 200 : 220,
              child: ElevatedButton.icon(
                icon: Icon(Icons.check_circle_outline, size: baseFontSize * 1.5),
                label: Text("Yopilgan hisoblar", style: TextStyle(fontSize: baseFontSize * 1.1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: baseFontSize * 1.5, vertical: baseFontSize * 0.9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                onPressed: () {},
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

    // Stollar javob beradi
    Widget _buildTablesGrid(double fontSize, BoxConstraints constraints) {

      final width = constraints.maxWidth;
      final isMobile = width < 600;
      final isTablet = width >= 600 && width <= 1200;
      final tableWidth = isMobile ? 150.0 : isTablet ? 200.0 : 250.0;

      return Padding(
        padding: EdgeInsets.all(fontSize * 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stollar', style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold)),
            SizedBox(height: fontSize * 0.5),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: fontSize * 1.5,
                  mainAxisSpacing: fontSize * 1.5,
                ),
                itemCount: _tables.length,
                itemBuilder: (_, index) => SizedBox(
                  width: tableWidth,
                  child: _buildTableCard(_tables[index], fontSize),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildTableCard(Map<String, dynamic> t, double f) {
      final isSelected = t['id'] == _selectedTableId;
      final isPending = t['status'] == 'pending';

      return InkWell(
        onTap: () => _handleTableTap(t['id']),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.all(f * 0.5),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal : isPending ? Colors.orange.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.table_restaurant_rounded, size: f * 2.5, color: isSelected ? Colors.white : Colors.black54),
              SizedBox(height: f * 0.5),
              Text(
                'Stol ${t['id']}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: f,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              if (isPending)
                Text(
                  'Band',
                  style: TextStyle(
                    fontSize: f * 0.8,
                    color: isSelected ? Colors.white70 : Colors.orange.shade800,
                  ),
                ),
            ],
          ),
        ),
      );
    }




  // yon oyan
    Widget _buildOrderDetails(double baseFontSize, BoxConstraints constraints) {
      final order = _orders[_selectedTableId];

      return Container(
        color: Colors.grey[50],
        padding: EdgeInsets.all(baseFontSize * 0.5),
        child: order == null
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
                style: TextStyle(fontSize: baseFontSize * 0.9, color: Colors.grey),
              ),
            ],
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Buyurtma (${order['orderId']})",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: baseFontSize * 1.2),
            ),
            SizedBox(height: baseFontSize * 0.5),
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(baseFontSize * 0.8),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.table_chart_rounded, 'Stol:', '$_selectedTableId', baseFontSize),
                    Divider(height: baseFontSize * 1.2),
                    _buildInfoRow(Icons.check_circle, 'Status:', '${order['status']}', baseFontSize),
                  ],
                ),
              ),
            ),
            SizedBox(height: baseFontSize * 0.5),
            Text(
              "Mahsulotlar:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: baseFontSize * 1.0),
            ),
            Divider(height: baseFontSize * 1.2),
            Expanded(
              child: ListView.builder(
                itemCount: (order['items'] as List).length,
                itemBuilder: (context, index) {
                  final item = (order['items'] as List)[index];
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: baseFontSize * 0.5),
                    title: Text(
                      item['name'],
                      style: TextStyle(fontSize: baseFontSize * 0.9),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${item['quantity'] ?? 1}x",
                          style: TextStyle(fontSize: baseFontSize * 0.9),
                        ),
                        SizedBox(width: baseFontSize * 1.8),
                        Text(
                          "${NumberFormat.decimalPattern('uz').format(item['price'])} so'm",
                          style: TextStyle(fontSize: baseFontSize * 0.9),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Divider(height: baseFontSize * 1.2),
            Padding(
              padding: EdgeInsets.symmetric(vertical: baseFontSize * 0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Jami:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: baseFontSize * 1.0),
                  ),
                  Text(
                    "${NumberFormat.decimalPattern('uz').format(order['sum'])} so'm",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: baseFontSize * 1.0, color: Colors.teal),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: baseFontSize * 0.8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                child: Text(
                  "Yopish",
                  style: TextStyle(fontSize: baseFontSize * 1.5),
                ),
              ),
            ),
            SizedBox(height: baseFontSize * 0.5),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: order != null ? () => _showCheckPreviewDialog(order) : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: baseFontSize * 0.8),
                  side: BorderSide(color: Colors.teal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                child: Text(
                  "Chekni chiqarish",
                  style: TextStyle(fontSize: baseFontSize * 1.5, color: Colors.teal),
                ),
              ),
            ),
            SizedBox(height: 60,)
          ],
        ),
      );
    }


    Widget _buildInfoRow(IconData icon, String key, String value, double fontSize) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: fontSize * 0.3),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[600], size: fontSize * 1.2),
            SizedBox(width: fontSize * 0.5),
            Text(key, style: TextStyle(color: Colors.grey[700], fontSize: fontSize * 0.9)),
            const Spacer(),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize * 0.9)),
          ],
        ),
      );
    }
  }



  class OrderScreenContent extends StatefulWidget {
    final int? tableId;

    const OrderScreenContent({super.key, this.tableId});

    @override
    State<OrderScreenContent> createState() => _OrderScreenContentState();
  }

  class _OrderScreenContentState extends State<OrderScreenContent> {
    String _selectedCategory = 'ichimlik';
    final List<Product> _allProducts = [
      Product(id: 1, name: 'cola', price: 12000, category: 'ichimlik'),
      Product(id: 2, name: 'fanta', price: 12000, category: 'ichimlik'),
      Product(id: 3, name: 'choy', price: 5000, category: 'ichimlik'),
      Product(id: 4, name: 'medovik', price: 25000, category: 'tortlar'),
      Product(id: 5, name: 'napoleon', price: 28000, category: 'tortlar'),
      Product(id: 6, name: 'osh', price: 35000, category: 'taom'),
      Product(id: 7, name: 'shashlik', price: 18000, category: 'taom'),
    ];

    final List<CartItem> _cart = [];

    final NumberFormat _currencyFormatter = NumberFormat('#,##0', 'uz_UZ');

    @override
    void initState() {
      super.initState();
      _addToCart(_allProducts.firstWhere((p) => p.name == 'cola'));
    }

    void _addToCart(Product product) {
      setState(() {
        for (var item in _cart) {
          if (item.product.id == product.id) {
            item.quantity++;
            return;
          }
        }
        _cart.add(CartItem(product: product));
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

    int _getQuantityInCart(Product product) {
      return _cart.firstWhere((item) => item.product.id == product.id, orElse: () => CartItem(product: product, quantity: 0)).quantity;
    }

    IconData _getCategoryIcon(String category) {
      switch (category.toLowerCase()) {
        case 'tortlar':
          return Icons.bakery_dining;
        case 'taom':
          return Icons.dinner_dining;
        case 'ichimlik':
          return Icons.local_bar;
        default:
          return Icons.restaurant;
      }
    }

    @override
    Widget build(BuildContext context) {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final baseFontSize = screenWidth * 0.035;
      final isMobile = screenWidth < 600;
      final padding = (screenWidth * 0.03).clamp(8.0, 16.0); // Min padding for small screens

      return Theme(
        data: Theme.of(context).copyWith(
          primaryColor: Colors.teal,
          scaffoldBackgroundColor: Colors.transparent,
          textTheme: Theme.of(context).textTheme.apply(
            fontSizeFactor: screenWidth * 0.0025,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final categoryWidth = isMobile ? screenWidth * 0.25 : screenWidth * 0.15;

                  return Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      children: [
                        _buildAppBar(baseFontSize, screenWidth),
                        SizedBox(height: padding * 0.3),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: categoryWidth,
                                child: _buildCategoriesSection(baseFontSize, padding),
                              ),
                              VerticalDivider(width: padding * 0.5),
                              Flexible(
                                flex: 3,
                                child: _buildProductsSection(baseFontSize, padding, screenWidth),
                              ),
                              VerticalDivider(width: padding * 0.5),
                              Flexible(
                                flex: 2,
                                child: _buildOrderSection(baseFontSize, padding),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: padding * 0.3),
                        _buildBottomActions(baseFontSize, padding, screenWidth),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    Widget _buildAppBar(double fontSize, double screenWidth) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.white, size: fontSize * 1.2),
              SizedBox(width: fontSize * 0.5),
              Text(
                widget.tableId != null ? "Stol ${widget.tableId} • Stol: bo'sh" : "Yangi hisob",
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))],
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
              shadows: [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))],
            ),
          ),
          SizedBox(height: padding * 0.5),
          _buildCategoryButton('tortlar', fontSize, padding),
          SizedBox(height: padding * 0.5),
          _buildCategoryButton('taom', fontSize, padding),
          SizedBox(height: padding * 0.5),
          _buildCategoryButton('ichimlik', fontSize, padding),
        ],
      );
    }

    Widget _buildCategoryButton(String title, double fontSize, double padding) {
      final bool isSelected = _selectedCategory == title;
      return SizedBox(
        height: fontSize * 2.8, // Slightly smaller for small screens
        child: ElevatedButton(
          onPressed: () => setState(() => _selectedCategory = title),
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
                _getCategoryIcon(title),
                size: fontSize * 0.9,
                color: isSelected ? Colors.white : Colors.teal.shade700,
              ),
              SizedBox(width: padding * 0.3),
              Expanded(
                child: Text(
                  title,
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

    Widget _buildProductsSection(double fontSize, double padding, double screenWidth) {
      final productsToShow = _allProducts.where((p) => p.category == _selectedCategory).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Taomlar',
            style: TextStyle(
              fontSize: fontSize * 1.1,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))],
            ),
          ),
          SizedBox(height: padding * 0.3),
          Expanded(
            child: Card(
              elevation: 3,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: EdgeInsets.all(padding * 0.5),
                child: CustomScrollView(
                  slivers: [
                    SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: screenWidth < 600 ? 1.0 : 1.4, // Compact for small screens
                        crossAxisSpacing: padding * 0.5,
                        mainAxisSpacing: padding * 0.5,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final product = productsToShow[index];
                          return _buildProductCard(product, fontSize, padding);
                        },
                        childCount: productsToShow.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget _buildProductCard(Product product, double fontSize, double padding) {
      final int quantityInCart = _getQuantityInCart(product);
      final bool isInCart = quantityInCart > 0;

      return GestureDetector(
        onTap: () => _addToCart(product),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: Matrix4.identity()..scale(isInCart ? 1.02 : 1.0),
          decoration: BoxDecoration(
            border: Border.all(color: isInCart ? Colors.teal.shade700 : Colors.grey.shade200, width: 1),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
            color: Colors.white,
          ),
          padding: EdgeInsets.all(padding * 0.5),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: fontSize * 0.85,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currencyFormatter.format(product.price)} soʻm',
                        style: TextStyle(
                          fontSize: fontSize * 0.75,
                          color: Colors.teal.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isInCart)
                        Text(
                          '$quantityInCart dona',
                          style: TextStyle(
                            fontSize: fontSize * 0.65,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (isInCart)
                Positioned(
                  top: padding * 0.2,
                  right: padding * 0.2,
                  child: Container(
                    padding: EdgeInsets.all(padding * 0.15),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$quantityInCart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize * 0.65,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget _buildOrderSection(double fontSize, double padding) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zakaz  - ${_cart.length}',
            style: TextStyle(
              fontSize: fontSize * 0.9,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))],
            ),
          ),
          SizedBox(height: padding * 0.4),
          Expanded(
            child: Container(
              width: double.infinity, // Ensures the container takes full width
              child: Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: EdgeInsets.all(padding * 0.25),
                  child: _cart.isEmpty
                      ? Center(
                    child: Text(
                      'Savat boʻsh',
                      style: TextStyle(fontSize: fontSize * 0.85, color: Colors.grey.shade600),
                    ),
                  )
                      : ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (context, index) => Divider(height: padding * 0.5),
                    itemBuilder: (context, index) {
                      return _buildOrderItem(_cart[index], fontSize, padding);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    Widget _buildOrderItem(CartItem item, double fontSize, double padding) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            item.product.name,
            style: TextStyle(
              fontSize: fontSize * 0.75,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: padding * 0.1),
          Text(
            '${_currencyFormatter.format(item.product.price * item.quantity)} soʻm',
            style: TextStyle(
              fontSize: fontSize * 0.65,
              color: Colors.teal.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: padding * 0.1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, size: fontSize * 0.65, color: Colors.teal.shade700),
                      padding: EdgeInsets.all(padding * 0.1),
                      constraints: BoxConstraints(),
                      onPressed: () => _updateQuantity(item, -1),
                    ),
                    Text(
                      item.quantity.toString(),
                      style: TextStyle(
                        fontSize: fontSize * 0.7,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, size: fontSize * 0.65, color: Colors.teal.shade700),
                      padding: EdgeInsets.all(padding * 0.1),
                      constraints: BoxConstraints(),
                      onPressed: () => _updateQuantity(item, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    Widget _buildBottomActions(double fontSize, double padding, double screenWidth) {
      final double total = _calculateTotal();
      final bool isCartEmpty = _cart.isEmpty;

      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: padding * 1.0, vertical: padding * 0.4),
              side: BorderSide(color: Colors.teal.shade700, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: Colors.white,
            ),
            child: Text(
              'Bekor qilish',
              style: TextStyle(
                fontSize: fontSize * 0.8,
                color: Colors.teal.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: padding),
          ElevatedButton(
            onPressed: isCartEmpty ? null : () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCartEmpty ? Colors.grey.shade300 : Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: padding * 1.0, vertical: padding * 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 3,
            ),
            child: Text(
              "Zakaz berish (${_currencyFormatter.format(total)} so'm)",
              style: TextStyle(
                fontSize: fontSize * 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
  }