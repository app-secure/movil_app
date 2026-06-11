// Stub para web — webview_flutter no existe en web.
// Se usa url_launcher en su lugar desde paypal_webview_screen.dart
import 'package:flutter/material.dart';
import 'paypal_webview_screen.dart';

/// Widget stub vacío para web. Nunca se renderiza porque paypal_webview_screen
/// detecta kIsWeb antes y usa url_launcher.
class PaypalWebViewMobile extends StatelessWidget {
  final String approvalUrl;
  final int numeroFactura;
  final String successUrlFragment;
  final String cancelUrlFragment;

  const PaypalWebViewMobile({
    super.key,
    required this.approvalUrl,
    required this.numeroFactura,
    this.successUrlFragment = '/api/pagos/paypal/success',
    this.cancelUrlFragment = '/api/pagos/paypal/cancel',
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
