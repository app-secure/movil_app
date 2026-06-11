import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../core/api_service.dart';
import '../core/cart_manager.dart';

class DetalleProductoScreen extends StatefulWidget {
  final int idProducto;
  const DetalleProductoScreen({super.key, required this.idProducto});

  @override
  State<DetalleProductoScreen> createState() => _DetalleProductoScreenState();
}

class _DetalleProductoScreenState extends State<DetalleProductoScreen> {
  Map<String, dynamic>? _producto;
  bool _loading = true;
  int _cantidad = 1;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final data = await ApiService.getProducto(widget.idProducto);
      setState(() { _producto = data; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _agregar() {
    if (_producto == null) return;
    final stock = _producto!['stock'] ?? 0;
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(_snackError('Este producto no tiene stock disponible'));
      return;
    }
    final error = CartManager.instance.agregar(CartItem(
      idProducto: _producto!['idProducto'],
      nombre:     _producto!['nombre'] ?? '',
      precio:     double.tryParse('${_producto!['precio']}') ?? 0,
      urlImagen:  _producto!['urlImagen'],
      stock:      stock,
      cantidad:   _cantidad,
    ));
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(_snackError(error));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('$_cantidad × ${_producto!['nombre']} añadido al carrito')),
      ]),
      backgroundColor: const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
    Navigator.pop(context);
  }

  SnackBar _snackError(String msg) => SnackBar(
    content: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg)),
    ]),
    backgroundColor: kError,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    duration: const Duration(seconds: 3),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: kBackground,
        body: const Center(child: CircularProgressIndicator(color: kTeal)),
      );
    }
    if (_producto == null) {
      return Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(backgroundColor: kTeal, iconTheme: const IconThemeData(color: Colors.white)),
        body: const Center(child: Text('Producto no encontrado')),
      );
    }
    return _buildScaffold();
  }

  Widget _buildScaffold() {
    final nombre  = _producto!['nombre'] ?? '';
    final precio  = double.tryParse('${_producto!['precio']}') ?? 0;
    final stock   = _producto!['stock'] ?? 0;
    final imagen  = _producto!['urlImagen'];
    final hayStock = stock > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // AppBar con imagen expandible
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: kTeal,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: imagen != null
                ? CachedNetworkImage(
                    imageUrl: imagen,
                    fit: BoxFit.cover,
                    errorWidget: (ctx, url, err) => _fallback(),
                  )
                : _fallback(),
            ),
          ),

          // Contenido que llena el resto de la pantalla
          SliverFillRemaining(
            hasScrollBody: false,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + badge stock
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          nombre,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextDark, height: 1.25),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: hayStock ? const Color(0xFF2E7D32).withValues(alpha: 0.1) : kError.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hayStock ? const Color(0xFF2E7D32).withValues(alpha: 0.3) : kError.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          hayStock ? 'Stock: $stock' : 'Sin stock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: hayStock ? const Color(0xFF2E7D32) : kError,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Precio
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${precio.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: kTeal),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 5),
                        child: Text('sin IVA', style: TextStyle(fontSize: 12, color: kTextGrey)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Divider decorativo
                  Container(height: 1, decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [kTeal.withValues(alpha: 0.3), Colors.transparent]),
                  )),
                  const SizedBox(height: 24),

                  // Selector de cantidad
                  const Text('Cantidad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextGrey, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: kBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        _qtyBtn(
                          Icons.remove,
                          _cantidad > 1 ? () => setState(() => _cantidad--) : null,
                          enabled: _cantidad > 1,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$_cantidad',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextDark),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'de $stock disponibles',
                                style: const TextStyle(fontSize: 10, color: kTextGrey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        _qtyBtn(
                          Icons.add,
                          _cantidad < stock ? () => setState(() => _cantidad++) : null,
                          enabled: _cantidad < stock,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtotal
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kTeal.withValues(alpha: 0.07), kTeal.withValues(alpha: 0.03)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kTeal.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Subtotal', style: TextStyle(fontSize: 12, color: kTextGrey, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(
                              '\$${(precio * _cantidad).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kTeal),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_cantidad × \$${precio.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTeal),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Botones de acción
                  Row(
                    children: [
                      // Volver
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kTeal,
                          side: const BorderSide(color: kTeal, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          minimumSize: const Size(0, 54),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                            SizedBox(width: 4),
                            Text('Volver', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Agregar al carrito
                      Expanded(
                        child: ElevatedButton(
                          onPressed: hayStock ? _agregar : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTeal,
                            disabledBackgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 54),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hayStock ? Icons.add_shopping_cart_rounded : Icons.remove_shopping_cart_outlined,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hayStock ? 'Agregar al carrito' : 'Sin stock',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap, {required bool enabled}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? kTeal : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
            ? [BoxShadow(color: kTeal.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
            : [],
        ),
        child: Icon(icon, color: enabled ? Colors.white : Colors.grey.shade400, size: 20),
      ),
    );
  }

  Widget _fallback() => Container(
    color: kBackground,
    child: const Center(child: Icon(Icons.devices_outlined, size: 80, color: kTeal)),
  );
}
