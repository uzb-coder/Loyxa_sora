import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32/win32.dart';

// Models
class OrderModel {
  final String id;
  final String orderNumber;
  final String tableNumber;
  final String waiterName;
  final int itemsCount;
  final double subtotal;
  final double serviceAmount;
  final double finalTotal;
  final String status;
  final bool receiptPrinted;
  final DateTime createdAt;
  final List<OrderItem> items;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.tableNumber,
    required this.waiterName,
    required this.itemsCount,
    required this.subtotal,
    required this.serviceAmount,
    required this.finalTotal,
    required this.status,
    required this.receiptPrinted,
    required this.createdAt,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['_id'] ?? '',
      orderNumber: json['orderNumber']?.toString() ?? 'N/A',
      tableNumber: json['tableNumber']?.toString() ?? 'N/A',
      waiterName: json['waiterName']?.toString() ?? 'N/A',
      itemsCount: json['itemsCount'] ?? 0,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      serviceAmount: (json['serviceAmount'] ?? 0).toDouble(),
      finalTotal: (json['finalTotal'] ?? 0).toDouble(),
      status: json['status']?.toString() ?? 'N/A',
      receiptPrinted: json['receiptPrinted'] ?? false,
      createdAt:
          json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ??
                  DateTime.now()
              : DateTime.now(),
      items:
          json['items'] != null
              ? (json['items'] as List)
                  .map((item) => OrderItem.fromJson(item))
                  .toList()
              : [],
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'orderNumber': orderNumber,
    'tableNumber': tableNumber,
    'waiterName': waiterName,
    'itemsCount': itemsCount,
    'subtotal': subtotal,
    'serviceAmount': serviceAmount,
    'finalTotal': finalTotal,
    'status': status,
    'receiptPrinted': receiptPrinted,
    'createdAt': createdAt.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;

  OrderItem({required this.name, required this.quantity, required this.price});

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name']?.toString() ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'price': price,
  };
}

class AuthResponse {
  final bool success;
  final String token;
  final String message;

