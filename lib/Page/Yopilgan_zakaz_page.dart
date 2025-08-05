import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32/win32.dart';

// AuthServices - avvalgi koddan
class AuthServices {
  static const String baseUrl = "https://sora-b.vercel.app/api";
  static const String userCode = "9090034564";
  static const String password = "0000";

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    print("✅ Token localda saqlandi");
  }

  static Future<String?> getTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> loginAndPrintToken() async {
    final Uri loginUrl = Uri.parse('$baseUrl/auth/login');

    print("Yuborilayotgan ma'lumot: user_code=$userCode, password=$password");

    try {
      final response = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_code': userCode, 'password': password}),
      );

      print("📥 Status Code: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String token = data['token'];
        await saveToken(token);
        print("✅ Token muvaffaqiyatli olindi: $token");
      } else {
        print("❌ Login xatolik. Status: ${response.statusCode}, Body: ${response.body}");
        throw Exception('Login xatolik: ${response.statusCode}');
      }
    } catch (e) {
      print("❗ Xatolik yuz berdi: $e");
      throw Exception('Login xatolik: $e');
    }
  }
}

// OrderService - avvalgi koddan
class OrderService {
  final String baseUrl = "https://sora-b.vercel.app/api";
  String? _token;

  Future<void> _initializeToken() async {
    try {
      _token = await AuthServices.getTokens();
      if (_token == null) {
        await AuthServices.loginAndPrintToken();
        _token = await AuthServices.getTokens();
      }
      if (_token == null) {
        throw Exception('Token olishda xatolik: Token null bo\'lib qoldi');
      }
    } catch (e) {
      throw Exception('Token olishda xatolik: $e');
    }
  }

  Future<List<dynamic>> getPendingPayments() async {
    await _initializeToken();

    if (_token == null) {
      throw Exception('Token topilmadi, iltimos qayta urinib ko\'ring');
    }

    final url = Uri.parse('$baseUrl/orders/pending-payments');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print("✅ Json ma'lumotlar ${response.body}");
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['pending_orders'] != null) {
          return List<dynamic>.from(data['pending_orders']);
        } else {
          return [];
        }
      } else {
        throw Exception('Xato: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print("❗ API xatoligi: $e");
      throw Exception('API xatoligi: $e');
    }
  }

  Future<void> updateReceiptPrinted(String orderId) async {
    await _initializeToken();

    if (_token == null) {
      throw Exception('Token topilmadi, iltimos qayta urinib ko\'ring');
    }

    final url = Uri.parse('$baseUrl/orders/$orderId/receipt-printed');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'receiptPrinted': true}),
      );

      if (response.statusCode == 200) {
        print("✅ Order $orderId receiptPrinted updated to true");
      } else {
        print("❌ Failed to update receiptPrinted: ${response.statusCode} - ${response.body}");
        throw Exception('Failed to update receiptPrinted: ${response.statusCode}');
      }
    } catch (e) {
      print("❗ API xatoligi: $e");
      throw Exception('API xatoligi: $e');
    }
  }
}

