import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../core/api_service.dart';
import '../core/cart_manager.dart';
import '../core/contingency_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'paypal_webview_screen.dart';
import 'factura_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '_paypal_web_sdk.dart' if (dart.library.io) '_paypal_web_sdk_stub.dart';
import 'package:flutter/services.dart';

class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});
  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  bool _procesando = false;

  void _rebuild() => setState(() {});

  int? _lastNumeroFactura;

  void _abrirCheckout() async {
    if (ContingencyService.bloquear(context)) return;
    final res = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(
        onConfirmar: _confirmarCompra,
      ),
    );

    if (res == null) return;

    if (res is PaypalResult) {
      _procesarResultadoPago(res, _lastNumeroFactura ?? 0);
    } else if (res is Map<String, dynamic>) {
      final approvalUrl = res['approvalUrl'] ?? '';
      final orderId = res['orderId'] ?? '';
      final clientId = res['clientId'] ?? '';
      final numeroFactura = res['numeroFactura'] ?? 0;

      if (!mounted) return;
      final result = await Navigator.push<PaypalResult>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PaypalWebViewScreen(
            approvalUrl: approvalUrl,
            orderId: orderId,
            clientId: clientId,
            numeroFactura: numeroFactura,
          ),
        ),
      );
      _procesarResultadoPago(result, numeroFactura);
    }
  }

  void _mostrarDialogoExito(int numeroFactura) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle, color: kGreen, size: 22),
          ),
          const SizedBox(width: 10),
          const Text('¡Pago exitoso!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Tu pago con PayPal fue procesado correctamente.',
            style: TextStyle(fontSize: 13, color: kTextGrey, height: 1.5),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kGreenLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined, color: kGreen, size: 16),
              const SizedBox(width: 8),
              Text(
                'Compra #$numeroFactura',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kGreen),
              ),
            ]),
          ),
        ]),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              final navigator = Navigator.of(context);
              navigator.pop(); // volver al catálogo
              mostrarFacturaComprobanteSheet(
                navigator.context,
                numeroFactura: numeroFactura,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Ver factura', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _procesarResultadoPago(PaypalResult? result, int numeroFactura) {
    if (result == PaypalResult.success) {
      CartManager.instance.limpiar();
      _mostrarDialogoExito(numeroFactura);
    } else {
      // Si se cancela o falla el pago, anulamos el pedido temporal en la base de datos para restaurar el stock
      ApiService.anularCompra(numeroFactura).catchError((e) {
        debugPrint("Error al anular compra tras cancelación de PayPal: $e");
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result == PaypalResult.cancel
            ? 'Pago cancelado. Puedes intentarlo de nuevo.'
            : 'Error en el pago. Puedes intentarlo de nuevo.'),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<Map<String, dynamic>?> _confirmarCompra({
    required String lugarEntrega,
    required bool requiereFactura,
    String? cedulaFactura,
    String? nombreFactura,
  }) async {
    final items = CartManager.instance.items;
    if (items.isEmpty) return null;

    setState(() => _procesando = true);
    try {
      final prefs     = await SharedPreferences.getInstance();
      final idUsuario = prefs.getString('idUsuario') ?? '';

      final body = <String, dynamic>{
        'idUsuario':      idUsuario,
        'metodoPago':     'PayPal',
        'lugarEntrega':   lugarEntrega,
        'requiereFactura': requiereFactura,
        'detalles': items.map((i) => {
          'idProducto':     i.idProducto,
          'cantidad':       i.cantidad,
          'precioUnitario': i.precio,
        }).toList(),
      };
      if (requiereFactura && cedulaFactura != null) body['cedulaFactura'] = cedulaFactura;
      if (requiereFactura && nombreFactura  != null) body['nombreFactura'] = nombreFactura;

      // 1. Crear el pedido
      final data          = await ApiService.realizarCompra(body);
      final numeroFactura = data['numeroFactura'] ?? data['idCompra'] ?? data['id'];

      _lastNumeroFactura = numeroFactura;

      // 2. Obtener la URL de aprobación de PayPal
      final paypalData   = await ApiService.crearPagoPaypal(numeroFactura);
      final approvalUrl  = paypalData['approvalUrl'] ?? '';
      final orderId      = paypalData['orderId'] ?? '';
      final clientId     = paypalData['clientId'] ?? '';

      if (approvalUrl.isEmpty) throw Exception('No se recibió URL de PayPal');

      return {
        'numeroFactura': numeroFactura,
        'approvalUrl': approvalUrl,
        'orderId': orderId,
        'clientId': clientId,
      };
    } catch (e) {
      if (!mounted) return null;
      final mensaje = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      final esStockInsuficiente = mensaje.toLowerCase().contains('stock');
      showDialog(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: kError.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(esStockInsuficiente ? Icons.people_outline_rounded : Icons.error_outline_rounded, color: kError, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(esStockInsuficiente ? 'Sin stock disponible' : 'No se pudo completar', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (esStockInsuficiente) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kError.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kError.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: kError, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Otro usuario compró el último artículo justo antes que tú. El stock ya no está disponible.',
                          style: TextStyle(fontSize: 13, color: kError, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Te sugerimos explorar otros productos similares en el catálogo.',
                  style: TextStyle(fontSize: 13, color: kTextGrey, height: 1.5),
                ),
              ] else
                Text(mensaje, style: const TextStyle(fontSize: 14, color: kTextGrey, height: 1.5)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: kError,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return null;
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = CartManager.instance.items;
    final total = CartManager.instance.total;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kTeal,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          tooltip: 'Volver a productos',
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mi carrito', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          if (items.isNotEmpty)
            TextButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Vaciar carrito', style: TextStyle(fontWeight: FontWeight.w800)),
                  content: const Text('¿Eliminar todos los productos del carrito?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: kTextGrey))),
                    ElevatedButton(
                      onPressed: () { CartManager.instance.limpiar(); setState(() {}); Navigator.pop(context); },
                      style: ElevatedButton.styleFrom(backgroundColor: kError, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: const Text('Vaciar'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 18),
              label: const Text('Vaciar', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ContingencyBanner(child: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: kTeal.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text('Tu carrito está vacío', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextDark)),
                  const SizedBox(height: 8),
                  const Text('Agrega productos para continuar', style: TextStyle(color: kTextGrey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: kTeal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Volver a productos', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _CartItemCard(item: items[i], onChanged: _rebuild),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal (sin IVA)', style: TextStyle(color: kTextGrey, fontSize: 13)),
                          Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: kTextDark, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('IVA (15%)', style: TextStyle(color: kTextGrey, fontSize: 13)),
                          Text('\$${(total * 0.15).toStringAsFixed(2)}', style: const TextStyle(color: kTextGrey, fontSize: 13)),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total con IVA', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kTextDark)),
                          Text('\$${(total * 1.15).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kTeal)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ContingencyGuardButton(
                        action: _abrirCheckout,
                        builder: (onPressed) => SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _procesando ? null : onPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kTeal,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            icon: _procesando
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : const Icon(Icons.payment, color: Color(0xFF4CAF50), size: 22),
                            label: _procesando
                                ? const SizedBox.shrink()
                                : const Text('Pagar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Checkout sheet — solo datos del pedido (lugar de entrega + factura)
// ─────────────────────────────────────────────────────────────────────────────
class _CheckoutSheet extends StatefulWidget {
  final Future<Map<String, dynamic>?> Function({
    required String lugarEntrega,
    required bool requiereFactura,
    String? cedulaFactura,
    String? nombreFactura,
  }) onConfirmar;

  const _CheckoutSheet({required this.onConfirmar});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _formKey     = GlobalKey<FormState>();
  bool  _requiereFactura = false;
  bool  _procesando  = false;

  String? _orderId;
  String? _clientId;
  int? _numeroFactura;
  bool _loadingClient = false;
  String? _clientError;

  final _lugarCtrl  = TextEditingController(text: 'Retiro en Tienda');
  final _cedulaCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _loadClientId();
    }
  }

  Future<void> _loadClientId() async {
    setState(() {
      _loadingClient = true;
      _clientError = null;
    });
    try {
      final cid = await ApiService.getPaypalClientId();
      if (mounted) {
        setState(() {
          _clientId = cid;
          _loadingClient = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _clientError = e.toString();
          _loadingClient = false;
        });
      }
    }
  }

  Future<String?> _handleCreateOrderWeb() async {
    if (!_formKey.currentState!.validate()) return null;
    setState(() => _procesando = true);
    try {
      final res = await widget.onConfirmar(
        lugarEntrega:   _lugarCtrl.text.trim(),
        requiereFactura: _requiereFactura,
        cedulaFactura:  _requiereFactura ? _cedulaCtrl.text.trim() : null,
        nombreFactura:  _requiereFactura ? _nombreCtrl.text.trim() : null,
      );
      if (res != null) {
        setState(() {
          _numeroFactura = res['numeroFactura'];
        });
        return res['orderId'];
      }
    } catch (_) {}
    if (mounted) setState(() => _procesando = false);
    return null;
  }

  @override
  void dispose() {
    _lugarCtrl.dispose();
    _cedulaCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _procesando = true);
    try {
      final res = await widget.onConfirmar(
        lugarEntrega:   _lugarCtrl.text.trim(),
        requiereFactura: _requiereFactura,
        cedulaFactura:  _requiereFactura ? _cedulaCtrl.text.trim() : null,
        nombreFactura:  _requiereFactura ? _nombreCtrl.text.trim() : null,
      );
      if (res != null) {
        if (kIsWeb) {
          setState(() {
            _orderId = res['orderId'];
            _clientId = res['clientId'];
            _numeroFactura = res['numeroFactura'];
            _procesando = false;
          });
        } else {
          if (mounted) Navigator.pop(context, res);
        }
      } else {
        if (mounted) setState(() => _procesando = false);
      }
    } catch (_) {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),

            // Título
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF003087).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF003087), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Datos del pedido',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextDark)),
            ]),
            const SizedBox(height: 16),

            // Badge PayPal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF003087),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                RichText(
                  text: const TextSpan(children: [
                    TextSpan(text: 'Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, fontStyle: FontStyle.italic)),
                    TextSpan(text: 'Pal', style: TextStyle(color: Color(0xFF009CDE), fontWeight: FontWeight.w900, fontSize: 16, fontStyle: FontStyle.italic)),
                  ]),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('PayPal Sandbox', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    Text('Pago seguro con tu cuenta de prueba', style: TextStyle(color: Color(0xFFB3C4E8), fontSize: 11)),
                  ]),
                ),
                const Icon(Icons.check_circle, color: Color(0xFF009CDE), size: 20),
              ]),
            ),
            const SizedBox(height: 14),

            // Info box
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
                Expanded(child: Text(
                  'Al presionar "Pagar con PayPal" se abrirá la página de inicio de sesión de PayPal Sandbox.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF003087), height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: 20),

            // Lugar de entrega
            const Text('Lugar de entrega',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextGrey, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _lugarCtrl,
              decoration: InputDecoration(
                hintText: 'Retiro en Tienda',
                prefixIcon: const Icon(Icons.location_on_outlined, color: kTeal, size: 20),
                filled: true,
                fillColor: kBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el lugar de entrega' : null,
            ),

            const SizedBox(height: 16),

            // Requiere factura
            Container(
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text('Requiere factura legal', style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark, fontSize: 14)),
                subtitle: const Text('XML para el SRI con tu cédula/RUC', style: TextStyle(color: kTextGrey, fontSize: 11)),
                value: _requiereFactura,
                onChanged: (v) => setState(() => _requiereFactura = v),
                activeThumbColor: kTeal,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            // Campos de factura
            if (_requiereFactura) ...[
              const SizedBox(height: 14),
              const Text('Datos de facturación',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextGrey, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cedulaCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                decoration: InputDecoration(
                  hintText: 'Cédula o RUC',
                  prefixIcon: const Icon(Icons.badge_outlined, color: kTeal, size: 20),
                  filled: true,
                  fillColor: kBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                validator: (v) {
                  if (!_requiereFactura) return null;
                  if (v == null || v.trim().isEmpty) return 'Ingresa la cédula o RUC';
                  if (v.trim().length != 10 && v.trim().length != 13) return 'Debe tener 10 dígitos (cédula) o 13 dígitos (RUC)';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nombreCtrl,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Záéíóú�?É�?ÓÚñÑ\s]')),
                ],
                decoration: InputDecoration(
                  hintText: 'Razón social o nombre completo',
                  prefixIcon: const Icon(Icons.person_outline, color: kTeal, size: 20),
                  filled: true,
                  fillColor: kBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                validator: (v) {
                  if (!_requiereFactura) return null;
                  if (v == null || v.trim().isEmpty) return 'Ingresa el nombre o razón social';
                  if (v.trim().length < 3) return 'Mínimo 3 letras';
                  return null;
                },
              ),
            ],

            const SizedBox(height: 24),

            // Botón pagar o PaypalWebSdkWidget
            if (kIsWeb) ...[
              if (_loadingClient)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: kTeal),
                        SizedBox(height: 10),
                        Text('Cargando pasarela de pago...', style: TextStyle(color: kTextGrey, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else if (_clientError != null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: $_clientError', style: const TextStyle(color: kError, fontSize: 13)),
                      TextButton(
                        onPressed: _loadClientId,
                        child: const Text('Reintentar', style: TextStyle(color: kTeal, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              else if (_clientId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: PaypalWebSdkWidget(
                    clientId: _clientId!,
                    numeroFactura: _numeroFactura ?? 0,
                    onCreateOrder: _handleCreateOrderWeb,
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
                        try {
                          await ApiService.confirmarPagoPaypal(_numeroFactura ?? 0, orderId ?? '', payerId ?? '');
                        } catch (e) {
                          debugPrint("Error al confirmar pago PayPal en Web: $e");
                        } finally {
                          if (mounted) Navigator.pop(context); // Cierra diálogo
                        }
                      }
                      if (mounted) Navigator.pop(context, result);
                    },
                  ),
                ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _procesando ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: _procesando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.payment, color: Color(0xFF4CAF50), size: 24),
                  label: _procesando
                      ? const Text('Creando pedido...', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))
                      : const Text('Pagar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de producto en el carrito
// ─────────────────────────────────────────────────────────────────────────────
class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onChanged;
  const _CartItemCard({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.urlImagen != null
                ? CachedNetworkImage(imageUrl: item.urlImagen!, width: 64, height: 64, fit: BoxFit.cover,
                    errorWidget: (ctx, url, err) => _imgFallback())
                : _imgFallback(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextDark), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('\$${item.precio.toStringAsFixed(2)} c/u', style: const TextStyle(color: kTextGrey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _qtyBtn(Icons.remove, () { CartManager.instance.cambiarCantidad(item.idProducto, item.cantidad - 1); onChanged(); }, disabled: item.cantidad <= 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(children: [
                        Text('${item.cantidad}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('/ ${item.stock}', style: const TextStyle(fontSize: 9, color: kTextGrey)),
                      ]),
                    ),
                    _qtyBtn(Icons.add,
                      item.cantidad < item.stock ? () { CartManager.instance.subirCantidad(item.idProducto); onChanged(); } : null,
                      disabled: item.cantidad >= item.stock),
                    const Spacer(),
                    Text('\$${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: kTeal, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () { CartManager.instance.eliminar(item.idProducto); onChanged(); },
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.delete_outline, color: kError.withValues(alpha: 0.7), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap, {bool disabled = false}) => GestureDetector(
    onTap: disabled ? null : onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: disabled ? Colors.grey.shade100 : kBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: disabled ? Colors.grey.shade200 : Colors.grey.shade300),
      ),
      child: Icon(icon, size: 16, color: disabled ? Colors.grey.shade400 : kTeal),
    ),
  );

  Widget _imgFallback() => Container(width: 64, height: 64, color: kBackground, child: const Icon(Icons.devices_outlined, color: kTeal));
}
