// ignore_for_file: avoid_web_libraries_in_flutter, uri_does_not_exist, undefined_class, undefined_prefixed_name
import 'dart:html' as html;
import 'dart:js_util' as js_util;
// ignore: undefined_shown_name
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'paypal_webview_screen.dart';

/// Renderiza el botón de PayPal usando el JS SDK oficial (sandbox).
/// Crea un popup nativo de PayPal superpuesto en la página (no iframe).
class PaypalWebSdkWidget extends StatefulWidget {
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
  State<PaypalWebSdkWidget> createState() => _PaypalWebSdkWidgetState();
}

class _PaypalWebSdkWidgetState extends State<PaypalWebSdkWidget> {
  bool _sdkLoaded = false;
  bool _error = false;
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'paypal-btn-${widget.numeroFactura}';
    _registerView();
    _loadSdk();
  }

  void _registerView() {
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final div = html.DivElement()
        ..id = 'paypal-container-${widget.numeroFactura}'
        ..style.width = '100%'
        ..style.padding = '8px 0';
      return div;
    });
  }

  void _loadSdk() {
    // Verificar si ya está cargado
    if (js_util.hasProperty(html.window, 'paypal')) {
      _renderButtons();
      return;
    }

    final script = html.ScriptElement()
      ..id = 'paypal-sdk-script'
      ..src =
          'https://www.sandbox.paypal.com/sdk/js?client-id=${widget.clientId}&currency=USD&intent=capture'
      ..async = true;

    script.onLoad.listen((_) {
      if (mounted) {
        setState(() => _sdkLoaded = true);
        _renderButtons();
      }
    });

    script.onError.listen((_) {
      if (mounted) setState(() => _error = true);
    });

    html.document.head!.append(script);
  }

  void _renderButtons() {
    final viewId = 'paypal-container-${widget.numeroFactura}';

    // Registrar callbacks globales para comunicar con Dart
    js_util.setProperty(html.window, 'onPaypalCreateOrder', js_util.allowInterop(
      (dynamic resolve, dynamic reject) {
        widget.onCreateOrder().then((orderId) {
          if (orderId != null) {
            js_util.callMethod(resolve, 'call', [null, orderId]);
          } else {
            js_util.callMethod(reject, 'call', [null, 'Cancelado']);
          }
        }).catchError((err) {
          js_util.callMethod(reject, 'call', [null, err.toString()]);
        });
      }
    ));

    js_util.setProperty(html.window, 'onPaypalApprove', js_util.allowInterop(
      (dynamic data) {
        final orderId = js_util.getProperty(data, 'orderID') as String? ?? '';
        final payerId = js_util.getProperty(data, 'payerID') as String? ?? '';
        widget.onResult(PaypalResult.success, orderId: orderId, payerId: payerId);
      },
    ));

    js_util.setProperty(html.window, 'onPaypalCancel', js_util.allowInterop(
      () {
        widget.onResult(PaypalResult.cancel);
      },
    ));

    js_util.setProperty(html.window, 'onPaypalError', js_util.allowInterop(
      (dynamic err) {
        widget.onResult(PaypalResult.error);
      },
    ));

    // Esperar que el DOM esté listo con el div registrado
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        js_util.callMethod(html.window, 'eval', ['''
          (function() {
            var container = document.getElementById('$viewId');
            if (!container) {
              console.error('PayPal container not found: $viewId');
              return;
            }
            container.innerHTML = ''; // Limpiar por si acaso
            paypal.Buttons({
              createOrder: function(data, actions) {
                return new Promise(function(resolve, reject) {
                  window.onPaypalCreateOrder(resolve, reject);
                });
              },
              onApprove: function(data, actions) {
                window.onPaypalApprove(data);
              },
              onCancel: function(data) {
                window.onPaypalCancel();
              },
              onError: function(err) {
                console.error('PayPal error:', err);
                window.onPaypalError(err);
              },
              style: {
                layout: 'vertical',
                color: 'gold',
                shape: 'rect',
                label: 'pay',
                height: 48
              }
            }).render('#$viewId');
          })();
        ''']);
      } catch (e) {
        debugPrint('[PayPal Web SDK] Error al renderizar botón: $e');
        if (mounted) setState(() => _error = true);
      }
    });

    if (mounted) setState(() => _sdkLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kError.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: kError, size: 32),
          const SizedBox(height: 8),
          const Text('No se pudo cargar PayPal.',
              style: TextStyle(
                  color: kError, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() => _error = false);
              _loadSdk();
            },
            child: const Text('Reintentar',
                style: TextStyle(color: kTeal, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
    }

    if (!_sdkLoaded) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Color(0xFF2A7F8F)),
          SizedBox(height: 16),
          Text('Cargando PayPal...',
              style: TextStyle(color: kTextGrey, fontSize: 13)),
        ]),
      );
    }

    // El HtmlElementView donde el SDK de PayPal renderiza el botón
    return SizedBox(
      height: 60,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}
