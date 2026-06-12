class CartItem {
  final int idProducto;
  final String nombre;
  final double precio;
  final String? urlImagen;
  int stock;
  int cantidad;

  CartItem({
    required this.idProducto,
    required this.nombre,
    required this.precio,
    this.urlImagen,
    this.stock = 999,
    this.cantidad = 1,
  });

  double get subtotal => precio * cantidad;
}

class CartManager {
  CartManager._();
  static final CartManager instance = CartManager._();

  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  int get totalItems => _items.fold(0, (s, i) => s + i.cantidad);
  double get total => _items.fold(0, (s, i) => s + i.subtotal);

  /// Actualiza el stock de un producto y ajusta la cantidad en el carrito si excede el nuevo stock.
  void actualizarStock(int idProducto, int nuevoStock) {
    final idx = _items.indexWhere((i) => i.idProducto == idProducto);
    if (idx >= 0) {
      _items[idx].stock = nuevoStock;
      if (_items[idx].cantidad > nuevoStock) {
        _items[idx].cantidad = nuevoStock;
      }
    }
  }

  /// Retorna null si ok, o mensaje de error si no se puede agregar
  String? agregar(CartItem item) {
    final idx = _items.indexWhere((i) => i.idProducto == item.idProducto);
    if (idx >= 0) {
      final nuevaCantidad = _items[idx].cantidad + item.cantidad;
      if (nuevaCantidad > item.stock) {
        return 'Solo hay ${item.stock} unidades disponibles (ya tienes ${_items[idx].cantidad} en el carrito)';
      }
      _items[idx].cantidad = nuevaCantidad;
    } else {
      if (item.cantidad > item.stock) {
        return 'Stock insuficiente. Solo hay ${item.stock} unidades disponibles';
      }
      _items.add(item);
    }
    return null;
  }

  /// Retorna false si excede el stock
  bool subirCantidad(int idProducto) {
    final idx = _items.indexWhere((i) => i.idProducto == idProducto);
    if (idx < 0) return false;
    if (_items[idx].cantidad >= _items[idx].stock) return false;
    _items[idx].cantidad++;
    return true;
  }

  void cambiarCantidad(int idProducto, int cantidad) {
    final idx = _items.indexWhere((i) => i.idProducto == idProducto);
    if (idx >= 0) {
      if (cantidad <= 0) {
        _items.removeAt(idx);
      } else {
        _items[idx].cantidad = cantidad;
      }
    }
  }

  void eliminar(int idProducto) => _items.removeWhere((i) => i.idProducto == idProducto);

  void limpiar() => _items.clear();
}
