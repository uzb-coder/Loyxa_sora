// // Minimal model classes required for printing
// class User {
//   final String firstName;
//   User({required this.firstName});
// }
//
// class Ovqat {
//   final String id;
//   final String name;
//   final String categoryId;
//
//   Ovqat({
//     required this.id,
//     required this.name,
//     required this.categoryId,
//   });
// }
//
// class CartItem {
//   final Ovqat product;
//   int quantity;
//
//   CartItem({required this.product, this.quantity = 1});
// }
//
// class Printer {
//   final String ip;
//
//   Printer({required this.ip});
// }
//
// class Category {
//   final String id;
//   final String title;
//   final Printer printerId;
//
//   Category({
//     required this.id,
//     required this.title,
//     required this.printerId,
//   });
// }
//
// // The printing method
// Future<void> _printOrderDirectly(Map<String, dynamic> orderData, {
//   required List<CartItem> _cart,
//   required List<Category> _categories,
//   required String? tableName,
//   required User user,
// }) async {
//   const int port = 9100;
//
//   // Group cart items by category
//   final Map<String, List<CartItem>> itemsByCategory = {};
//   for (var item in _cart) {
//     final categoryId = item.product.categoryId;
//     if (!itemsByCategory.containsKey(categoryId)) {
//       itemsByCategory[categoryId] = [];
//     }
//     itemsByCategory[categoryId]!.add(item);
//   }
//
//   // Process each category's items and print to the corresponding printer
//   for (var categoryId in itemsByCategory.keys) {
//     final category = _categories.firstWhere(
//           (cat) => cat.id == categoryId,
//       orElse: () => Category(
//         id: '',
//         title: 'Unknown',
//         printerId: Printer(ip: ''),
//       ),
//     );
//
//     final printerIP = category.printerId.ip;
//     if (printerIP.isEmpty) {
//       print('Printer IP not found for category: ${category.title}');
//       continue; // Skip if no valid IP
//     }
//
//     try {
//       StringBuffer receipt = StringBuffer();
//       String centerText(String text, int width) => text
//           .padLeft((width - text.length) ~/ 2 + text.length)
//           .padRight(width);
//
//       receipt.writeln(centerText('--- Restoran Cheki ---', 32));
//       receipt.writeln();
//       receipt.writeln(centerText('Buyurtma: ${orderData['_id'] ?? 'N/A'}', 32));
//       receipt.writeln();
//       receipt.writeln(centerText('Stol: ${tableName ?? 'N/A'}', 32));
//       receipt.writeln();
//       receipt.writeln(centerText('Hodim: ${user.firstName}', 32));
//       receipt.writeln();
//       receipt.writeln(
//         centerText(
//           'Vaqt: ${DateFormat('d MMMM yyyy, HH:mm', 'uz').format(DateTime.now())}',
//           32,
//         ),
//       );
//       receipt.writeln();
//       receipt.writeln(centerText('Kategoriya: ${category.title}', 32));
//       receipt.writeln();
//       receipt.writeln(centerText('--------------------', 32));
//       receipt.writeln();
//       receipt.writeln(centerText('Mahsulotlar:', 32));
//       receipt.writeln();
//
//       for (var item in itemsByCategory[categoryId]!) {
//         String name = item.product.name.length > 18
//             ? item.product.name.substring(0, 18)
//             : item.product.name;
//         String quantity = '${item.quantity}x';
//         receipt.writeln('${name.padRight(18)}$quantity');
//         receipt.writeln();
//       }
//
//       receipt.writeln(centerText('--------------------', 32));
//       receipt.writeln('\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n');
//       receipt.write('\x1D\x56\x00');
//
//       Socket socket = await Socket.connect(
//         printerIP,
//         port,
//         timeout: const Duration(seconds: 5),
//       );
//       socket.write(receipt.toString());
//       await socket.flush();
//       socket.destroy();
//     } catch (e) {
//       print('Printer xatoligi for IP $printerIP: $e');
//     }
//   }
// }