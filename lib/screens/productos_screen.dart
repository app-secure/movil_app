import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../core/api_service.dart';
import '../core/cart_manager.dart';
import '../screens/detalle_producto_screen.dart';
import '../screens/carrito_screen.dart';
import '../screens/login_screen.dart';
import '../screens/mis_compras_screen.dart';
import '../screens/perfil_screen.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  List<dynamic> _productos = [];
  bool _loading = true;
  String? _error;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getProductos();
      setState(() { _productos = data; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _actualizarCarrito() => setState(() => _cartCount = CartManager.instance.totalItems);

  Future<void> _logout() async {
    await ApiService.clearSession();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kTeal,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.storefront_outlined, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('TechStore360', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        actions: [
          // Mis compras
          IconButton(
            tooltip: 'Mis compras',
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisComprasScreen())),
          ),
          // Perfil
          IconButton(
            tooltip: 'Mi perfil',
            icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilScreen())),
          ),
          // Carrito con badge
          Stack(
            children: [
              IconButton(
                tooltip: 'Mi carrito',
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const CarritoScreen()));
                  _actualizarCarrito();
                },
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: Center(child: Text('$_cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                  ),
                ),
            ],
          ),
          // Cerrar sesión
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_outlined, color: Colors.white),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.w800)),
                content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: kTextGrey))),
                  ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(backgroundColor: kTeal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Salir'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarProductos,
        color: kTeal,
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: kError, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: kTextGrey), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _cargarProductos, style: ElevatedButton.styleFrom(backgroundColor: kTeal), child: const Text('Reintentar', style: TextStyle(color: Colors.white))),
                  ],
                ),
              )
            : _productos.isEmpty
              ? const Center(child: Text('No hay productos disponibles', style: TextStyle(color: kTextGrey)))
              : Column(
                  children: [
                    // Banner
                    Container(
                      color: kTeal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: Colors.white60, size: 16),
                          const SizedBox(width: 6),
                          Text('${_productos.length} productos disponibles', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 258,
                        ),
                        itemCount: _productos.length,
                        itemBuilder: (_, i) => _ProductoCard(
                          producto: _productos[i],
                          onCartUpdated: _actualizarCarrito,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _ProductoCard extends StatelessWidget {
  final dynamic producto;
  final VoidCallback onCartUpdated;
  const _ProductoCard({required this.producto, required this.onCartUpdated});

  @override
  Widget build(BuildContext context) {
    final nombre = producto['nombre'] ?? 'Sin nombre';
    final precio = double.tryParse('${producto['precio']}') ?? 0;
    final stock  = producto['stock'] ?? 0;
    final imagen = producto['urlImagen'];
    final hayStock = stock > 0;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetalleProductoScreen(idProducto: producto['idProducto']),
        ));
        onCartUpdated();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.09), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  imagen != null
                    ? CachedNetworkImage(
                        imageUrl: imagen,
                        height: 118, width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) => _imagenFallback(),
                        errorWidget: (ctx, url, err) => _imagenFallback(),
                      )
                    : _imagenFallback(),
                  if (!hayStock)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: kError, borderRadius: BorderRadius.circular(6)),
                          child: const Text('Sin stock', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Contenido
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '\$${precio.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTeal),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: hayStock ? const Color(0xFF2E7D32).withValues(alpha: 0.1) : kError.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 10, color: hayStock ? const Color(0xFF2E7D32) : kError),
                          const SizedBox(width: 4),
                          Text(
                            hayStock ? 'Stock: $stock' : 'Sin stock',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: hayStock ? const Color(0xFF2E7D32) : kError),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Pie de tarjeta — CTA
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Ver producto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTeal.withValues(alpha: 0.9))),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 10, color: kTeal.withValues(alpha: 0.8)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagenFallback() => Container(
    height: 118, color: kBackground,
    child: const Center(child: Icon(Icons.devices_outlined, size: 44, color: kTeal)),
  );
}
