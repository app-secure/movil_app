import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/file_downloader.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'paypal_webview_screen.dart';
import '_paypal_web_sdk.dart' if (dart.library.io) '_paypal_web_sdk_stub.dart';

class DetalleCompraScreen extends StatefulWidget {
  final int numeroFactura;
  const DetalleCompraScreen({super.key, required this.numeroFactura});

  @override
  State<DetalleCompraScreen> createState() => _DetalleCompraScreenState();
}

class _DetalleCompraScreenState extends State<DetalleCompraScreen> {
  Map<String, dynamic>? _compra;
  bool    _loading       = true;
  bool    _pagando       = false;
  bool    _descXml       = false;
  bool    _descPdf       = false;
  bool    _enviandoEmail = false;
  bool    _emailEnviado  = false;
  String? _error;
  List<int>? _qrBytes;
  bool    _loadingQr     = false;
  String? _orderId;
  String? _clientId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargarQr() async {
    if (_qrBytes != null) return;
    setState(() => _loadingQr = true);
    try {
      final bytes = await ApiService.getQrCompra(widget.numeroFactura);
      if (mounted) setState(() => _qrBytes = bytes);
    } catch (e) {
      debugPrint("Error loading QR: $e");
    } finally {
      if (mounted) setState(() => _loadingQr = false);
    }
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getDetalleCompra(widget.numeroFactura);
      setState(() => _compra = data);

      final estado = (data['estado'] ?? '').toString().toUpperCase();
      if (estado == 'ABIERTA') {
        await _cargarQr();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _iniciarPagoPaypal() async {
    setState(() => _pagando = true);
    try {
      final res = await ApiService.crearPagoPaypal(widget.numeroFactura);
      final approvalUrl = res['approvalUrl'] ?? '';
      final orderId = res['orderId'] ?? '';
      final clientId = res['clientId'] ?? '';
      if (approvalUrl.isEmpty) throw 'No se obtuvo la URL de pago de PayPal';

      if (kIsWeb) {
        setState(() {
          _orderId = orderId;
          _clientId = clientId;
          _pagando = false;
        });
      } else {
        if (!mounted) return;
        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PaypalWebViewScreen(
              approvalUrl: approvalUrl,
              orderId: orderId,
              clientId: clientId,
              numeroFactura: widget.numeroFactura,
            ),
          ),
        );
        bool isSuccess = false;
        String? errorMsg;
        if (result is Map<String, dynamic>) {
          if (result['result'] == PaypalResult.success) {
            isSuccess = true;
          } else if (result['result'] == PaypalResult.error) {
            errorMsg = result['message'];
          }
        } else if (result == PaypalResult.success) {
          isSuccess = true;
        }

        if (isSuccess) {
          _cargar();
        } else {
          setState(() => _pagando = false);
          if (errorMsg != null) {
            if (errorMsg.toLowerCase().contains('stock') || errorMsg.toLowerCase().contains('insuficiente')) {
              _mostrarDialogoAlerta(
                titulo: 'Sin stock disponible',
                mensaje: 'Otro usuario ya realizó la compra de estos artículos y el stock se ha agotado. Tu pago no fue procesado.',
                esErrorStock: true,
              );
            } else {
              _mostrarDialogoAlerta(
                titulo: 'Error en el pago',
                mensaje: errorMsg.replaceFirst(RegExp(r'^Exception:\s*'), ''),
                esErrorStock: false,
              );
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString();
      setState(() => _pagando = false);
      if (errorMsg.toLowerCase().contains('stock') || errorMsg.toLowerCase().contains('insuficiente')) {
        _mostrarDialogoAlerta(
          titulo: 'Sin stock disponible',
          mensaje: 'Otro usuario ya realizó la compra de estos artículos y el stock se ha agotado. Tu pago no fue procesado.',
          esErrorStock: true,
        );
      } else {
        _mostrarDialogoAlerta(
          titulo: 'Error al iniciar PayPal',
          mensaje: errorMsg.replaceFirst(RegExp(r'^Exception:\s*'), ''),
          esErrorStock: false,
        );
      }
    }
  }

  Future<void> _descargarXml() async {
    setState(() => _descXml = true);
    try {
      final bytes = await ApiService.descargarXmlGet(widget.numeroFactura);
      await saveAndOpenFile(bytes, 'factura-${widget.numeroFactura}.xml');
    } catch (e) {
      if (!mounted) return;
      _snackError('Error al descargar XML: $e');
    } finally {
      if (mounted) setState(() => _descXml = false);
    }
  }

  Future<void> _descargarPdf() async {
    setState(() => _descPdf = true);
    try {
      final bytes = await ApiService.descargarPdfGet(widget.numeroFactura);
      await saveAndOpenFile(bytes, 'factura-${widget.numeroFactura}.pdf');
    } catch (e) {
      if (!mounted) return;
      _snackError('Error al descargar PDF: $e');
    } finally {
      if (mounted) setState(() => _descPdf = false);
    }
  }

  Future<void> _enviarEmail({bool silencioso = false}) async {
    if (_emailEnviado) return;
    setState(() => _enviandoEmail = true);
    try {
      await ApiService.enviarFacturaPorEmail(widget.numeroFactura);
      if (mounted) {
        setState(() => _emailEnviado = true);
        if (!silencioso) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Factura enviada a tu correo registrado'),
            backgroundColor: kGreen,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted && !silencioso) _snackError('No se pudo enviar el email: $e');
    } finally {
      if (mounted) setState(() => _enviandoEmail = false);
    }
  }

  void _snackError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: kError,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ));

  void _mostrarDialogoAlerta({required String titulo, required String mensaje, bool esErrorStock = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kError.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                esErrorStock ? Icons.inventory_2_outlined : Icons.error_outline_rounded,
                color: kError,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          mensaje,
          style: const TextStyle(fontSize: 13, color: kTextGrey, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Compra #${widget.numeroFactura}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _cargar)
              : _compra == null
                  ? const SizedBox()
                  : _buildBody(),
    );
  }

  Widget _buildBody() {
    final c              = _compra!;
    final estado         = (c['estado'] ?? '').toString().toUpperCase();
    final total          = double.tryParse('${c['totalCompra']}') ?? 0.0;
    final detalles       = c['detalles'] as List? ?? [];
    final requiereFactura = c['requiereFactura'] as bool? ?? false;
    final esPendiente    = estado == 'PENDIENTE_PAGO';
    final esAbierta      = estado == 'ABIERTA';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── Encabezado ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: kTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.receipt_long_outlined, color: kTeal, size: 22),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Compra #${c['numeroFactura']}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextDark)),
                const SizedBox(height: 2),
                Text(_formatFecha(c['createdAt']?.toString() ?? ''),
                    style: const TextStyle(fontSize: 12, color: kTextGrey)),
              ]),
              const Spacer(),
              _EstadoChip(estado: estado),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFEEF0F3)),
            const SizedBox(height: 16),

            // Información adicional
            if (c['metodoPago'] != null) ...[
              _infoRow(Icons.payment_outlined, 'Método de pago', '${c['metodoPago']}'),
              const SizedBox(height: 8),
            ],
            if (c['lugarEntrega'] != null) ...[
              _infoRow(Icons.location_on_outlined, 'Entrega', '${c['lugarEntrega']}'),
              const SizedBox(height: 8),
            ],

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total de la compra',
                  style: TextStyle(fontSize: 14, color: kTextGrey, fontWeight: FontWeight.w600)),
              Text('\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTeal)),
            ]),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Título productos ─────────────────────────────────────────
        Row(children: [
          Container(width: 3, height: 16, decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          const Text('Productos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextGrey, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 10),

        ...detalles.map((d) => _DetalleItem(detalle: d)),

        const SizedBox(height: 20),


        // ── Botón PAGAR (solo si PENDIENTE_PAGO) ────────────────────
        if (esPendiente) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3E8EE)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              // Encabezado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.schedule_rounded, color: Color(0xFFF9A825), size: 18),
                  SizedBox(width: 8),
                  Text('Pago pendiente',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF795548), fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 14),
              const Text(
                'Completa el pago de tu pedido con PayPal. Se abrirá la pantalla de inicio de sesión de PayPal en tu navegador.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7A8D), height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              // Botón PayPal real o PaypalWebSdkWidget inline en Web
              if (kIsWeb && _orderId != null && _clientId != null)
                PaypalWebSdkWidget(
                  clientId: _clientId!,
                  numeroFactura: widget.numeroFactura,
                  onCreateOrder: () async => _orderId!,
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
                        await ApiService.confirmarPagoPaypal(widget.numeroFactura, orderId ?? _orderId ?? '', payerId ?? '');
                      } catch (e) {
                        debugPrint("Error al confirmar pago PayPal en Web: $e");
                        final errorMsg = e.toString();
                        if (mounted) {
                          if (errorMsg.toLowerCase().contains('stock') || errorMsg.toLowerCase().contains('insuficiente')) {
                            _mostrarDialogoAlerta(
                              titulo: 'Sin stock disponible',
                              mensaje: 'Otro usuario ya realizó la compra de estos artículos y el stock se ha agotado. Tu pago no fue procesado.',
                              esErrorStock: true,
                            );
                          } else {
                            _mostrarDialogoAlerta(
                              titulo: 'Error en el pago',
                              mensaje: errorMsg.replaceFirst(RegExp(r'^Exception:\s*'), ''),
                              esErrorStock: false,
                            );
                          }
                        }
                      } finally {
                        if (mounted) Navigator.of(context).pop(); // Cierra diálogo
                      }
                      _cargar();
                    } else {
                      setState(() {
                        _orderId = null;
                        _clientId = null;
                      });
                    }
                  },
                )
              else
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _pagando ? null : () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _DatosPedidoSheet(
                          compra: _compra!,
                          onPagar: _iniciarPagoPaypal,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: _pagando
                        ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 10),
                            Text('Conectando con PayPal...', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          ])
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            // Logo PayPal texto
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(text: 'Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, fontStyle: FontStyle.italic)),
                                  TextSpan(text: 'Pal', style: TextStyle(color: Color(0xFF009CDE), fontWeight: FontWeight.w900, fontSize: 18, fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text('Pagar con PayPal',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          ]),
                  ),
                ),
              const SizedBox(height: 10),
              const Text(
                'Serás redirigido a PayPal para completar el pago de forma segura.',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF9E9E9E)),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ],

        // ── Comprobante con Código QR y Botones de descarga (solo si ABIERTA) ────────────
        if (esAbierta) ...[
          const SizedBox(height: 16),
          // Comprobante QR
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: kGreenLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Column(children: [
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_rounded, color: kGreen, size: 22),
                SizedBox(width: 8),
                Text('Pago Realizado',
                    style: TextStyle(fontWeight: FontWeight.w800, color: kGreen, fontSize: 15)),
              ]),
              const SizedBox(height: 14),
              if (_loadingQr)
                const SizedBox(
                  height: 150,
                  child: Center(child: CircularProgressIndicator(color: kGreen)),
                )
              else if (_qrBytes != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Image.memory(
                    Uint8List.fromList(_qrBytes!),
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                )
              else
                const Text('Código QR transaccional no disponible',
                    style: TextStyle(fontSize: 12, color: Color(0xFF558B2F))),
              const SizedBox(height: 12),
              const Text(
                'Tu pago ha sido procesado correctamente y la factura legal fue enviada al correo.',
                style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
          
          const SizedBox(height: 16),
          
          // Botones de Descarga
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.download_outlined, color: kTeal, size: 20),
                SizedBox(width: 8),
                Text('Documentos',
                    style: TextStyle(fontWeight: FontWeight.w800, color: kTextDark, fontSize: 14)),
              ]),
              const SizedBox(height: 12),

              // XML — siempre disponible
              _BotonDescarga(
                label: 'Descargar XML',
                sublabel: 'Para el portal SRI Ecuador',
                icon: Icons.code_outlined,
                color: const Color(0xFF1565C0),
                cargando: _descXml,
                onTap: _descargarXml,
              ),

              // PDF — solo si requiereFactura
              if (requiereFactura) ...[
                const SizedBox(height: 10),
                _BotonDescarga(
                  label: 'Descargar PDF',
                  sublabel: 'Factura para imprimir o archivar',
                  icon: Icons.picture_as_pdf_outlined,
                  color: kError,
                  cargando: _descPdf,
                  onTap: _descargarPdf,
                ),
              ],
            ]),
          ),
        ],

        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
    Icon(icon, size: 15, color: kTextGrey),
    const SizedBox(width: 6),
    Text('$label: ', style: const TextStyle(fontSize: 12, color: kTextGrey)),
    Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: kTextDark, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
  ]);

  String _formatFecha(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return raw; }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón de descarga reutilizable
