import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';

class Xp80cPrinterScreen extends StatelessWidget {
  const Xp80cPrinterScreen({super.key});

  Future<List<int>> loadLogoBytes() async {
    // LOGO PNG faylini o‘qing (assets/images/logo.png deb olaylik)
    final file = File('rasm/sara.png'); // <-- Yo‘lini to‘g‘rilang
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes)!;

    // ESC/POS formatiga bitmap yasash (mono B/W)
    List<int> escPosLogo = [];

    final width = (image.width + 7) ~/ 8 * 8; // 8 pixel align
    final height = image.height;

    // Bit Image Mode Command: GS v 0
    escPosLogo.addAll([0x1D, 0x76, 0x30, 0x00]); // Raster bit image mode
    escPosLogo.addAll([width ~/ 8, 0x00, height % 256, height ~/ 256]);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x += 8) {
        int byte = 0;
        for (int b = 0; b < 8; b++) {
          int pxX = x + b;
          if (pxX >= image.width) continue;
          int pixel = image.getPixel(pxX, y);
          int luminance = img.getLuminance(pixel);
          if (luminance < 128) {
            byte |= (1 << (7 - b));
          }
        }
        escPosLogo.add(byte);
      }
    }

    return escPosLogo;
  }

  Future<void> printToXp80c() async {
    const printerName = 'XP-80C';
    final hPrinter = calloc<HANDLE>();
    final docInfo = calloc<DOC_INFO_1>();

    docInfo.ref.pDocName = TEXT('Flutter Check Print');
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

    // LOGO rasmini yuklash
    final logoBytes = await loadLogoBytes();

    // Chek matni
    final List<int> escPosData = <int>[
      0x1B, 0x40,  // Initialize printer
      ...logoBytes, // <-- LOGO bitmap qo‘shildi
      0x1B, 0x64, 0x02,  // Feed 2 lines
      0x1B, 0x21, 0x30,  // Double Width & Height
      0x1B, 0x61, 0x01,  // Center align
      ...'FLUTTER CHEK PRINT\n'.codeUnits,
      0x1B, 0x21, 0x00,  // Normal font
      0x1B, 0x61, 0x00,  // Left align
      ...'-----------------------------\n'.codeUnits,
      ...'Mahsulot 1  2 x 10,000 = 20,000\n'.codeUnits,
      ...'Mahsulot 2  1 x 15,000 = 15,000\n'.codeUnits,
      ...'-----------------------------\n'.codeUnits,
      0x1B, 0x21, 0x20,  // Double Height for total
      ...'JAMI:             35,000 UZS\n'.codeUnits,
      0x1B, 0x64, 0x06,  // Feed 6 lines
      0x1D, 0x56, 0x00   // Full cut
    ];

    final bytesPointer = calloc<Uint8>(escPosData.length);
    final bytesList = bytesPointer.asTypedList(escPosData.length);
    bytesList.setAll(0, escPosData);

    final bytesWritten = calloc<DWORD>();
    final success = WritePrinter(hPrinter.value, bytesPointer, escPosData.length, bytesWritten);

    if (success == 0) {
      print('❌ Ma\'lumot yuborishda xato.');
    } else {
      print('✅ Chek muvaffaqiyatli yuborildi (logo bilan).');
    }

    EndPagePrinter(hPrinter.value);
    EndDocPrinter(hPrinter.value);
    ClosePrinter(hPrinter.value);

    calloc.free(bytesPointer);
    calloc.free(bytesWritten);
    calloc.free(hPrinter);
    calloc.free(docInfo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('XP-80C Printer Test')),
      body: Center(
        child: ElevatedButton(
          onPressed: printToXp80c,
          child: const Text('Chek (logo bilan) chiqarish'),
        ),
      ),
    );
  }
}
