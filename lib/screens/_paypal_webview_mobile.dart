import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants.dart';
import 'paypal_webview_screen.dart';
import '../core/api_service.dart';

class PaypalWebViewMobile extends StatefulWidget {
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
  State<PaypalWebViewMobile> createState() => _PaypalWebViewMobileState();
}

class _PaypalWebViewMobileState extends State<PaypalWebViewMobile> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (!mounted) return;
          setState(() => _loading = true);
          _checkRedirect(url);
        },
        onPageFinished: (url) {
          if (!mounted) return;
          setState(() => _loading = false);
          _checkRedirect(url);
        },
        onNavigationRequest: (request) {
          final intercepted = _checkRedirect(request.url);
          if (intercepted) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          if (!mounted) return;
          setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.approvalUrl));
  }

  bool _checkRedirect(String url) {
    if (_completed) return false;
    if (url.contains(widget.successUrlFragment)) {
      _completed = true;
      _confirmarPagoAsync(url);
      return true;
    } else if (url.contains(widget.cancelUrlFragment)) {
      _completed = true;
      _anularCompraAsync(url);
      return true;
    }
    return false;
  }

  void _confirmarPagoAsync(String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: kTeal),
                  SizedBox(height: 16),
                  Text(
                    'Confirmando pago y enviando factura...',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextDark),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    bool success = false;
    String? errorMsg;
    try {
      final uri = Uri.parse(url);
      final numeroFactura = int.tryParse(uri.queryParameters['numeroFactura'] ?? '') ?? widget.numeroFactura;
      final token = uri.queryParameters['token'] ?? '';
      final payerId = uri.queryParameters['PayerID'] ?? '';

      // Invocar directamente el endpoint de éxito de la API mediante HTTP
      await ApiService.confirmarPagoPaypal(numeroFactura, token, payerId);
      success = true;
    } catch (e) {
      debugPrint("Error al confirmar pago PayPal directamente: $e");
      errorMsg = e.toString();
    } finally {
      if (mounted) {
        Navigator.of(context).pop(); // Cierra diálogo
        if (success) {
          Navigator.of(context).pop(PaypalResult.success); // Cierra pantalla
        } else {
          Navigator.of(context).pop({'result': PaypalResult.error, 'message': errorMsg});
        }
      }
    }
  }

  void _anularCompraAsync(String url) async {
    try {
      final uri = Uri.parse(url);
      final numeroFactura = int.tryParse(uri.queryParameters['numeroFactura'] ?? '') ?? widget.numeroFactura;
      await ApiService.anularCompra(numeroFactura);
    } catch (e) {
      debugPrint("Error al anular compra PayPal: $e");
    } finally {
      if (mounted) Navigator.of(context).pop(PaypalResult.cancel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: 'Cancelar pago',
          onPressed: _confirmarCancelar,
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: RichText(
              text: const TextSpan(children: [
                TextSpan(
                  text: 'Pay',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                TextSpan(
                  text: 'Pal',
                  style: TextStyle(
                    color: Color(0xFF009CDE),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Compra #${widget.numeroFactura}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ]),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white60,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFF002070),
              color: Color(0xFF009CDE),
              minHeight: 3,
            ),
        ],
      ),
    );
  }

  void _confirmarCancelar() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '¿Cancelar el pago?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: const Text(
          'Si cierras esta ventana, el pago no se completará. Podrás intentarlo de nuevo desde Mis Compras.',
          style: TextStyle(fontSize: 13, color: kTextGrey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continuar pago',
                style: TextStyle(color: kTeal, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop(PaypalResult.cancel);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kError,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancelar pago',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
