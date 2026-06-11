import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';

class ContingencyService {
  static final ContingencyService instance = ContingencyService._();
  ContingencyService._();

  final ValueNotifier<bool> isContingency = ValueNotifier(false);
  Timer? _timer;

  void start() {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    try {
      final data = await ApiService.getEstadoDB();
      final db = (data['activeDatabase'] ?? '').toString();
      isContingency.value = db != 'Supabase';
    } catch (_) {
      isContingency.value = true; // red fallback: si falla la red, modo seguro
    }
  }

  /// Llama esto antes de cualquier operación de escritura.
  /// Devuelve true si está en contingencia (la acción debe bloquearse).
  static bool bloquear(BuildContext context) {
    if (!instance.isContingency.value) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'NO SE PUEDE REALIZAR ESTA ACCIÓN: EL SISTEMA ESTÁ EN CONTINGENCIA',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ]),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    return true;
  }
}

/// Widget que muestra la franja de advertencia debajo del AppBar
/// cuando el sistema está en contingencia.
class ContingencyBanner extends StatelessWidget {
  final Widget child;
  const ContingencyBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ContingencyService.instance.isContingency,
      builder: (_, contingency, _) {
        return Column(
          children: [
            if (contingency)
              Container(
                width: double.infinity,
                color: Colors.orange.shade800,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Sistema en modo contingencia preventiva. Solo se permite la lectura de datos; compras y actualizaciones están bloqueadas.',
                        style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// Wrapper para botones de escritura — los deshabilita reactivamente en contingencia.
class ContingencyGuardButton extends StatelessWidget {
  final Widget Function(VoidCallback? onPressed) builder;
  final VoidCallback action;

  const ContingencyGuardButton({
    super.key,
    required this.builder,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ContingencyService.instance.isContingency,
      builder: (ctx, contingency, _) {
        return builder(contingency ? null : action);
      },
    );
  }
}