// USB Printer Service - yangi
class UsbPrinterService {
  Future<List<int>> loadLogoBytes() async {
    try {
      final file = File('rasm/sara.png');
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes)!;

      final width = image.width;
      final height = image.height;
      final alignedWidth = (width + 7) ~/ 8 * 8;

      List<int> escPosLogo = [];

      // Raster bit image mode command
      escPosLogo.addAll([0x1D, 0x76, 0x30, 0x00]);
      escPosLogo.addAll([
        (alignedWidth ~/ 8) & 0xFF,
        ((alignedWidth ~/ 8) >> 8) & 0xFF,
        height & 0xFF,
        (height >> 8) & 0xFF
      ]);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < alignedWidth; x += 8) {
          int byte = 0;
          for (int bit = 0; bit < 8; bit++) {
            int pixelX = x + bit;
            if (pixelX < width) {
              int pixel = image.getPixel(pixelX, y);
              int luminance = img.getLuminance(pixel);
              if (luminance < 128) {
                byte |= (1 << (7 - bit));
              }
            }
          }
          escPosLogo.add(byte);
        }
      }

      print('✅ Logo yuklandi: ${width}x${height}');
      return escPosLogo;
    } catch (e) {
      print('❌ Logo yuklashda xato: $e');
      return [];
    }
  }


  Future<void> printOrderReceipt(dynamic orderData) async {
    const printerName = 'XP-80C';
    final hPrinter = calloc<HANDLE>();
    final docInfo = calloc<DOC_INFO_1>();

    docInfo.ref.pDocName = TEXT('Restaurant Order Receipt');
    docInfo.ref.pOutputFile = nullptr;
    docInfo.ref.pDatatype = TEXT('RAW');

    final openResult = OpenPrinter(TEXT(printerName), hPrinter, nullptr);
    if (openResult == 0) {
      print('❌ Printer topilmadi: $printerName');
      calloc.free(hPrinter);
      calloc.free(docInfo);
      return;
    }

    final jobId = StartDocPrinter(hPrinter.value, 1, docInfo.cast());
    if (jobId == 0) {
      print('❌ Print Job boshlashda xato.');
      ClosePrinter(hPrinter.value);
      calloc.free(hPrinter);
      calloc.free(docInfo);
      return;
    }

    StartPagePrinter(hPrinter.value);

    // Logo yuklash
    final logoBytes = await loadLogoBytes();

    // Logo markazlash
    List<int> centeredLogo = [];
    if (logoBytes.isNotEmpty) {
      centeredLogo.addAll([0x1B, 0x61, 0x01]); // Center align
      centeredLogo.addAll(logoBytes);
      centeredLogo.addAll([0x1B, 0x61, 0x00]); // Reset align
    }

    // Hozirgi sana va vaqt
    final now = DateTime.now();
    final dateTime = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // API ma'lumotlari
    final orderNumber = orderData['orderNumber'] ?? 'N/A';
    final tableNumber = orderData['tableNumber'] ?? 'N/A';
    final waiterName = orderData['waiterName'] ?? 'N/A';
    final subtotal = orderData['subtotal'] ?? 0;
    final serviceAmount = orderData['serviceAmount'] ?? 0;
    final finalTotal = orderData['finalTotal'] ?? 0;
    final status = orderData['status'] ?? 'N/A';
    final items = orderData['items'] ?? [];

    final List<int> escPosData = <int>[
      0x1B, 0x40,  // Initialize printer

      // Logo (center)
      ...centeredLogo,
      // Manzil va Telefon (bold)
      0x1B, 0x21, 0x08,  // Bold on
      ...centerText('Toshkent shahri, Yunusobod tumani\n'),
      ...centerText('Tel: +998 90 123 45 67\n'),
      0x1B, 0x21, 0x00,  // Normal font
      0x1B, 0x64, 0x01,  // 1 qator bo'sh joy

      // Buyurtma tafsilotlari (center)
      ...centerText('Sana: $dateTime\n'),
      ...centerText('Buyurtma №: $orderNumber\n'),
      ...centerText('Stol №: $tableNumber\n'),
      ...centerText('Ofitsiant: $waiterName\n'),
      ...centerText('Holati: $status\n'),

      // Separator line
      ...centerText('================================\n'),

      // BUYURTMA TAFSILOTLARI Sarlavha
      0x1B, 0x21, 0x08,  // Bold on
      ...centerText('BUYURTMA TAFSILOTLARI:\n'),
      0x1B, 0x21, 0x00,  // Normal font
      ...centerText('--------------------------------\n'),

      // Mahsulotlar ro'yxati
      ...buildItemsList(items),

      ...centerText('--------------------------------\n'),

      // Hisob-kitob qismi (center)
      ...centerText('Mahsulotlar jami: ${formatNumber(subtotal)} so\'m\n'),
      ...centerText('Xizmat haqi: ${formatNumber(serviceAmount)} so\'m\n'),
      ...centerText('--------------------------------\n'),

      // Yakuniy summa (katta va qalin, center)
      0x1B, 0x21, 0x30,  // Double Width & Height
      0x1B, 0x45, 0x01,  // Bold on
      ...centerText('JAMI: ${formatNumber(finalTotal)} so\'m\n'),
      0x1B, 0x21, 0x00,  // Normal font
      0x1B, 0x45, 0x00,  // Bold off

      0x1B, 0x64, 0x01,  // 1 qator bo'sh joy

      // Separator line
      ...centerText('================================\n'),

      // Rahmat matni (bold, center)
      0x1B, 0x21, 0x10,  // Slightly bigger font
      ...centerText('TASHRIFINGIZ UCHUN RAHMAT!\n'),
      ...centerText('Yana kutib qolamiz!\n'),
      0x1B, 0x21, 0x00,  // Normal font

      0x1B, 0x64, 0x04,  // 4 qator bo'sh joy

      // Cut paper
      0x1D, 0x56, 0x00
    ];

    final bytesPointer = calloc<Uint8>(escPosData.length);
    final bytesList = bytesPointer.asTypedList(escPosData.length);
    bytesList.setAll(0, escPosData);

    final bytesWritten = calloc<DWORD>();
    final success = WritePrinter(hPrinter.value, bytesPointer, escPosData.length, bytesWritten);

    if (success == 0) {
      print('❌ Ma\'lumot yuborishda xato.');
      throw Exception('Printer xatosi');
    } else {
      print('✅ Chek muvaffaqiyatli chop etildi! Buyurtma: $orderNumber');
    }

    EndPagePrinter(hPrinter.value);
    EndDocPrinter(hPrinter.value);
    ClosePrinter(hPrinter.value);

    calloc.free(bytesPointer);
    calloc.free(bytesWritten);
    calloc.free(hPrinter);
    calloc.free(docInfo);
  }

