  import 'package:flutter/material.dart';
  import 'package:intl/intl.dart';
  import 'dart:io';

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
          {'name': 'Choy (ko\'k)', 'price': 3000, 'quantity': 1},
          {'name': 'Somsa (go\'shtli)', 'price': 9000, 'quantity': 1},
          {'name': 'Somsa (go\'shtli)', 'price': 9000, 'quantity': 1},
          {'name': 'Somsa (go\'shtli)', 'price': 9000, 'quantity': 1},
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
        receipt.writeln(centerText('Buyurtma: ${order['orderId']}', 32));
        receipt.writeln(centerText('Stol: $_selectedTableId', 32));
        receipt.writeln(centerText('Vaqt: ${DateFormat('d MMMM yyyy, HH:mm', 'uz').format(DateTime.now())}', 32));
        receipt.writeln(centerText('--------------------', 32));
        receipt.writeln(centerText('Mahsulotlar:', 32));
        for (var item in order['items'] as List) {
          receipt.writeln('${item['name'].padRight(20)} ${item['quantity'] ?? 1}x ${NumberFormat.decimalPattern('uz').format(item['price'])} so\'m');
        }
        receipt.writeln(centerText('--------------------', 32));
        receipt.writeln(centerText('Jami: ${NumberFormat.decimalPattern('uz').format(order['sum'])} so\'m', 32));
        receipt.writeln(centerText('--- Rahmat! ---', 32));
        receipt.writeln('\n\n\n\n\n');
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
          final baseFontSize = MediaQuery.of(context).textScaler.scale(16.0); // biroz kattalashtirildi

          return AlertDialog(
            titlePadding: EdgeInsets.only(top: baseFontSize),
            contentPadding: EdgeInsets.symmetric(horizontal: baseFontSize * 0.8, vertical: baseFontSize * 0.6),
            title: Column(
              children: [
                Icon(Icons.receipt_long_rounded, size: baseFontSize * 3.5, color: Colors.teal),
                SizedBox(height: baseFontSize * 0.5),
                Text(
                  'Restoran Cheki',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: baseFontSize * 1.2,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            content: Container(
              width: 340,
              child: Card(
                elevation: 5,
                color: const Color(0xFFFDFDFD),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(baseFontSize * 0.8),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Buyurtma: ${order['orderId']}',
                          style: TextStyle(fontSize: baseFontSize, fontFamily: 'Courier'),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Stol: $_selectedTableId',
                          style: TextStyle(fontSize: baseFontSize, fontFamily: 'Courier'),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Vaqt: ${DateFormat('d MMMM yyyy, HH:mm', 'uz').format(DateTime.now())}',
                          style: TextStyle(fontSize: baseFontSize, fontFamily: 'Courier'),
                          textAlign: TextAlign.center,
                        ),
                        Divider(thickness: 1.2, height: baseFontSize * 1.2),
                        Text(
                          'Mahsulotlar:',
                          style: TextStyle(
                            fontSize: baseFontSize * 1.1,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Courier',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: baseFontSize * 0.3),
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1.5),
                          },
                          children: (order['items'] as List).map((item) {
                            return TableRow(
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: baseFontSize * 0.25),
                                  child: Text(
                                    item['name'],
                                    style: TextStyle(fontFamily: 'Courier', fontSize: baseFontSize * 0.95),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: baseFontSize * 0.25),
                                  child: Text(
                                    '${item['quantity'] ?? 1}x',
                                    style: TextStyle(fontFamily: 'Courier', fontSize: baseFontSize * 0.95),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: baseFontSize * 0.25),
                                  child: Text(
                                    '${NumberFormat.decimalPattern('uz').format(item['price'])} so\'m',
                                    style: TextStyle(fontFamily: 'Courier', fontSize: baseFontSize * 0.95),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                        Divider(thickness: 1.2, height: baseFontSize * 1.2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Jami:',
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: baseFontSize * 1.1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${NumberFormat.decimalPattern('uz').format(order['sum'])} so\'m',
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: baseFontSize * 1.1,
                                fontWeight: FontWeight.w700,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: baseFontSize * 0.5),
                        Text(
                          '--- Rahmat! ---',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: baseFontSize * 1.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Bekor qilish', style: TextStyle(fontSize: baseFontSize * 0.9)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _printCheck(order);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: baseFontSize * 1.2, vertical: baseFontSize * 0.8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                child: Text('Chop etish', style: TextStyle(fontSize: baseFontSize * 0.9)),
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
                  padding: EdgeInsets.symmetric(horizontal: baseFontSize * 1.5, vertical: baseFontSize * 0.8),
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
                  padding: EdgeInsets.symmetric(horizontal: baseFontSize * 1.5, vertical: baseFontSize * 0.8),
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
        bottomNavigationBar: Padding(
          padding: EdgeInsets.all(baseFontSize * 0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.exit_to_app, size: baseFontSize * 1.2),
                label: Text("Chiqish", style: TextStyle(fontSize: baseFontSize * 0.9)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: baseFontSize * 1.5, vertical: baseFontSize * 0.8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
    }
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
                    trailing: Text(
                      "${item['quantity'] ?? 1}x ${NumberFormat.decimalPattern('uz').format(item['price'])} so'm",
                      style: TextStyle(fontSize: baseFontSize * 0.9),
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
      double total = 0;
      for (var item in _cart) {
        total += item.product.price * item.quantity;
      }
      return total;
    }

    int _getQuantityInCart(Product product) {
      try {
        return _cart.firstWhere((item) => item.product.id == product.id).quantity;
      } catch (e) {
        return 0;
      }
    }

    IconData _getCategoryIcon(String category) {
      switch (category.toLowerCase()) {
        case 'tortlar':
          return Icons.bakery_dining; // More specific bakery icon
        case 'taom':
          return Icons.dinner_dining; // More elegant dining icon
        case 'ichimlik':
          return Icons.local_bar; // Stylish drink icon
        default:
          return Icons.restaurant;
      }
    }

    IconData _getProductIcon(Product product) {
      switch (product.name.toLowerCase()) {
        case 'cola':
          return Icons.local_cafe; // Cola-specific drink icon
        case 'fanta':
          return Icons.local_bar; // Vibrant drink icon
        case 'choy':
          return Icons.water_drop; // Tea-specific icon
        case 'medovik':
          return Icons.bakery_dining; // Bakery icon for honey cake
        case 'napoleon':
          return Icons.cake_outlined; // Distinct cake icon
        case 'osh':
          return Icons.soup_kitchen; // Soup/bowl icon for osh
        case 'shashlik':
          return Icons.cookie_outlined; // BBQ-specific icon
        default:
          return Icons.restaurant;
      }
    }

    Color _getProductIconColor(Product product) {
      switch (product.name.toLowerCase()) {
        case 'cola':
          return Colors.grey.shade800;
        case 'fanta':
          return Colors.orange.shade600;
        case 'choy':
          return Colors.brown.shade400;
        case 'medovik':
          return Colors.amber.shade600;
        case 'napoleon':
          return Colors.pink.shade300;
        case 'osh':
          return Colors.green.shade600;
        case 'shashlik':
          return Colors.red.shade600;
        default:
          return Colors.teal.shade800;
      }
    }

    @override
    Widget build(BuildContext context) {
      final baseFontSize = MediaQuery.of(context).textScaler.scale(16.0); // Increased base font size
      final isMobile = MediaQuery.of(context).size.width < 600;
      final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width <= 1200;

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
                colors: [Colors.teal.shade700, Colors.teal.shade100],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final categoryWidth = isMobile ? 180.0 : 220.0; // Increased width
                final maxCrossAxisExtent = isMobile ? 160.0 : isTablet ? 200.0 : 220.0; // Increased grid size

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    baseFontSize * 0.6,
                    baseFontSize * 0.9,
                    baseFontSize * 0.6,
                    baseFontSize * 0.6,
                  ),
                  child: Column(
                    children: [
                      _buildAppBar(baseFontSize),
                      SizedBox(height: baseFontSize * 0.6),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: categoryWidth,
                              child: _buildCategoriesSection(baseFontSize),
                            ),
                            VerticalDivider(width: baseFontSize * 0.6),
                            Expanded(
                              child: _buildProductsSection(baseFontSize, maxCrossAxisExtent),
                            ),
                            VerticalDivider(width: baseFontSize * 0.6),
                            Expanded(
                              child: _buildOrderSection(baseFontSize),
                            ),
                          ],
                        ),
                      ),
                      _buildBottomActions(baseFontSize),
                    ],
                  ),
                );
              },
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
                widget.tableId != null ? "Stol ${widget.tableId} • Stol: bo'sh" : "Yangi hisob",
                style: TextStyle(fontSize: fontSize * 1.0, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close, size: fontSize * 1.4, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    Widget _buildCategoriesSection(double fontSize) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kategoriyalar',
            style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: fontSize * 0.5),
          _buildCategoryButton('tortlar', fontSize),
          SizedBox(height: fontSize * 0.5),
          _buildCategoryButton('taom', fontSize),
          SizedBox(height: fontSize * 0.5),
          _buildCategoryButton('ichimlik', fontSize),
        ],
      );
    }

    Widget _buildCategoryButton(String title, double fontSize) {
      final bool isSelected = _selectedCategory == title;
      return SizedBox(
        width: double.infinity,
        height: 70, // Increased height for larger buttons
        child: ElevatedButton(
          onPressed: () => setState(() => _selectedCategory = title),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.teal.shade800 : Colors.white,
            foregroundColor: isSelected ? Colors.white : Colors.teal.shade800,
            elevation: isSelected ? 4 : 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: EdgeInsets.symmetric(horizontal: fontSize * 0.7, vertical: fontSize * 0.7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                _getCategoryIcon(title),
                size: fontSize * 1.3, // Slightly larger icon
                color: isSelected ? Colors.white : Colors.teal.shade800,
              ),
              SizedBox(width: fontSize * 0.5),
              Text(
                title,
                style: TextStyle(
                  fontSize: fontSize * 1.1,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildProductsSection(double fontSize, double maxCrossAxisExtent) {
      final productsToShow = _allProducts.where((p) => p.category == _selectedCategory).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Taomlar',
            style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: fontSize * 0.5),
          Expanded(
            child: Card(
              elevation: 3, // Slightly increased elevation
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: EdgeInsets.all(fontSize * 0.6),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: maxCrossAxisExtent,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: fontSize * 0.6,
                    mainAxisSpacing: fontSize * 0.6,
                  ),
                  itemCount: productsToShow.length,
                  itemBuilder: (context, index) {
                    final product = productsToShow[index];
                    return _buildProductCard(product, fontSize);
                  },
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget _buildProductCard(Product product, double fontSize) {
      final int quantityInCart = _getQuantityInCart(product);
      final bool isInCart = quantityInCart > 0;

      return GestureDetector(
        onTap: () => _addToCart(product),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border.all(color: isInCart ? Colors.teal.shade800 : Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
            color: Colors.white,
          ),
          padding: EdgeInsets.all(fontSize * 0.6),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(fontSize: fontSize * 1.0, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Expanded(
                    child: Center(
                      child: Icon(
                        _getProductIcon(product),
                        size: fontSize * 1.5, // Reduced icon size
                        color: _getProductIconColor(product),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currencyFormatter.format(product.price)} soʻm',
                        style: TextStyle(fontSize: fontSize * 0.9, color: Colors.teal.shade800, fontWeight: FontWeight.w600),
                      ),
                      if (isInCart)
                        Text(
                          '$quantityInCart dona',
                          style: TextStyle(fontSize: fontSize * 0.8, color: Colors.black54),
                        ),
                    ],
                  ),
                ],
              ),
              if (isInCart)
                Positioned(
                  top: fontSize * 0.2,
                  right: fontSize * 0.2,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: fontSize * 1.3,
                      minHeight: fontSize * 1.3,
                    ),
                    padding: EdgeInsets.all(fontSize * 0.2),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade800,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$quantityInCart',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize * 0.8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget _buildOrderSection(double fontSize) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zakaz [${_cart.length}]',
            style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: fontSize * 0.5),
          Expanded(
            child: Card(
              elevation: 3,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: EdgeInsets.all(fontSize * 0.6),
                child: _cart.isEmpty
                    ? Center(child: Text('Savat boʻsh', style: TextStyle(fontSize: fontSize * 1.0)))
                    : ListView.separated(
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    return _buildOrderItem(_cart[index], fontSize);
                  },
                  separatorBuilder: (context, index) => Divider(height: fontSize * 1.3),
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget _buildOrderItem(CartItem item, double fontSize) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: fontSize * 0.4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: TextStyle(fontSize: fontSize * 1.0, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: fontSize * 0.3),
                  Text(
                    '${_currencyFormatter.format(item.product.price * item.quantity)} soʻm',
                    style: TextStyle(fontSize: fontSize * 0.9, color: Colors.teal.shade800, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove, size: fontSize * 1.0, color: Colors.teal.shade800),
                    padding: EdgeInsets.all(fontSize * 0.4),
                    constraints: BoxConstraints(minWidth: fontSize * 2.0, minHeight: fontSize * 2.0),
                    onPressed: () => _updateQuantity(item, -1),
                  ),
                  Text(
                    item.quantity.toString(),
                    style: TextStyle(fontSize: fontSize * 1.0, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.add, size: fontSize * 1.0, color: Colors.teal.shade800),
                    padding: EdgeInsets.all(fontSize * 0.4),
                    constraints: BoxConstraints(minWidth: fontSize * 2.0, minHeight: fontSize * 2.0),
                    onPressed: () => _updateQuantity(item, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildBottomActions(double fontSize) {
      final double total = _calculateTotal();
      final bool isCartEmpty = _cart.isEmpty;

      return Padding(
        padding: EdgeInsets.only(top: fontSize * 0.6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: fontSize * 1.7, vertical: fontSize * 0.9),
                side: BorderSide(color: Colors.teal.shade800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 3,
              ),
              child: Text(
                'Bekor qilish',
                style: TextStyle(fontSize: fontSize * 1.0, color: Colors.teal.shade800),
              ),
            ),
            SizedBox(width: fontSize * 0.6),
            ElevatedButton(
              onPressed: isCartEmpty
                  ? null
                  : () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isCartEmpty ? Colors.grey.shade300 : Colors.teal.shade800,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: fontSize * 1.7, vertical: fontSize * 0.9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 3,
              ),
              child: Text(
                "Zakaz berish (${_currencyFormatter.format(total)} so'm)",
                style: TextStyle(fontSize: fontSize * 1.0, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }