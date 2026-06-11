// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void abrirHtmlEnNuevaPestana(String htmlContent) {
  final blob = html.Blob([htmlContent], 'text/html');
  final url  = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  Future.delayed(const Duration(seconds: 5), () => html.Url.revokeObjectUrl(url));
}

void descargarHtml(String htmlContent, String filename) {
  final blob   = html.Blob([htmlContent], 'text/html');
  final url    = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