// Matnni markazlashtirish funksiyasi
  List<int> centerText(String text) {
    List<int> result = [];
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.isNotEmpty) {
        result.addAll([0x1B, 0x61, 0x01]);  // Center align
        result.addAll(line.codeUnits);
        result.add(0x0A); // New line
      }
    }
    return result;
  }

// Mahsulotlar ro'yxatini formatlab berish
  List<int> buildItemsList(List<dynamic> items) {
    List<int> result = [];
    for (var item in items) {
      final name = item['name'] ?? '';
      final qty = item['quantity'] ?? 1;
      final price = item['price'] ?? 0;
      final line = '$name x$qty - ${formatNumber(price)}\n';
      result.addAll(centerText(line));
    }
    return result;
  }

// Narxni formatlash funksiyasi
  String formatNumber(dynamic number) {
    return number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

}

// Main Page - avvalgi koddan
class MainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ofitsiantlarni Tanlang',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 30,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF0d5720),
        elevation: 0,
        leading: Icon(Icons.restaurant_menu, color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {},
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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

// Order Details Page - avvalgi koddan
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
              'Ofitsiant : $waiterName',
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
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  );
                } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(
                    'Xizmat haqi: 0 so\'m',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  );
                }

                final filteredOrders = snapshot.data!
                    .where((order) => order['waiterName'].toString().toLowerCase().contains(waiterName.toLowerCase()))
                    .toList();
                final totalService = filteredOrders.fold<double>(
                  0,
                      (sum, order) => sum + (order['serviceAmount'] as num).toDouble(),
                );

                return Text(
                  'Umumiy xizmat haqi: ${totalService.toStringAsFixed(0)} so\'m',
                  style: TextStyle(fontSize: 20, color: Colors.white70),
                );
              },
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF0d5720),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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

// Pending Payments Page - print funksiyasi bilan
class PendingPaymentsPage extends StatefulWidget {
  final String waiterName;

  const PendingPaymentsPage({required this.waiterName});

  @override
  _PendingPaymentsPageState createState() => _PendingPaymentsPageState();
}

class _PendingPaymentsPageState extends State<PendingPaymentsPage> {
  final OrderService orderService = OrderService();
  final UsbPrinterService printerService = UsbPrinterService();
  Future<List<dynamic>>? pendingPayments;

  @override
  void initState() {
    super.initState();
    pendingPayments = orderService.getPendingPayments();
  }