  AuthResponse({
    required this.success,
    required this.token,
    required this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] ?? false,
      token: json['token'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String message;

  ApiResponse({required this.success, this.data, required this.message});
}

// AuthServices
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

  static Future<ApiResponse<String>> loginAndPrintToken() async {
    final Uri loginUrl = Uri.parse('$baseUrl/auth/login');

    try {
      final response = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_code': userCode, 'password': password}),
      );

      if (response.statusCode == 200) {
        final AuthResponse authResponse = AuthResponse.fromJson(
          jsonDecode(response.body),
        );
        await saveToken(authResponse.token);
        return ApiResponse(
          success: true,
          data: authResponse.token,
          message: 'Login muvaffaqiyatli',
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Login xatolik: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Login xatolik: $e');
    }
  }
}

// OrderService
class OrderService {
  final String baseUrl = "https://sora-b.vercel.app/api";
  String? _token;
  static const String _cacheKey = 'pending_orders_cache';
  static const String _cacheTimestampKey = 'pending_orders_timestamp';
  static const int _cacheDurationMinutes = 5; // Kesh muddati 5 daqiqa

  Future<void> _initializeToken() async {
    try {
      _token = await AuthServices.getTokens();
      if (_token == null) {
        final result = await AuthServices.loginAndPrintToken();
        if (result.success) {
          _token = result.data;
        } else {
          throw Exception(result.message);
        }
      }
    } catch (e) {
      throw Exception('Token olishda xatolik: $e');
    }
  }

  Future<void> _saveToCache(List<OrderModel> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final ordersJson =
        orders.map((order) => jsonEncode(order.toJson())).toList();
    await prefs.setString(_cacheKey, jsonEncode(ordersJson));
    await prefs.setString(_cacheTimestampKey, DateTime.now().toIso8601String());
  }

  Future<List<OrderModel>?> _getFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_cacheKey);
    final timestamp = prefs.getString(_cacheTimestampKey);

    if (cachedData != null && timestamp != null) {
      final cacheTime = DateTime.tryParse(timestamp);
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime).inMinutes <
              _cacheDurationMinutes) {
        final ordersJson = jsonDecode(cachedData) as List;
        return ordersJson
            .map((json) => OrderModel.fromJson(jsonDecode(json)))
            .toList();
      }
    }
    return null;
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
  }

  Future<ApiResponse<List<OrderModel>>> getPendingPayments({
    DateTime? startDate,
    DateTime? endDate,
    String? waiterName,
  }) async {
    await _initializeToken();

    if (_token == null) {
      return ApiResponse(success: false, message: 'Token topilmadi');
    }

    // Keshdan ma'lumot olish
    final cachedOrders = await _getFromCache();
    if (cachedOrders != null) {
      List<OrderModel> orders = cachedOrders;

      // Keshdagi ma'lumotlarga filtr qo'llash
      if (startDate != null && endDate != null) {
        orders =
            orders.where((order) {
              return order.createdAt.isAfter(
                    startDate.subtract(Duration(days: 1)),
                  ) &&
                  order.createdAt.isBefore(endDate.add(Duration(days: 1)));
            }).toList();
      }

      if (waiterName != null && waiterName.isNotEmpty) {
        orders =
            orders
                .where(
                  (order) => order.waiterName.toLowerCase().contains(
                    waiterName.toLowerCase(),
                  ),
                )
                .toList();
      }

      return ApiResponse(
        success: true,
        data: orders,
        message: 'Ma\'lumotlar keshdan yuklandi',
      );
    }

    // Agar kesh bo'sh yoki muddati o'tgan bo'lsa, serverdan olish
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
        print("APIIII :::::::::::::::: {$response.body}");

        final data = jsonDecode(response.body);
        if (data['success'] == true && data['pending_orders'] != null) {
          List<OrderModel> orders =
              (data['pending_orders'] as List)
                  .map((order) => OrderModel.fromJson(order))
                  .toList();

          // Filtrlar qo'llash
          if (startDate != null && endDate != null) {
            orders =
                orders.where((order) {
                  return order.createdAt.isAfter(
                        startDate.subtract(Duration(days: 1)),
                      ) &&
                      order.createdAt.isBefore(endDate.add(Duration(days: 1)));
                }).toList();
          }

          if (waiterName != null && waiterName.isNotEmpty) {
            orders =
                orders
                    .where(
                      (order) => order.waiterName.toLowerCase().contains(
                        waiterName.toLowerCase(),
                      ),
                    )
                    .toList();
          }

          // Keshga saqlash
          await _saveToCache(orders);

          return ApiResponse(
            success: true,
            data: orders,
            message: 'Ma\'lumotlar muvaffaqiyatli yuklandi',
          );
        } else {
          return ApiResponse(
            success: true,
            data: [],
            message: 'Ma\'lumotlar topilmadi',
          );
        }
      } else {
        return ApiResponse(
          success: false,
          message: 'Server xatosi: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'API xatoligi: $e');
    }
  }

  Future<ApiResponse<bool>> updateReceiptPrinted(String orderId) async {
    await _initializeToken();

    if (_token == null) {
      return ApiResponse(success: false, message: 'Token topilmadi');
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
        // Chek chop etilgandan so'ng keshni tozalash
        await _clearCache();
        return ApiResponse(
          success: true,
          data: true,
          message: 'Chek holati yangilandi',
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Chek holatini yangilashda xatolik: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'API xatoligi: $e');
    }
  }
}

// USB Printer Service
class UsbPrinterService {
  Future<List<String>> getConnectedPrinters() async {
    final flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
    final pcbNeeded = calloc<DWORD>();
    final pcReturned = calloc<DWORD>();

    EnumPrinters(flags, nullptr, 2, nullptr, 0, pcbNeeded, pcReturned);

    final cbBuf = pcbNeeded.value;
    final pPrinterEnum = calloc<BYTE>(cbBuf);

    final result = EnumPrinters(
      flags,
      nullptr,
      2,
      pPrinterEnum,
      cbBuf,
      pcbNeeded,
      pcReturned,
    );

    List<String> printerNames = [];
    if (result != 0) {
      final printerInfo = pPrinterEnum.cast<PRINTER_INFO_2>();
      final count = pcReturned.value;

      for (var i = 0; i < count; i++) {
        final printerName =
            printerInfo.elementAt(i).ref.pPrinterName.toDartString();
        final portName = printerInfo.elementAt(i).ref.pPortName.toDartString();

        if (portName.toUpperCase().contains('USB')) {
          printerNames.add(printerName);
        }
      }
    }

    calloc.free(pcbNeeded);
    calloc.free(pcReturned);
    calloc.free(pPrinterEnum);

    return printerNames;
  }

