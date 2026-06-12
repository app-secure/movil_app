import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import 'detalle_compra_screen.dart';
import 'factura_screen.dart';

class MisComprasScreen extends StatefulWidget {
  const MisComprasScreen({super.key});

  @override
  State<MisComprasScreen> createState() => _MisComprasScreenState();
}

class _MisComprasScreenState extends State<MisComprasScreen> {
  List<dynamic> _compras = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final idUsuario = prefs.getString('idUsuario') ?? '';
      if (idUsuario.isEmpty) throw 'Sesión no válida';
      final data = await ApiService.getComprasUsuario(idUsuario);
      // Filtrar para mostrar únicamente las compras exitosas/pagadas (estado ABIERTA)
      final comprasFiltradas = data.where((c) => (c['estado'] ?? '').toString().toUpperCase() == 'ABIERTA').toList();
      setState(() => _compras = comprasFiltradas);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mis Compras',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
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
          : _compras.isEmpty
          ? const _EmptyView()
          : RefreshIndicator(
              onRefresh: _cargar,
              color: kTeal,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _compras.length,
                separatorBuilder: (_, i) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _CompraCard(
                  compra: _compras[i],
                  onRefresh: _cargar,
                ),
              ),
            ),
    );
  }
}

class _CompraCard extends StatelessWidget {
  final dynamic compra;
  final VoidCallback? onRefresh;
  const _CompraCard({required this.compra, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final numero = compra['numeroFactura'];
    final total = double.tryParse('${compra['totalCompra']}') ?? 0.0;
    final estado = (compra['estado'] ?? '').toString();
    final estadoUpper = estado.toUpperCase();
    final fecha = _formatFecha(compra['createdAt']?.toString() ?? '');
    final esAbierta = estadoUpper == 'ABIERTA';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // �?cono de compra
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    esAbierta
                        ? Icons.shopping_bag_rounded
                        : Icons.shopping_bag_outlined,
                    color: kTeal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Datos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compra #$numero',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        fecha,
                        style: const TextStyle(fontSize: 12, color: kTextGrey),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _EstadoChip(estado: estado),
                          const Spacer(),
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kTeal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Botón "Ver Factura" — solo si está PAGADA (ABIERTA)
            if (esAbierta) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFEEF0F3)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Abre el modal de factura completa con XML y PDF
                    mostrarFacturaComprobanteSheet(
                      context,
                      numeroFactura: numero is int ? numero : int.tryParse('$numero') ?? 0,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text(
                    'Ver Factura',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ],

          ],
        ),
      ),
    );
  }

  String _formatFecha(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;
  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final upper = estado.toUpperCase();
    final color = switch (upper) {
      'ABIERTA'        => kTeal,
      'PENDIENTE_PAGO' => const Color(0xFFF9A825),
      'ANULADA'        => kError,
      _                => kTextGrey,
    };
    final label = upper == 'PENDIENTE_PAGO' ? 'PEND. PAGO' : estado;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
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
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: kError, size: 48),
        const SizedBox(height: 12),
        Text(
          error,
          style: const TextStyle(color: kTextGrey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: kTeal,
            foregroundColor: Colors.white,
          ),
          child: const Text('Reintentar'),
        ),
      ],
    ),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.shopping_bag_outlined,
          size: 64,
          color: kTeal.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        const Text(
          'Aún no tienes compras',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kTextGrey,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '¡Explora nuestros productos!',
          style: TextStyle(fontSize: 13, color: kTextGrey),
        ),
      ],
    ),
  );
}
