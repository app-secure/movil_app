import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import 'editar_perfil_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Map<String, dynamic>? _perfil;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final idUsuario = prefs.getString('idUsuario') ?? '';
      if (idUsuario.isEmpty) throw 'Sesión no válida';
      final data = await ApiService.getPerfil(idUsuario);
      setState(() => _perfil = data);
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mi Perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          if (_perfil != null)
            IconButton(
              tooltip: 'Editar perfil',
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: () async {
                final actualizado = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(builder: (_) => EditarPerfilScreen(perfilActual: _perfil!)),
                );
                if (actualizado != null) setState(() => _perfil = actualizado);
              },
            ),
        ],
      ),
      body: _loading
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
                      ElevatedButton(
                        onPressed: _cargarPerfil,
                        style: ElevatedButton.styleFrom(backgroundColor: kTeal, foregroundColor: Colors.white),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _perfil == null
                  ? const SizedBox()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          // Avatar
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              gradient: kTealGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: kTeal.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _initiales(_perfil!['nombreCompleto'] ?? _perfil!['nombre'] ?? _perfil!['email'] ?? '?'),
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _perfil!['nombreCompleto'] ?? _perfil!['nombre'] ?? 'Sin nombre',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextDark),
                          ),
                          const SizedBox(height: 4),
                          _RolChip(rol: _perfil!['rol'] ?? ''),
                          const SizedBox(height: 28),
                          // Tarjeta de datos
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              children: [
                                _FilaPerfil(
                                  icon: Icons.email_outlined,
                                  label: 'Correo',
                                  valor: _perfil!['email'] ?? '—',
                                ),
                                _Divider(),
                                if (_perfil!['telefono'] != null) ...[
                                  _FilaPerfil(
                                    icon: Icons.phone_outlined,
                                    label: 'Teléfono',
                                    valor: _perfil!['telefono'].toString(),
                                  ),
                                  _Divider(),
                                ],
                                if (_perfil!['direccion'] != null) ...[
                                  _FilaPerfil(
                                    icon: Icons.location_on_outlined,
                                    label: 'Dirección',
                                    valor: _perfil!['direccion'].toString(),
                                  ),
                                  _Divider(),
                                ],
                                _FilaPerfil(
                                  icon: Icons.toggle_on_outlined,
                                  label: 'Estado',
                                  valor: (_perfil!['estado'] ?? 'activo').toString(),
                                  valorColor: (_perfil!['estado'] == 'activo' || _perfil!['estado'] == true)
                                      ? const Color(0xFF2E7D32)
                                      : kError,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ID de usuario (colapsado)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.fingerprint_outlined, color: kTeal, size: 20),
                                const SizedBox(width: 10),
                                const Text('ID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _perfil!['idUsuario']?.toString() ?? _perfil!['uid']?.toString() ?? '—',
                                    style: const TextStyle(fontSize: 11, color: kTextGrey, fontFamily: 'monospace'),
                                    overflow: TextOverflow.ellipsis,
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

  String _initiales(String text) {
    final parts = text.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return text.isNotEmpty ? text[0].toUpperCase() : '?';
  }
}

class _RolChip extends StatelessWidget {
  final String rol;
  const _RolChip({required this.rol});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: kTeal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rol.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kTeal, letterSpacing: 1),
      ),
    );
  }
}

class _FilaPerfil extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final Color? valorColor;
  const _FilaPerfil({required this.icon, required this.label, required this.valor, this.valorColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: kTeal, size: 20),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextGrey)),
          const Spacer(),
          Flexible(
            child: Text(
              valor,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valorColor ?? kTextDark),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 52, endIndent: 18, color: Color(0xFFEEF0F3));
}
