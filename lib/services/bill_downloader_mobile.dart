import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _channel = MethodChannel('royal_erp/file_provider');

Future<void> platformDownloadOrShare(
  List<int> bytes,
  String filename,
  String customerMobile,
  String whatsappMessage,
) async {
  // Save PDF — prefer external storage (visible in file manager), fall back to docs
  File pdfFile;
  try {
    final extDir = await getExternalStorageDirectory();
    pdfFile = extDir != null
        ? File('${extDir.path}/$filename')
        : File('${(await getApplicationDocumentsDirectory()).path}/$filename');
  } catch (_) {
    pdfFile =
        File('${(await getApplicationDocumentsDirectory()).path}/$filename');
  }
  await pdfFile.writeAsBytes(bytes);

  final digits = customerMobile.replaceAll(RegExp(r'[^0-9]'), '');
  final waNumber = digits.length == 10
      ? '91$digits'
      : digits.length >= 11
          ? digits
          : '';

  if (waNumber.isNotEmpty) {
    // shareToWhatsApp does everything natively:
    //   1. FileProvider URI creation
    //   2. grantUriPermission() to give WhatsApp explicit read access
    //   3. Intent build + startActivity
    // This fixes "Couldn't share" errors caused by passing the URI
    // back to Flutter and re-using it in android_intent_plus, which
    // loses the URI permission grant.
    try {
      await _channel.invokeMethod<void>('shareToWhatsApp', {
        'filePath': pdfFile.path,
        'waNumber': waNumber,
        'text': whatsappMessage,
      });
      return;
    } on PlatformException catch (e) {
      if (e.code == 'WHATSAPP_NOT_FOUND') {
        // WhatsApp not installed — fall through to share sheet
      }
      // Any other native error — fall through to share sheet
    }
  }

  // Fallback: system share sheet (works even without WhatsApp / no mobile number)
  await Share.shareXFiles(
    [XFile(pdfFile.path, mimeType: 'application/pdf')],
    text: whatsappMessage,
    subject: filename,
  );
}
