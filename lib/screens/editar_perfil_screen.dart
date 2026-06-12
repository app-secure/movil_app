import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/contingency_service.dart';
import 'package:flutter/services.dart';

class EditarPerfilScreen extends StatefulWidget {
  final Map<String, dynamic> perfilActual;
  const EditarPerfilScreen({super.key, required this.perfilActual});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey       = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _cedulaCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _direccionCtrl;

  bool    _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.perfilActual;
    _nombreCtrl   = TextEditingController(text: p['nombreCompleto'] ?? p['nombre'] ?? '');
    _cedulaCtrl   = TextEditingController(text: p['cedula']?.toString() ?? '');
    _telefonoCtrl = TextEditingController(text: p['telefono']?.toString() ?? '');
    _direccionCtrl= TextEditingController(text: p['direccion']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (ContingencyService.bloquear(context)) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final idUsuario = prefs.getString('idUsuario') ?? '';
      if (idUsuario.isEmpty) throw 'Sesión no válida';

      final resultado = await ApiService.actualizarPerfil(idUsuario, {
        'nombreCompleto': _nombreCtrl.text.trim(),
        'cedula':         _cedulaCtrl.text.trim(),
        'telefono':       _telefonoCtrl.text.trim(),
        'direccion':      _direccionCtrl.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado correctamente'),
          backgroundColor: kGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, resultado);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
        title: const Text('Editar Perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _guardar,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ContingencyBanner(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: kError.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kError.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: kError, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: const TextStyle(color: kError, fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _Campo(
                      controller: _nombreCtrl,
                      label: 'Nombre completo',
                      icon: Icons.person_outline_rounded,
                      keyboard: TextInputType.name,
                      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Záéíóú�?É�?ÓÚñÑ\s]'))],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'El nombre es obligatorio';
                        if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _Campo(
                      controller: _cedulaCtrl,
                      label: 'Cédula',
                      icon: Icons.badge_outlined,
                      keyboard: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'La cédula es obligatoria';
                        if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) return 'Debe tener 10 dígitos';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _Campo(
                      controller: _telefonoCtrl,
                      label: 'Teléfono',
                      icon: Icons.phone_outlined,
                      keyboard: TextInputType.phone,
                      formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'El teléfono es obligatorio';
                        if (!RegExp(r'^09\d{8}$').hasMatch(v.trim())) return 'Debe empezar con 09 y tener 10 dígitos';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _Campo(
                      controller: _direccionCtrl,
                      label: 'Dirección',
                      icon: Icons.location_on_outlined,
                      keyboard: TextInputType.streetAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'La dirección es obligatoria';
                        if (v.trim().length < 5) return 'Ingresa una dirección válida';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ContingencyGuardButton(
                action: _guardar,
                builder: (onPressed) => SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : onPressed,
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('GUARDAR CAMBIOS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.8)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTeal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  final String? Function(String?) validator;
  final List<TextInputFormatter>? formatters;

  const _Campo({
    required this.controller,
    required this.label,
    required this.icon,
    required this.keyboard,
    required this.validator,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      textInputAction: TextInputAction.next,
      validator: validator,
      inputFormatters: formatters,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kTextGrey, fontSize: 13),
        prefixIcon: Icon(icon, color: kTeal, size: 20),
        filled: true,
        fillColor: kBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kTeal, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kError, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kError, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
