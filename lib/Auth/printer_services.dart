import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PrinterService {
  PrinterService._();

  static const MethodChannel _channel = MethodChannel('pos_printer');

  static const int paperWidthPx = 384;

  static const double _normalPixelRatio = 2.0;

  static const double _maxImageHeightPx = 4000;
  static Future<void> logDeviceInfo() async {
    try {
      debugPrint('[PRINT] deviceInfo maang rahe hain...');
      final info = await _channel.invokeMethod<String>('deviceInfo');
      debugPrint('[PRINT] deviceInfo:\n$info');
    } on MissingPluginException catch (e) {
      debugPrint('[PRINT] ERROR: channel nahi mila (MainActivity.kt update hua? full restart karo): $e');
    } catch (e) {
      debugPrint('[PRINT] ERROR deviceInfo: $e');
    }
  }

  static Future<Uint8List?> _capture(GlobalKey key) async {
    try {
      debugPrint('[PRINT] 1) receipt capture start');
      final ctx = key.currentContext;
      if (ctx == null) {
        debugPrint('[PRINT] ERROR: RepaintBoundary ka context null hai (key lagi hai?)');
        return null;
      }
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      final logicalHeight = boundary.size.height;
      final ratio = (logicalHeight * _normalPixelRatio > _maxImageHeightPx)
          ? (_maxImageHeightPx / logicalHeight)
          : _normalPixelRatio;
      debugPrint('[PRINT] receipt logical height: ${logicalHeight.toStringAsFixed(0)}, pixelRatio: ${ratio.toStringAsFixed(2)}');

      final image = await boundary.toImage(pixelRatio: ratio);
      debugPrint('[PRINT] image size: ${image.width} x ${image.height}');
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        debugPrint('[PRINT] ERROR: toByteData null aaya');
        return null;
      }
      final bytes = data.buffer.asUint8List();
      debugPrint('[PRINT] 2) capture done, PNG bytes: ${bytes.length}');
      return bytes;
    } catch (e, st) {
      debugPrint('[PRINT] ERROR capture: $e\n$st');
      return null;
    }
  }

  static Future<bool> printReceipt(GlobalKey receiptKey) async {
    final bytes = await _capture(receiptKey);
    if (bytes == null) return false;

    try {
      debugPrint('[PRINT] 3) Kotlin ko bhej rahe hain (printBitmap)');
      final ok = await _channel.invokeMethod<bool>('printBitmap', {
        'bytes': bytes,
        'width': paperWidthPx,
      });
      debugPrint('[PRINT] 4) Kotlin se result: $ok');
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[PRINT] ERROR PlatformException -> code: ${e.code}, message: ${e.message}');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('[PRINT] ERROR: channel nahi mila (MainActivity.kt check karo, full restart karo): $e');
      return false;
    } catch (e, st) {
      debugPrint('[PRINT] ERROR unknown: $e\n$st');
      return false;
    }
  }
}