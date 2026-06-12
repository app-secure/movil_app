import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants.dart';
import '../core/api_service.dart';

// Importación condicional para usar el widget web de PayPal solo en plataforma Web
import '_paypal_web_sdk.dart' if (dart.library.io) '_paypal_web_sdk_stub.dart';

enum PaypalResult { success, cancel, error }

// ─── Parámetros compartidos ───────────────────────────────────────────────────
class PaypalWebViewScreen extends StatefulWidget {
  final String approvalUrl;
  final String orderId;       // para web JS SDK
  final String clientId;      // PayPal sandbox client ID
  final int numeroFactura;
  final String successUrlFragment;
  final String cancelUrlFragment;

  const PaypalWebViewScreen({
    super.key,
    required this.approvalUrl,
    required this.orderId,
    required this.clientId,
    required this.numeroFactura,
    this.successUrlFragment = '/api/pagos/paypal/success',
    this.cancelUrlFragment  = '/api/pagos/paypal/cancel',
  });

  @override
  State<PaypalWebViewScreen> createState() => _PaypalWebViewScreenState();
}

class _PaypalWebViewScreenState extends State<PaypalWebViewScreen> {
  // ── Móvil ──────────────────────────────────────────────────────────────────
  WebViewController? _webController;
  bool _loading = true;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _initMobile();
  }

  void _initMobile() {
    _webController = WebViewController()
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
        onNavigationRequest: (req) {
          final intercepted = _checkRedirect(req.url);
          if (intercepted) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _loading = false);
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
    int numFact = 0;
    bool success = false;
    String? errorMsg;
    try {
      final uri = Uri.parse(url);
      final token = uri.queryParameters['token'] ?? widget.orderId;
      final payerId = uri.queryParameters['PayerID'] ?? '';

      // Invocar directamente el endpoint de éxito de la API mediante HTTP
      final response = await ApiService.confirmarPagoPaypal(widget.numeroFactura > 0 ? widget.numeroFactura : null, token, payerId);
      numFact = response['numeroFactura'] ?? 0;
      success = true;
    } catch (e) {
      debugPrint("Error al confirmar pago PayPal directamente: $e");
      errorMsg = e.toString();
    } finally {
      if (mounted) {
        Navigator.of(context).pop(); // Cierra diálogo
        if (success) {
          Navigator.of(context).pop({'result': PaypalResult.success, 'numeroFactura': numFact}); // Cierra pantalla
        } else {
          Navigator.of(context).pop({'result': PaypalResult.error, 'message': errorMsg});
        }
      }
    }
  }

  void _anularCompraAsync(String url) async {
    if (mounted) Navigator.of(context).pop(PaypalResult.cancel);
  }

  void _confirmarCancelar() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('¿Cancelar el pago?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text(
          'Si cierras esta ventana, el pago no se completará.',
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

  // ── Build ──────────────────────────────────────────────────────────────────

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
          onPressed: kIsWeb
              ? () => Navigator.of(context).pop(PaypalResult.cancel)
              : _confirmarCancelar,
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
                      fontStyle: FontStyle.italic),
                ),
                TextSpan(
                  text: 'Pal',
                  style: TextStyle(
                      color: Color(0xFF009CDE),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      fontStyle: FontStyle.italic),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Compra #${widget.numeroFactura}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ]),
        actions: [
          if (!kIsWeb && _loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white60),
                ),
              ),
            ),
        ],
      ),
      body: kIsWeb ? _buildWebBody() : _buildMobileBody(),
    );
  }

  // ── Body Web (JS SDK popup) ────────────────────────────────────────────────

  Widget _buildWebBody() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header PayPal
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF003087).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              RichText(
                text: const TextSpan(children: [
                  TextSpan(
                    text: 'Pay',
                    style: TextStyle(
                        color: Color(0xFF003087),
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        fontStyle: FontStyle.italic),
                  ),
                  TextSpan(
                    text: 'Pal',
                    style: TextStyle(
                        color: Color(0xFF009CDE),
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        fontStyle: FontStyle.italic),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sandbox — Pago seguro',
                style: TextStyle(fontSize: 12, color: kTextGrey),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFB3C4E8)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Color(0xFF003087), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Haz clic en el botón de abajo. Se abrirá una ventana emergente de PayPal para completar el pago.',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF003087), height: 1.4),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Botón PayPal JS SDK ─────────────────────────────────────────
          // El widget web-specific que renderiza el botón oficial de PayPal
          _PaypalWebButton(
            orderId: widget.orderId,
            clientId: widget.clientId,
            numeroFactura: widget.numeroFactura,
            onResult: (result, {String? orderId, String? payerId}) async {
              if (result == PaypalResult.success) {
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
                int numFact = 0;
                bool success = false;
                String? errorMsg;
                try {
                  final response = await ApiService.confirmarPagoPaypal(widget.numeroFactura > 0 ? widget.numeroFactura : null, orderId ?? widget.orderId, payerId ?? '');
                  numFact = response['numeroFactura'] ?? 0;
                  success = true;
                } catch (e) {
                  debugPrint("Error al confirmar pago PayPal en Web: $e");
                  errorMsg = e.toString();
                } finally {
                  if (mounted) {
                    Navigator.of(context).pop(); // Cierra diálogo
                    if (success) {
                      Navigator.of(context).pop({'result': PaypalResult.success, 'numeroFactura': numFact});
                    } else {
                      Navigator.of(context).pop({'result': PaypalResult.error, 'message': errorMsg});
                    }
                  }
                }
              } else {
                if (mounted) Navigator.of(context).pop(result);
              }
            },
          ),

          const SizedBox(height: 20),

          // Compra info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined,
                  color: Color(0xFF003087), size: 16),
              const SizedBox(width: 8),
              Text(
                'Compra #${widget.numeroFactura}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF003087)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Body Móvil (WebView nativo) ────────────────────────────────────────────

  Widget _buildMobileBody() {
    return Stack(children: [
      if (_webController != null)
        WebViewWidget(controller: _webController!),
      if (_loading)
        const LinearProgressIndicator(
          backgroundColor: Color(0xFF002070),
          color: Color(0xFF009CDE),
          minHeight: 3,
        ),
    ]);
  }
}

// ─── Widget intermediario para cargar el widget web solo en web ───────────────
// En móvil, este widget nunca se llega a usar (kIsWeb = false)
class _PaypalWebButton extends StatelessWidget {
  final String orderId;
  final String clientId;
  final int numeroFactura;
  final void Function(PaypalResult result, {String? orderId, String? payerId}) onResult;

  const _PaypalWebButton({
    required this.orderId,
    required this.clientId,
    required this.numeroFactura,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    // En web, el import condicional provee PaypalWebSdkWidget
    // En móvil este código nunca se ejecuta (kIsWeb guard en el padre)
    if (!kIsWeb) return const SizedBox.shrink();
    return _buildWebSdk();
  }

  // Separado para que el compilador móvil no intente compilar _paypal_web_sdk.dart
  Widget _buildWebSdk() {
    return PaypalWebSdkWidget(
      clientId: clientId,
      numeroFactura: numeroFactura,
      onCreateOrder: () async => orderId,
      onResult: onResult,
    );
  }
}