// ─────────────────────────────────────────────────────────────────────────────
class _BotonDescarga extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final bool cargando;
  final VoidCallback onTap;
  const _BotonDescarga({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.cargando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: cargando ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: cargando
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            Text(sublabel, style: const TextStyle(fontSize: 11, color: kTextGrey)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _DetalleItem extends StatelessWidget {
  final dynamic detalle;
  const _DetalleItem({required this.detalle});

  @override
  Widget build(BuildContext context) {
    final nombre   = detalle['nombreProducto'] ?? 'Producto';
    final imagen   = detalle['urlImagen'];
    final cantidad = detalle['cantidad'] ?? 1;
    final precio   = double.tryParse('${detalle['precioUnitario']}') ?? 0.0;
    final subtotal = double.tryParse('${detalle['subtotal']}') ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imagen != null
                ? CachedNetworkImage(imageUrl: imagen, width: 58, height: 58, fit: BoxFit.cover,
                    placeholder: (ctx, url) => _imgFallback(),
                    errorWidget: (ctx, url, err) => _imgFallback())
                : _imgFallback(),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('\$${precio.toStringAsFixed(2)} c/u', style: const TextStyle(fontSize: 12, color: kTextGrey)),
          ])),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('x$cantidad', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kTeal)),
            ),
            const SizedBox(height: 4),
            Text('\$${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextDark)),
          ]),
        ]),
      ),
    );
  }

  Widget _imgFallback() => Container(width: 58, height: 58, color: kBackground,
      child: const Center(child: Icon(Icons.devices_outlined, size: 26, color: kTeal)));
}

