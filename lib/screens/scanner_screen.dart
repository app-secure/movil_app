import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/constants.dart';
import 'detalle_compra_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _procesado = false;
  bool _linterna  = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)  _controller.start();
    if (state == AppLifecycleState.paused)   _controller.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  int? _extraerNumeroFactura(String codigo) {
    final porUrl = RegExp(r'/compras/(\d+)').firstMatch(codigo);
    if (porUrl != null) return int.tryParse(porUrl.group(1)!);
    return int.tryParse(codigo.trim());
  }

  void _alDetectar(BarcodeCapture capture) {
    if (_procesado) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final numero = _extraerNumeroFactura(barcode!.rawValue!);
    if (numero == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('QR no válido. Escanea el código de una compra TechStore360.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _procesado = true);
    _controller.stop();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DetalleCompraScreen(numeroFactura: numero)),
    );
  }

  void _mostrarIngresoManual() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: kTeal, size: 24),
            SizedBox(width: 8),
            Text('Ingresar código', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingresa el número de factura o pedido manualmente:',
              style: TextStyle(color: kTextGrey, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Ej. 12',
                hintStyle: const TextStyle(color: kTextGrey, fontSize: 13),
                filled: true,
                fillColor: kBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: kTextGrey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              final num = int.tryParse(val);
              if (num != null) {
                Navigator.pop(ctx);
                setState(() => _procesado = true);
                _controller.stop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => DetalleCompraScreen(numeroFactura: num)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Por favor, ingresa un número válido.'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: Icon(
              _linterna ? Icons.flash_on : Icons.flash_off,
              color: _linterna ? Colors.amber : const Color(0xFF1E293B),
            ),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _linterna = !_linterna);
            },
          ),
          IconButton(
            tooltip: 'Cambiar cámara',
            icon: const Icon(Icons.flip_camera_ios_outlined, color: Color(0xFF1E293B)),
            onPressed: () => _controller.switchCamera(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Subtítulo pequeño
                const Text(
                  'Escaneo de Compra',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                // Título principal
                const Text(
                  'Escanear QR de Compra',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                // Descripción de la instrucción
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Apunta la cámara al código QR generado en la confirmación de la compra',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                      height: 1.4,
                    ),
                  ),
                ),
                const Spacer(),

                // Contenedor principal del escáner
                Center(
                  child: Container(
                    width: 270,
                    height: 270,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Feed de la cámara
                          MobileScanner(
                            controller: _controller,
                            onDetect: _alDetectar,
                          ),
                          // Animación de escaneo (línea que sube y baja)
                          const _ScanLineAnimation(),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),

                // Botón de ingreso manual
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: InkWell(
                    onTap: _mostrarIngresoManual,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard_outlined, color: const Color(0xFF334155).withOpacity(0.8), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '¿Problemas con la cámara? Ingresar código',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155).withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cargador intermedio si procesa
          if (_procesado)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(color: kTeal),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanLineAnimation extends StatefulWidget {
  const _ScanLineAnimation();

  @override
  State<_ScanLineAnimation> createState() => _ScanLineAnimationState();
}

class _ScanLineAnimationState extends State<_ScanLineAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: _animCtrl.value * 270,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: kTeal.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 2,
                    ),
                  ],
                  color: kTeal,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