  Future<List<int>> loadLogoBytes() async {
    try {
      ByteData byteData = await rootBundle.load('assets/rasm/sara.png');
      final bytes = byteData.buffer.asUint8List();
      final image = img.decodeImage(bytes)!;

      final width = image.width;
      final height = image.height;
      final alignedWidth = (width + 7) ~/ 8 * 8;

      List<int> escPosLogo = [];
      escPosLogo.addAll([0x1D, 0x76, 0x30, 0x00]);
      escPosLogo.addAll([
        (alignedWidth ~/ 8) & 0xFF,
        ((alignedWidth ~/ 8) >> 8) & 0xFF,
        height & 0xFF,
        (height >> 8) & 0xFF,
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

      return escPosLogo;
    } catch (e) {
      print('❌ Logo yuklashda xato: $e');
      return [];
    }
  }

  Future<ApiResponse<bool>> printOrderReceipt(OrderModel order) async {
    final printers = await getConnectedPrinters();
    if (printers.isEmpty) {
      return ApiResponse(success: false, message: 'USB printer topilmadi');
    }

    final printerName = printers.first;
    final hPrinter = calloc<HANDLE>();
    final docInfo = calloc<DOC_INFO_1>();

    docInfo.ref.pDocName = TEXT('Restaurant Order Receipt');
    docInfo.ref.pOutputFile = nullptr;
    docInfo.ref.pDatatype = TEXT('RAW');

    try {
      final openResult = OpenPrinter(TEXT(printerName), hPrinter, nullptr);
      if (openResult == 0) {
        return ApiResponse(
          success: false,
          message: 'Printer ochishda xato: $printerName',
        );
      }

      final jobId = StartDocPrinter(hPrinter.value, 1, docInfo.cast());
      if (jobId == 0) {
        ClosePrinter(hPrinter.value);
        return ApiResponse(
          success: false,
          message: 'Print Job boshlashda xato',
        );
      }

      StartPagePrinter(hPrinter.value);

      final logoBytes = await loadLogoBytes();
      List<int> centeredLogo = [];
      if (logoBytes.isNotEmpty) {
        centeredLogo.addAll([0x1B, 0x61, 0x01]);
        centeredLogo.addAll(logoBytes);
        centeredLogo.addAll([0x1B, 0x61, 0x00]);
      }

      final now = DateTime.now();
      final dateTime =
          '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final List<int> escPosData = <int>[
        0x1B,
        0x40,
        ...centeredLogo,
        ...centerBoldText('Namangan shahri, Namangan tumani'),
        0x1B,
        0x64,
        0x01,
        ...centerBoldText('Tel: +998 90 123 45 67'),
        0x1B,
        0x64,
        0x01,
        ...centerBoldText('Sana: $dateTime'),
        0x1B,
        0x64,
        0x01,
        ...centerBoldText(
          'Buyurtma №: ${order.orderNumber}  |  Stol №: ${order.tableNumber}',
        ),
        0x1B,
        0x64,
        0x01,
        ...centerBoldText('Ofitsiant: ${order.waiterName}'),
        0x1B,
        0x64,
        0x01,
        ...centerBoldText('================================'),
        0x1B,
        0x64,
        0x01,
        ...centerBoldText(
          'Mahsulotlar jami: ${formatNumber(order.subtotal)} so\'m',
        ),
        0x1B,
        0x64,
        0x01,
        ...centerBoldText(
          'Xizmat haqi: ${formatNumber(order.serviceAmount)} so\'m',
        ),
        0x1B,
        0x64,
        0x01,
        ...centerBoldText('JAMI: ${formatNumber(order.finalTotal)} so\'m'),
        0x1B,
        0x64,
        0x01,
        ...centerBoldText('================================'),
        0x1B,
        0x64,
        0x01,
        ...centerBoldText('TASHRIFINGIZ UCHUN RAHMAT!'),
        0x1B,
        0x64,
        0x04,
        0x1D,
        0x56,
        0x00,
      ];

      final bytesPointer = calloc<Uint8>(escPosData.length);
      final bytesList = bytesPointer.asTypedList(escPosData.length);
      bytesList.setAll(0, escPosData);

      final bytesWritten = calloc<DWORD>();
      final success = WritePrinter(
        hPrinter.value,
        bytesPointer,
        escPosData.length,
        bytesWritten,
      );

      EndPagePrinter(hPrinter.value);
      EndDocPrinter(hPrinter.value);
      ClosePrinter(hPrinter.value);

      calloc.free(bytesPointer);
      calloc.free(bytesWritten);
      calloc.free(hPrinter);
      calloc.free(docInfo);

      if (success == 0) {
        return ApiResponse(
          success: false,
          message: 'Ma\'lumot yuborishda xato',
        );
      } else {
        return ApiResponse(
          success: true,
          data: true,
          message: 'Chek muvaffaqiyatli chop etildi',
        );
      }
    } catch (e) {
      calloc.free(hPrinter);
      calloc.free(docInfo);
      return ApiResponse(success: false, message: 'Chop etishda xato: $e');
    }
  }

  List<int> centerBoldText(String text) {
    return [
      0x1B, 0x61, 0x01, // Center
      0x1B, 0x21, 0x10, // Double Height, Normal Width
      0x1B, 0x45, 0x01, // Bold on
      ...text.codeUnits,
      0x0A, // New line
      0x1B, 0x45, 0x00, // Bold off
      0x1B, 0x21, 0x00, // Font normal
    ];
  }

  String formatNumber(num value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

// Main Page
class MainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ofitsiantlarni Tanlang',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF0d5720),
        elevation: 0,
        leading: Icon(Icons.restaurant_menu, color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0d5720).withOpacity(0.1), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            _buildWaiterButton(context, 'Nozima', Icons.person),
            SizedBox(height: 16),
            _buildWaiterButton(context, 'Zilola', Icons.person),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiterButton(
    BuildContext context,
    String waiterName,
    IconData icon,
  ) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Color(0xFF0d5720).withOpacity(0.8), Color(0xFF0d5720)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          leading: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            radius: 25,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          title: Text(
            waiterName.toUpperCase(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: Colors.white,
            size: 20,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderTablePage(waiterName: waiterName),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Order Table Page
class OrderTablePage extends StatefulWidget {
  final String waiterName;

  const OrderTablePage({required this.waiterName});

  @override
  _OrderTablePageState createState() => _OrderTablePageState();
}

class _OrderTablePageState extends State<OrderTablePage> {
  final OrderService orderService = OrderService();
  final UsbPrinterService printerService = UsbPrinterService();

  DateTime? startDate;
  DateTime? endDate;
  List<OrderModel> allOrders = [];
  List<OrderModel> filteredOrders = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => isLoading = true);

    final result = await orderService.getPendingPayments(
      startDate: startDate,
      endDate: endDate,
      waiterName: widget.waiterName,
    );

    setState(() {
      isLoading = false;
      if (result.success && result.data != null) {
        allOrders = result.data!;
        filteredOrders = allOrders;
      } else {
        allOrders = [];
        filteredOrders = [];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: Colors.red),
        );
      }
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 30)),
      initialDateRange:
          startDate != null && endDate != null
              ? DateTimeRange(start: startDate!, end: endDate!)
              : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF0d5720),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _loadOrders();
    }
  }

  void _clearDateFilter() {
    setState(() {
      startDate = null;
      endDate = null;
    });
    _loadOrders();
  }

  Future<void> _printOrder(OrderModel order) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(color: Color(0xFF0d5720)),
                  SizedBox(width: 20),
                  Text('Chek chop etilmoqda...'),
                ],
              ),
            ),
      );

      final printResult = await printerService.printOrderReceipt(order);
      Navigator.of(context).pop();

      if (printResult.success) {
        final updateResult = await orderService.updateReceiptPrinted(order.id);

        if (updateResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Chek muvaffaqiyatli chop etildi!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadOrders();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Chek chop etildi, lekin holat yangilanmadi'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${printResult.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Xato: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 600 ? 12.0 : 14.0;

    // Calculate totals
    final totalService = filteredOrders.fold<double>(
      0,
      (sum, order) => sum + order.serviceAmount,
    );
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Color(0xFF0d5720),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ofitsiant: ${widget.waiterName}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Ofitsiant xaqi: ${printerService.formatNumber(totalService)} so\'m',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : filteredOrders.isEmpty
              ? Center(child: Text('Ma\'lumotlar topilmadi'))
              : LayoutBuilder(
                builder: (context, constraints) {
                  return Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          minHeight: constraints.maxHeight,
                        ),
                        child: Container(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (startDate != null && endDate != null)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${DateFormat('dd.MM.yyyy').format(startDate!)} - ${DateFormat('dd.MM.yyyy').format(endDate!)}',
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.close),
                                        onPressed: _clearDateFilter,
                                      ),
                                    ],
                                  ),
                                ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Container(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth - 32,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.3),
                                        spreadRadius: 2,
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: DataTable(
                                    columnSpacing: 20,
                                    horizontalMargin: 20,
                                    headingRowHeight: 50,
                                    dataRowHeight: 50,
                                    headingRowColor: MaterialStateProperty.all(
                                      Color(0xFF0d5720).withOpacity(0.1),
                                    ),
                                    columns: [
                                      DataColumn(
                                        label: SizedBox(
                                          width: 60,
                                          child: Center(child: Text('№')),
                                        ),
                                      ),
                                      DataColumn(
                                        label: SizedBox(
                                          width: 80,
                                          child: Center(child: Text('Stol')),
                                        ),
                                      ),
                                      DataColumn(
                                        label: SizedBox(
                                          width: 80,
                                          child: Center(
                                            child: Text('Mahsulot'),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: SizedBox(
                                          width: 100,
                                          child: Center(child: Text('Jami')),
                                        ),
                                      ),
                                      DataColumn(
                                        label: SizedBox(
                                          width: 100,
                                          child: Center(child: Text('Xizmat')),
                                        ),
                                      ),
                                      DataColumn(
                                        label: SizedBox(
                                          width: 120,
                                          child: Center(child: Text('Yakuniy')),
                                        ),
                                      ),
                                      DataColumn(
                                        label: SizedBox(
                                          width: 150,
                                          child: Center(
                                            child: Text('Chop etish'),
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: List<DataRow>.generate(
                                      filteredOrders.length,
                                      (index) => DataRow(
                                        cells: [
                                          DataCell(
                                            Container(
                                              width: 60,
                                              padding: EdgeInsets.symmetric(
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Color(
                                                  0xFF0d5720,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  filteredOrders[index]
                                                      .orderNumber,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0d5720),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              width: 80,
                                              padding: EdgeInsets.symmetric(
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  filteredOrders[index]
                                                      .tableNumber,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 80,
                                              child: Center(
                                                child: Text(
                                                  '${filteredOrders[index].itemsCount}',
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 100,
                                              child: Center(
                                                child: Text(
                                                  '${printerService.formatNumber(filteredOrders[index].subtotal)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 100,
                                              child: Center(
                                                child: Text(
                                                  '${printerService.formatNumber(filteredOrders[index].serviceAmount)}',
                                                  style: TextStyle(
                                                    color: Colors.orange[700],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 120,
                                              child: Center(
                                                child: Text(
                                                  '${printerService.formatNumber(filteredOrders[index].finalTotal)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0d5720),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 150,
                                              child: ElevatedButton.icon(
                                                onPressed:
                                                    filteredOrders[index]
                                                            .receiptPrinted
                                                        ? null
                                                        : () => _printOrder(
                                                          filteredOrders[index],
                                                        ),
                                                icon: Icon(
                                                  filteredOrders[index]
                                                          .receiptPrinted
                                                      ? Icons.check_circle
                                                      : Icons.print,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  filteredOrders[index]
                                                          .receiptPrinted
                                                      ? 'Chop etilgan'
                                                      : 'Chek chiqarish',
                                                  style: TextStyle(
                                                    fontSize: fontSize - 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