// ─────────────────────────────────────────────────────────────────────────────
class _EstadoChip extends StatelessWidget {
  final String estado;
  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (estado) {
      'ABIERTA'       => (kGreen, kGreenLight),
      'PENDIENTE_PAGO'=> (const Color(0xFFF9A825), const Color(0xFFFFF8E1)),
      'ANULADA'       => (kError, const Color(0xFFFFEBEE)),
      _               => (kTextGrey, const Color(0xFFF5F5F5)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(
        estado == 'PENDIENTE_PAGO' ? 'PEND. PAGO' : estado,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: kError, size: 48),
      const SizedBox(height: 12),
      Text(error, style: const TextStyle(color: kTextGrey), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: onRetry,
        style: ElevatedButton.styleFrom(backgroundColor: kTeal, foregroundColor: Colors.white),
        child: const Text('Reintentar'),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet for order details and PayPal confirmation
// ─────────────────────────────────────────────────────────────────────────────
class _DatosPedidoSheet extends StatelessWidget {
  final Map<String, dynamic> compra;
  final VoidCallback onPagar;

  const _DatosPedidoSheet({
    required this.compra,
    required this.onPagar,
  });

  @override
  Widget build(BuildContext context) {
    final requiereFactura = compra['requiereFactura'] as bool? ?? false;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003087).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF003087), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Datos del pedido',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextDark),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Badge PayPal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF003087),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(text: 'Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, fontStyle: FontStyle.italic)),
                        TextSpan(text: 'Pal', style: TextStyle(color: Color(0xFF009CDE), fontWeight: FontWeight.w900, fontSize: 16, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PayPal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                        Text('Pago seguro y confiable con tu cuenta', style: TextStyle(color: Color(0xFFB3C4E8), fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Color(0xFF009CDE), size: 20),
                ],
              ),
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
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF003087), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Al presionar "Pagar con PayPal" se abrirá la página de inicio de sesión de PayPal.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF003087), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Lugar de entrega
            const Text(
              'Lugar de entrega',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextGrey, letterSpacing: 0.4),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: kTeal, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    compra['lugarEntrega'] ?? 'Retiro en Tienda',
                    style: const TextStyle(fontSize: 14, color: kTextDark, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
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
                value: requiereFactura,
                onChanged: null,
                activeThumbColor: kTeal,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            // Campos de factura
            if (requiereFactura) ...[
              const SizedBox(height: 14),
              const Text(
                'Datos de facturación',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextGrey, letterSpacing: 0.4),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, color: kTeal, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      compra['cedulaFactura'] ?? '',
                      style: const TextStyle(fontSize: 14, color: kTextDark, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, color: kTeal, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        compra['nombreFactura'] ?? '',
                        style: const TextStyle(fontSize: 14, color: kTextDark, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Botón Pagar con PayPal
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onPagar();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC439), // PayPal Yellow
                  foregroundColor: const Color(0xFF003087), // PayPal Blue
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Pagar con ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF003087))),
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(text: 'Pay', style: TextStyle(color: Color(0xFF003087), fontWeight: FontWeight.w900, fontSize: 18, fontStyle: FontStyle.italic)),
                          TextSpan(text: 'Pal', style: TextStyle(color: Color(0xFF009CDE), fontWeight: FontWeight.w900, fontSize: 18, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

