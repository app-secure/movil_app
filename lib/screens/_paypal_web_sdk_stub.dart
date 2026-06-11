import 'package:flutter/material.dart';
import 'paypal_webview_screen.dart';

/// Stub class for compilation on mobile platform where HTML is not available.
class PaypalWebSdkWidget extends StatelessWidget {
  final String clientId;
  final int numeroFactura;
  final Future<String?> Function() onCreateOrder;
  final void Function(PaypalResult result, {String? orderId, String? payerId}) onResult;

  const PaypalWebSdkWidget({
    super.key,
    required this.clientId,
    required this.numeroFactura,
    required this.onCreateOrder,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
