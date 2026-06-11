import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  List<dynamic> _todosProductos = [];
  List<dynamic> _productos = [];
  List<String> _categorias = [];
  String _busqueda = '';
  String? _categoriaSeleccionada;
  bool _loading = true;
  String? _error;
  int _cartCount = 0;
  final TextEditingController _busquedaCtrl = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _nombreUsuario = '';
  String _emailUsuario  = '';

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final idUsuario = prefs.getString('idUsuario') ?? '';
    final email     = prefs.getString('email') ?? '';
    setState(() => _emailUsuario = email);
    try {
      final perfil = await ApiService.getPerfil(idUsuario);
      final nombre = perfil['nombreCompleto'] ?? perfil['nombre'] ?? '';
      setState(() => _nombreUsuario = nombre.toString().trim().isNotEmpty ? nombre.toString().trim() : email.split('@').first);
    } catch (_) {
      setState(() => _nombreUsuario = email.split('@').first);
    }
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getProductos();
      final conStock = data.where((p) => (p['stock'] ?? 0) > 0).toList();
      final cats = conStock
          .map((p) => (p['categoria'] ?? '').toString().trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      setState(() {
        _todosProductos = conStock;
        _categorias = cats;
      });
      _filtrar();
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _filtrar() {
    final q = _busqueda.toLowerCase();
    setState(() {
      _productos = _todosProductos.where((p) {
        final nombre = (p['nombre'] ?? '').toString().toLowerCase();
        final cat    = (p['categoria'] ?? '').toString().trim();
        final coincideNombre = q.isEmpty || nombre.contains(q);
        final coincideCat    = _categoriaSeleccionada == null || cat == _categoriaSeleccionada;
        return coincideNombre && coincideCat;
      }).toList();
    });
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
      key: _scaffoldKey,
      backgroundColor: kBackground,
      drawer: _ModernDrawer(
        nombre: _nombreUsuario,
        email: _emailUsuario,
        cartCount: _cartCount,
        onMisCompras: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MisComprasScreen()));
        },
        onPerfil: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilScreen()));
        },
        onCarrito: () async {
          Navigator.pop(context);
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CarritoScreen()));
          _actualizarCarrito();
        },
        onLogout: () {
          Navigator.pop(context);
          showDialog(
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
          );
        },
      ),
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
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          // Carrito con badge (se mantiene visible)
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
                    // Buscador + filtros
                    Container(
                      color: kTeal,
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Barra de búsqueda
                          TextField(
                            controller: _busquedaCtrl,
                            onChanged: (v) { _busqueda = v; _filtrar(); },
                            style: const TextStyle(fontSize: 14, color: kTextDark),
                            decoration: InputDecoration(
                              hintText: 'Buscar producto...',
                              hintStyle: TextStyle(color: kTextGrey.withValues(alpha: 0.7), fontSize: 14),
                              prefixIcon: const Icon(Icons.search_rounded, color: kTextGrey, size: 20),
                              suffixIcon: _busqueda.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, color: kTextGrey, size: 18),
                                      onPressed: () { _busquedaCtrl.clear(); _busqueda = ''; _filtrar(); },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          // Chips de categorías (solo si hay)
                          if (_categorias.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 32,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _CategoriaChip(
                                    label: 'Todos',
                                    selected: _categoriaSeleccionada == null,
                                    onTap: () { setState(() => _categoriaSeleccionada = null); _filtrar(); },
                                  ),
                                  const SizedBox(width: 6),
                                  ..._categorias.map((cat) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _CategoriaChip(
                                      label: cat,
                                      selected: _categoriaSeleccionada == cat,
                                      onTap: () { setState(() => _categoriaSeleccionada = _categoriaSeleccionada == cat ? null : cat); _filtrar(); },
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          // Contador
                          Row(children: [
                            const Icon(Icons.inventory_2_outlined, color: Colors.white60, size: 14),
                            const SizedBox(width: 5),
                            Text('${_productos.length} producto${_productos.length == 1 ? '' : 's'} encontrado${_productos.length == 1 ? '' : 's'}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ]),
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

// ─── Drawer moderno ──────────────────────────────────────────────────────────
class _ModernDrawer extends StatelessWidget {
  final String nombre;
  final String email;
  final int cartCount;
  final VoidCallback onMisCompras;
  final VoidCallback onPerfil;
  final VoidCallback onCarrito;
  final VoidCallback onLogout;

  const _ModernDrawer({
    required this.nombre,
    required this.email,
    required this.cartCount,
    required this.onMisCompras,
    required this.onPerfil,
    required this.onCarrito,
    required this.onLogout,
  });

  String _inicial() {
    final n = nombre.trim();
    return n.isNotEmpty ? n[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: Column(
          children: [
            // ── Header con gradiente ──────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: kTealGradient,
                borderRadius: BorderRadius.only(topRight: Radius.circular(32)),
              ),
              child: Stack(
                children: [
                  // Círculos decorativos de fondo
                  Positioned(
                    right: -30, top: -30,
                    child: Container(
                      width: 130, height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 30, bottom: -20,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  // Contenido
                  Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 24,
                      bottom: 24,
                      left: 22,
                      right: 22,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _inicial(),
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Nombre real
                        Text(
                          nombre.isNotEmpty ? nombre : 'Usuario',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        // Correo
                        Row(
                          children: [
                            Icon(Icons.alternate_email_rounded, size: 12, color: Colors.white.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                email,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Pill activo
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 7, height: 7,
                                  decoration: const BoxDecoration(color: Color(0xFF8BC34A), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text('Activo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Elementos del menú ────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  children: [
                    _DrawerItem(
                      icon: Icons.receipt_long_outlined,
                      label: 'Mis Compras',
                      color: kTeal,
                      onTap: onMisCompras,
                    ),
                    const SizedBox(height: 8),
                    _DrawerItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Mi Perfil',
                      color: kTeal,
                      onTap: onPerfil,
                    ),
                    const SizedBox(height: 8),
                    _DrawerItem(
                      icon: Icons.shopping_cart_outlined,
                      label: 'Mi Carrito',
                      color: kTeal,
                      badge: cartCount > 0 ? '$cartCount' : null,
                      onTap: onCarrito,
                    ),
                  ],
                ),
              ),
            ),

            // ── Cerrar sesión al fondo ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Cerrar sesión',
                color: kError,
                onTap: onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color == kError ? kError : kTextDark),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Chips de categoría ───────────────────────────────────────────────────────
class _CategoriaChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoriaChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.white : Colors.white.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? kTeal : Colors.white,
          ),
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
                        color: hayStock ? kGreen.withValues(alpha: 0.1) : kError.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 10, color: hayStock ? kGreen : kError),
                          const SizedBox(width: 4),
                          Text(
                            hayStock ? 'Stock: $stock' : 'Sin stock',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: hayStock ? kGreen : kError),
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
