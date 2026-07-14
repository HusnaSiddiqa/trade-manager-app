// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<void> platformDownloadOrShare(
  List<int> bytes,
  String filename,
  String customerMobile,
  String whatsappMessage,
) async {
  // Download the PDF
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);

  // Open WhatsApp with the bill message
  final digits = customerMobile.replaceAll(RegExp(r'[^0-9]'), '');
  final waNumber = digits.length == 10 ? '91$digits' : digits;
  final waBase = waNumber.isNotEmpty ? 'https://wa.me/$waNumber' : 'https://wa.me';
  final waUrl = '$waBase?text=${Uri.encodeComponent(whatsappMessage)}';
  html.window.open(waUrl, '_blank');
}
