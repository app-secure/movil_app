import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import 'login_screen.dart';
import 'productos_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  Timer? _timer;
  bool _dialogoVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciarVerificacion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Verifica también cuando el usuario vuelve a primer plano
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verificarEstado();
  }

  void _iniciarVerificacion() {
    _verificarEstado();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _verificarEstado());
  }

  Future<void> _verificarEstado() async {
    if (_dialogoVisible || !mounted) return;
    final activo = await ApiService.isUsuarioActivo();
    if (!activo && mounted && !_dialogoVisible) {
      _dialogoVisible = true;
      _mostrarModalDesactivado();
    }
  }

  void _mostrarModalDesactivado() {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          title: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: kError.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block_rounded, color: kError, size: 38),
              ),
              const SizedBox(height: 16),
              const Text(
                'Acceso Denegado',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: kTextDark),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kError.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kError.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'Tu cuenta fue desactivada por un administrador. Ya no tienes acceso a la aplicación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: kTextGrey, height: 1.6),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await ApiService.clearSession();
                    if (ctx.mounted) {
                      Navigator.of(ctx, rootNavigator: true).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kError,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const ProductosScreen();
}