  // Print funksiyasi
  Future<void> _printOrder(dynamic order) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Chek chop etilmoqda...'),
            ],
          ),
        ),
      );

      // Chekni chop etish
      await printerService.printOrderReceipt(order);

      // API da receiptPrinted ni true qilish
      await orderService.updateReceiptPrinted(order['_id']);

      Navigator.of(context).pop(); // Loading dialog yopish

      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Chek muvaffaqiyatli chop etildi!'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh qilish
      setState(() {
        pendingPayments = orderService.getPendingPayments();
      });

    } catch (e) {
      Navigator.of(context).pop(); // Loading dialog yopish

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Chek chop etishda xato: $e'),
          backgroundColor: Colors.red,
        ),
      );

      print('❌ Print xatosi: $e');
    }
  }

  // Responsive grid parameters calculator
  Map<String, dynamic> _getResponsiveGridParams(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount;
    double childAspectRatio;
    double cardWidth;

    if (screenWidth < 600) {
      crossAxisCount = 2;
      childAspectRatio = 0.85;
      cardWidth = (screenWidth - 32 - 8) / 2;
    } else if (screenWidth < 900) {
      crossAxisCount = 3;
      childAspectRatio = 0.9;
      cardWidth = (screenWidth - 32 - 16) / 3;
    } else if (screenWidth < 1200) {
      crossAxisCount = 4;
      childAspectRatio = 0.95;
      cardWidth = (screenWidth - 32 - 24) / 4;
    } else if (screenWidth < 1600) {
      crossAxisCount = 5;
      childAspectRatio = 1.0;
      cardWidth = (screenWidth - 32 - 32) / 5;
    } else {
      crossAxisCount = 6;
      childAspectRatio = 1.1;
      cardWidth = (screenWidth - 32 - 40) / 6;
    }

    return {
      'crossAxisCount': crossAxisCount,
      'childAspectRatio': childAspectRatio,
      'cardWidth': cardWidth,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: pendingPayments,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
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
            .where((order) => order['waiterName'].toString().toLowerCase().contains(widget.waiterName.toLowerCase()))
            .toList();

        if (filteredOrders.isEmpty) {
          return Center(
            child: Text(
              '${widget.waiterName} uchun buyurtma topilmadi.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        final gridParams = _getResponsiveGridParams(context);

        return GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridParams['crossAxisCount'],
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: gridParams['childAspectRatio'],
          ),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final order = filteredOrders[index];
            return _buildOrderCard(order, gridParams['cardWidth']);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(dynamic order, double cardWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double titleFontSize = (cardWidth * 0.06).clamp(14.0, 18.0);
        double infoFontSize = (cardWidth * 0.04).clamp(10.0, 14.0);
        double iconSize = (cardWidth * 0.06).clamp(14.0, 18.0);
        double padding = (cardWidth * 0.03).clamp(6.0, 12.0);

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt, color: Colors.blueAccent, size: iconSize),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '№ ${order['orderNumber'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: padding * 0.5),
                Expanded(
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.table_restaurant, 'Stol: ${order['tableNumber'] ?? 'N/A'}', infoFontSize, iconSize * 0.8),
                      _buildInfoRow(Icons.fastfood, 'Mahsulot: ${order['itemsCount'] ?? 0}', infoFontSize, iconSize * 0.8),
                      _buildInfoRow(Icons.monetization_on, 'Jami: ${order['subtotal'] ?? 0} so\'m', infoFontSize, iconSize * 0.8),
                      _buildInfoRow(Icons.room_service, 'Xizmat: ${order['serviceAmount'] ?? 0} so\'m', infoFontSize, iconSize * 0.8),
                      _buildInfoRow(Icons.account_balance_wallet, 'Yakuniy: ${order['finalTotal'] ?? 0} so\'m', infoFontSize, iconSize * 0.8),
                      _buildInfoRow(Icons.check_circle, 'Holati: ${order['status'] ?? 'N/A'}', infoFontSize, iconSize * 0.8, color: Colors.green),
                    ],
                  ),
                ),
                SizedBox(height: padding),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: cardWidth * 0.8,
                    height: (cardWidth * 0.1).clamp(30.0, 40.0),
                    child: ElevatedButton.icon(
                      onPressed: order['receiptPrinted'] == true ? null : () => _printOrder(order),
                      icon: Icon(Icons.print, size: iconSize * 0.8),
                      label: Text(
                        order['receiptPrinted'] == true ? 'Chop etilgan' : 'Chek chiqarish',
                        style: TextStyle(fontSize: infoFontSize),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: order['receiptPrinted'] == true ? Colors.grey : Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text, double fontSize, double iconSize, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.grey.shade600, size: iconSize),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                color: color ?? Colors.black87,
                fontWeight: color != null ? FontWeight.w500 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}