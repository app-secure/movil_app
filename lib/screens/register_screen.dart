import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/api_service.dart';
import 'login_screen.dart';
import 'productos_screen.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _nombreCtrl    = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _cedulaCtrl    = TextEditingController();
  final _telefonoCtrl  = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  bool _loading      = false;
  bool _showPass     = false;
  bool _showConfirm  = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();    _emailCtrl.dispose();
    _cedulaCtrl.dispose();    _telefonoCtrl.dispose();
    _direccionCtrl.dispose(); _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.registro({
        'nombreCompleto': _nombreCtrl.text.trim(),
        'email':          _emailCtrl.text.trim(),
        'cedula':         _cedulaCtrl.text.trim(),
        'telefono':       _telefonoCtrl.text.trim(),
        'direccion':      _direccionCtrl.text.trim(),
        'password':       _passwordCtrl.text,
      });
      // El backend de registro no devuelve token directo, hacemos login automático
      final loginData = await ApiService.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      await ApiService.saveSession(
        loginData['token'] ?? '',
        loginData['idUsuario'] ?? '',
        loginData['email'] ?? _emailCtrl.text.trim(),
        loginData['rol'] ?? 'USUARIO',
      );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProductosScreen()));
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kTealGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ──────────────────────────────────────
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Crear cuenta', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                            Text('TechStore360', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Card del formulario ──────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6))],
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [

                              // Error
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: kError.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: kError.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.error_outline, color: kError, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_error!, style: const TextStyle(color: kError, fontSize: 12))),
                                  ]),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // ── Sección: Información personal ──────
                              _sectionLabel('Información personal'),
                              const SizedBox(height: 12),
                              _field(_nombreCtrl,   'Nombre completo',    Icons.person_outline,       TextInputType.name,          _validateNombre,
                                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]'))]),
                              const SizedBox(height: 12),
                              _field(_emailCtrl,    'Correo electrónico', Icons.email_outlined,       TextInputType.emailAddress,  _validateEmail),
                              const SizedBox(height: 12),
                              _field(_cedulaCtrl,   'Cédula',             Icons.badge_outlined,       TextInputType.number,        _validateCedula,
                                  formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
                              const SizedBox(height: 12),
                              _field(_telefonoCtrl, 'Teléfono',           Icons.phone_outlined,       TextInputType.phone,         _validateTelefono,
                                  formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
                              const SizedBox(height: 12),
                              _field(_direccionCtrl,'Dirección',          Icons.location_on_outlined, TextInputType.streetAddress, _validateDireccion),

                              const SizedBox(height: 22),

                              // ── Sección: Seguridad ─────────────────
                              _sectionLabel('Seguridad'),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: !_showPass,
                                textInputAction: TextInputAction.next,
                                decoration: _deco('Contraseña', Icons.lock_outline).copyWith(
                                  suffixIcon: _eyeIcon(_showPass, () => setState(() => _showPass = !_showPass)),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                                  if (v.length < 6) return 'Mínimo 6 caracteres';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _confirmCtrl,
                                obscureText: !_showConfirm,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _register(),
                                decoration: _deco('Confirmar contraseña', Icons.lock_outline).copyWith(
                                  suffixIcon: _eyeIcon(_showConfirm, () => setState(() => _showConfirm = !_showConfirm)),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                                  if (v != _passwordCtrl.text) return 'Las contraseñas no coinciden';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              // Botón
                              SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kTeal,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: kTeal.withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: _loading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                    : const Text('CREAR CUENTA', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1)),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Link a login
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('¿Ya tienes cuenta? ', style: TextStyle(color: kTextGrey, fontSize: 13)),
                                  GestureDetector(
                                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                                    child: const Text('Inicia sesión', style: TextStyle(color: kTeal, fontSize: 13, fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Row(
    children: [
      Container(width: 3, height: 14, decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextGrey, letterSpacing: 0.5)),
    ],
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon, TextInputType keyboard, String? Function(String?) validator, {List<TextInputFormatter>? formatters}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      textInputAction: TextInputAction.next,
      decoration: _deco(label, icon),
      validator: validator,
      inputFormatters: formatters,
    );
  }

  Widget _eyeIcon(bool visible, VoidCallback onTap) => IconButton(
    icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: kTextGrey, size: 20),
    onPressed: onTap,
  );

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
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
  );

  String? _validateNombre(String? v) {
    if (v == null || v.trim().isEmpty) return 'El nombre es obligatorio';
    if (v.trim().length < 3) return 'Mínimo 3 caracteres';
    return null;
  }
  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'El correo es obligatorio';
    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v.trim())) return 'Correo no válido';
    return null;
  }
  String? _validateCedula(String? v) {
    if (v == null || v.trim().isEmpty) return 'La cédula es obligatoria';
    final c = v.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(c)) return 'Debe tener exactamente 10 dígitos';
    final provincia = int.parse(c.substring(0, 2));
    if (provincia < 1 || provincia > 24) return 'Cédula inválida (provincia no válida)';
    final tercero = int.parse(c[2]);
    if (tercero >= 6) return 'Cédula inválida';
    // Algoritmo de verificación (dígito verificador)
    final coefs = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    int suma = 0;
    for (int i = 0; i < 9; i++) {
      int val = int.parse(c[i]) * coefs[i];
      if (val > 9) val -= 9;
      suma += val;
    }
    final verificador = (10 - (suma % 10)) % 10;
    if (verificador != int.parse(c[9])) return 'Cédula ecuatoriana no válida';
    return null;
  }
  String? _validateTelefono(String? v) {
    if (v == null || v.trim().isEmpty) return 'El teléfono es obligatorio';
    if (!RegExp(r'^09\d{8}$').hasMatch(v.trim())) return 'Debe empezar con 09 y tener 10 dígitos';
    return null;
  }
  String? _validateDireccion(String? v) {
    if (v == null || v.trim().isEmpty) return 'La dirección es obligatoria';
    if (v.trim().length < 5) return 'Ingresa una dirección válida';
    return null;
  }
}
