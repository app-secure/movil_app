import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/file_downloader.dart';
import '../core/constants.dart';
import '../core/api_service.dart';
import '../core/cart_manager.dart';
import 'detalle_compra_screen.dart';

Future<void> mostrarFacturaSheet(
  BuildContext context, {
  required dynamic numeroFactura,
  required List<CartItem> items,
  required double total,
  String metodoPago = 'PayPhone',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FacturaSheet(
      numeroFactura: numeroFactura,
      items: items,
      total: total,
      metodoPago: metodoPago,
    ),
  );
}

Future<void> mostrarFacturaComprobanteSheet(
  BuildContext context, {
  required int numeroFactura,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FacturaHtmlModal(
      numeroFactura: numeroFactura,
      items: const [],
      total: 0,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet principal: resumen de compra + QR si es PayPhone
// ─────────────────────────────────────────────────────────────────────────────
class _FacturaSheet extends StatelessWidget {
  final dynamic numeroFactura;
  final List<CartItem> items;
  final double total;
  final String metodoPago;
  const _FacturaSheet({
    required this.numeroFactura,
    required this.items,
    required this.total,
    required this.metodoPago,
  });

  void _abrirVistaFactura(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FacturaHtmlModal(
        numeroFactura: numeroFactura,
        items: items,
        total: total,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esPayPhone = metodoPago == 'PayPhone';
    final totalConIva = total * 1.15;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * (esPayPhone ? 0.92 : 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E6B7A), Color(0xFF2A7F8F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esPayPhone ? '¡Pedido creado!' : '¡Compra exitosa!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        esPayPhone
                            ? 'Escanea el QR para pagar · Factura #$numeroFactura'
                            : 'Factura #$numeroFactura',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // QR para PayPhone
                  if (esPayPhone) ...[
                    _QrSection(
                      numeroFactura:
                          int.tryParse('$numeroFactura') ?? numeroFactura,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Tabla de productos
                  Container(
                    decoration: BoxDecoration(
                      color: kBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: kTeal.withValues(alpha: 0.08),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'PRODUCTO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: kTextGrey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'CANT.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: kTextGrey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: kTextGrey,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...items.asMap().entries.map((e) {
                          final i = e.key;
                          final item = e.value;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: i % 2 == 0 ? Colors.white : kBackground,
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.nombre,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: kTextDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '×${item.cantidad}',
                                    style: const TextStyle(
                                      color: kTextGrey,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '\$${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: kTextDark,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Totales
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _row('Subtotal', '\$${total.toStringAsFixed(2)}'),
                        const SizedBox(height: 6),
                        _row(
                          'IVA (15%)',
                          '\$${(total * 0.15).toStringAsFixed(2)}',
                        ),
                        Divider(height: 16, color: Colors.grey.shade300),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL CON IVA',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: kTextDark,
                              ),
                            ),
                            Text(
                              '\$${totalConIva.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: kTeal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Botones fijos
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Column(
              children: [
                if (!esPayPhone)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _abrirVistaFactura(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.receipt_long_outlined, size: 20),
                      label: const Text(
                        'Ver factura',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                if (esPayPhone) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Cierra el sheet y navega al detalle de la compra (pendiente de pago)
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetalleCompraScreen(
                              numeroFactura:
                                  int.tryParse('$numeroFactura') ??
                                  numeroFactura,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                      label: const Text(
                        'Ver detalle del pedido',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kTeal,
                      side: const BorderSide(color: kTeal, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.storefront_outlined, size: 20),
                    label: const Text(
                      'Seguir comprando',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: kTextGrey, fontSize: 13)),
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: kTextDark,
          fontSize: 13,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección QR: carga la imagen desde la API y ofrece descargarla
// ─────────────────────────────────────────────────────────────────────────────
class _QrSection extends StatefulWidget {
  final int numeroFactura;
  const _QrSection({required this.numeroFactura});

  @override
  State<_QrSection> createState() => _QrSectionState();
}

class _QrSectionState extends State<_QrSection> {
  List<int>? _qrBytes;
  bool _cargando = true;
  bool _descargando = false;

  @override
  void initState() {
    super.initState();
    _cargarQr();
  }

  Future<void> _cargarQr() async {
    try {
      final bytes = await ApiService.getQrCompra(widget.numeroFactura);
      if (mounted)
        setState(() {
          _qrBytes = bytes;
          _cargando = false;
        });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _descargar() async {
    if (_qrBytes == null) return;
    setState(() => _descargando = true);
    try {
      await saveAndOpenFile(_qrBytes!, 'qr-compra-${widget.numeroFactura}.png');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_2, color: Color(0xFFF9A825), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Código QR de pago',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF795548),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Escanea este código con la sección "Escanear QR" para confirmar tu pago',
            style: TextStyle(fontSize: 11, color: Color(0xFF8D6E63)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          // Imagen QR
          if (_cargando)
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator(color: kTeal)),
            )
          else if (_qrBytes != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Image.memory(
                Uint8List.fromList(_qrBytes!),
                width: 170,
                height: 170,
                fit: BoxFit.contain,
              ),
            )
          else
            const Icon(Icons.qr_code_2_outlined, size: 80, color: kTextGrey),

          const SizedBox(height: 12),

          // Botón descargar QR
          if (_qrBytes != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _descargando ? null : _descargar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF795548),
                  side: const BorderSide(color: Color(0xFFFFE082), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _descargando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF795548),
                        ),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(
                  _descargando ? 'Guardando...' : 'Descargar QR',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segundo modal: Comprobante de la API + botón descargar PDF
// ─────────────────────────────────────────────────────────────────────────────
class _FacturaHtmlModal extends StatefulWidget {
  final dynamic numeroFactura;
  final List<CartItem> items;
  final double total;
  const _FacturaHtmlModal({
    required this.numeroFactura,
    required this.items,
    required this.total,
  });

  @override
  State<_FacturaHtmlModal> createState() => _FacturaHtmlModalState();
}

class _ProductoItem {
  final String nombre;
  final int cantidad;
  final double precio;
  final double subtotal;
  _ProductoItem({
    required this.nombre,
    required this.cantidad,
    required this.precio,
    required this.subtotal,
  });
}

class _FacturaHtmlModalState extends State<_FacturaHtmlModal> {
  bool _cargando = true;
  bool _descargando = false;
  bool _descargandoXml = false;
  Map<String, dynamic>? _comprobante;
  String? _error;

  // Datos cargados desde la API cuando el modal se abre desde "Mis Compras"
  List<_ProductoItem> _productos = [];
  double _totalCargado = 0;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    if (mounted)
      setState(() {
        _cargando = true;
        _error = null;
      });
    final int id =
        int.tryParse('${widget.numeroFactura}') ?? widget.numeroFactura;
    // Carga en paralelo: comprobante SRI + detalle de compra
    await Future.wait([
      _cargarComprobante(id),
      if (widget.items.isEmpty) _cargarDetalleCompra(id),
    ]);
  }

  Future<void> _cargarComprobante(int id) async {
    try {
      final data = await ApiService.getFacturaConsultar(id);
      if (mounted) setState(() => _comprobante = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarDetalleCompra(int id) async {
    try {
      final detalle = await ApiService.getDetalleCompra(id);
      final total =
          double.tryParse(
            '${detalle['subtotal'] ?? detalle['totalCompra'] ?? 0}',
          ) ??
          0.0;
      final detalles = (detalle['detalles'] as List? ?? []);
      final productos = detalles.map((d) {
        return _ProductoItem(
          nombre:
              d['nombreProducto']?.toString() ??
              d['nombre']?.toString() ??
              'Producto',
          cantidad: (d['cantidad'] as num?)?.toInt() ?? 1,
          precio: double.tryParse('${d['precioUnitario'] ?? 0}') ?? 0.0,
          subtotal: double.tryParse('${d['subtotal'] ?? 0}') ?? 0.0,
        );
      }).toList();
      if (mounted)
        setState(() {
          _totalCargado = total;
          _productos = productos;
        });
    } catch (_) {
      // Silently ignore — the user still sees the SRI comprobante
    }
  }

  Future<void> _descargar() async {
    setState(() => _descargando = true);
    try {
      final pdfBytes = await ApiService.descargarPdfGet(
        int.tryParse('${widget.numeroFactura}') ?? widget.numeroFactura,
      );
      await saveAndOpenFile(pdfBytes, 'factura-${widget.numeroFactura}.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descargar PDF: $e'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  Future<void> _descargarXml() async {
    setState(() => _descargandoXml = true);
    try {
      final xmlBytes = await ApiService.descargarXmlGet(
        int.tryParse('${widget.numeroFactura}') ?? widget.numeroFactura,
      );
      await saveAndOpenFile(xmlBytes, 'factura-${widget.numeroFactura}.xml');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descargar XML: $e'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _descargandoXml = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      height: screenH * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: kTeal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Factura Generada',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kTextDark,
                        ),
                      ),
                      Text(
                        'Factura #${widget.numeroFactura}',
                        style: const TextStyle(fontSize: 12, color: kTextGrey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Expanded(child: _buildContenido()),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_cargando || _error != null || _descargandoXml)
                          ? null
                          : _descargarXml,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: _descargandoXml
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.code_outlined, size: 20),
                      label: Text(
                        _descargandoXml ? 'Descargando...' : 'Descargar XML',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: (_cargando || _error != null || _descargando)
                          ? null
                          : _descargar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: _descargando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined, size: 20),
                      label: Text(
                        _descargando ? 'Descargando...' : 'Descargar PDF',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    if (_cargando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: kTeal),
            SizedBox(height: 14),
            Text(
              'Consultando validez SRI...',
              style: TextStyle(color: kTextGrey, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 44,
              ),
              const SizedBox(height: 12),
              const Text(
                'Estado SRI no disponible',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(color: kTextGrey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargarTodo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final sri = _comprobante;
    // Usa los items del widget si vienen del flujo normal; si no, usa los cargados desde la API
    final List<dynamic> itemsEfectivos = widget.items.isNotEmpty
        ? widget.items
        : _productos;
    final bool sonCartItems = widget.items.isNotEmpty;
    final double subtotalEfectivo = widget.items.isNotEmpty
        ? widget.total
        : _totalCargado;
    final double totalConIva = subtotalEfectivo * 1.15;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sri != null) ...[
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                'Autorización SRI',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextGrey,
                ),
              ),
            ),
            _ComprobanteCard(
              children: [
                _Fila(
                  'Estado SRI',
                  sri['estado']?.toString() ?? 'PENDIENTE',
                  valorColor: (sri['estado'] == 'AUTORIZADO')
                      ? const Color(0xFF2E7D32)
                      : Colors.orange,
                ),
                _Fila(
                  'Clave de Acceso',
                  sri['claveAcceso']?.toString() ?? 'S/N',
                  isMonospace: true,
                ),
                _Fila(
                  'Mensaje',
                  sri['mensaje']?.toString() ?? 'En espera de validación',
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'Detalle de Comprobante',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kTextGrey,
              ),
            ),
          ),
          _ComprobanteCard(
            children: [
              _Fila('# Factura', '#${widget.numeroFactura}'),
              _Fila('Subtotal', '\$${subtotalEfectivo.toStringAsFixed(2)}'),
              _Fila(
                'IVA (15%)',
                '\$${(subtotalEfectivo * 0.15).toStringAsFixed(2)}',
              ),
              _Fila(
                'Total General',
                '\$${totalConIva.toStringAsFixed(2)}',
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (itemsEfectivos.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                'Productos comprados',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextGrey,
                ),
              ),
            ),
            ...itemsEfectivos.map((item) {
              final nombre = sonCartItems
                  ? (item as CartItem).nombre
                  : (item as _ProductoItem).nombre;
              final cantidad = sonCartItems
                  ? (item as CartItem).cantidad
                  : (item as _ProductoItem).cantidad;
              final precio = sonCartItems
                  ? (item as CartItem).precio
                  : (item as _ProductoItem).precio;
              final subtotal = sonCartItems
                  ? (item as CartItem).subtotal
                  : (item as _ProductoItem).subtotal;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ComprobanteCard(
                  children: [
                    _Fila('Producto', nombre),
                    _Fila('Cantidad', '$cantidad'),
                    _Fila('P. Unitario', '\$${precio.toStringAsFixed(2)}'),
                    _Fila(
                      'Subtotal',
                      '\$${subtotal.toStringAsFixed(2)}',
                      bold: true,
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _formatFecha(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

class _ComprobanteCard extends StatelessWidget {
  final List<Widget> children;
  const _ComprobanteCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Column(children: children),
  );
}

class _Fila extends StatelessWidget {
  final String label;
  final String valor;
  final bool bold;
  final Color? valorColor;
  final bool isMonospace;

  const _Fila(
    this.label,
    this.valor, {
    this.bold = false,
    this.valorColor,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: kTextGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              color: valorColor ?? kTextDark,
              fontFamily: isMonospace ? 'monospace' : null,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}
