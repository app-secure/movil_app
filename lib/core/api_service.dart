import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiService {
  static String? _apiBaseUrl;

  static Future<String> getApiBaseUrl() async {
    if (_apiBaseUrl != null) return _apiBaseUrl!;
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString('custom_api_url');
    if (customUrl != null && customUrl.isNotEmpty) {
      _apiBaseUrl = customUrl;
      return customUrl;
    }
    const defaultUrl = 'http://10.79.9.56:5020';
    _apiBaseUrl = defaultUrl;
    return defaultUrl;
  }

  static Future<void> saveCustomApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url.trim().isEmpty) {
      await prefs.remove('custom_api_url');
      _apiBaseUrl = null;
    } else {
      var formattedUrl = url.trim();
      if (formattedUrl.endsWith('/')) {
        formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
      }
      await prefs.setString('custom_api_url', formattedUrl);
      _apiBaseUrl = formattedUrl;
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveSession(
    String token,
    String idUsuario,
    String email,
    String rol,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('idUsuario', idUsuario);
    await prefs.setString('email', email);
    await prefs.setString('rol', rol);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<Map<String, dynamic>> getMiEstado() async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw 'Sin sesión';
    final res = await _get('/api/usuarios/mi-estado', token: token);
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw data['mensaje'] ?? 'Error al verificar estado';
  }

  static Future<Map<String, dynamic>> getEstadoDB() async {
    final baseUrl = await getApiBaseUrl();
    final res = await http
        .get(Uri.parse('$baseUrl/api/test-db'), headers: _headers())
        .timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw 'Error al verificar estado de la base de datos';
  }

  static Future<bool> isUsuarioActivo() async {
    try {
      final data = await getMiEstado();
      return data['estado'] == true;
    } catch (_) {
      return true; // sin conexión: no bloquear
    }
  }

  static Map<String, String> _headers({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static Future<http.Response> _get(String path, {String? token}) async {
    final baseUrl = await getApiBaseUrl();
    try {
      final res = await http
          .get(Uri.parse('$baseUrl$path'), headers: _headers(token: token))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode < 500) return res;
    } on SocketException catch (_) {
    } on Exception catch (_) {}
    return http
        .get(Uri.parse('$baseUrl$path'), headers: _headers(token: token))
        .timeout(const Duration(seconds: 60));
  }

  static Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final encoded = jsonEncode(body);
    final baseUrl = await getApiBaseUrl();
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token: token),
            body: encoded,
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode < 500) return res;
    } on SocketException catch (_) {
    } on Exception catch (_) {}
    return http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers(token: token),
          body: encoded,
        )
        .timeout(const Duration(seconds: 60));
  }

  static Future<http.Response> _put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final encoded = jsonEncode(body);
    final baseUrl = await getApiBaseUrl();
    try {
      final res = await http
          .put(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token: token),
            body: encoded,
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode < 500) return res;
    } on SocketException catch (_) {
    } on Exception catch (_) {}
    return http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: _headers(token: token),
          body: encoded,
        )
        .timeout(const Duration(seconds: 60));
  }

  static Future<http.Response> _delete(String path, {String? token}) async {
    final baseUrl = await getApiBaseUrl();
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl$path'), headers: _headers(token: token))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode < 500) return res;
    } on SocketException catch (_) {
    } on Exception catch (_) {}
    return http
        .delete(Uri.parse('$baseUrl$path'), headers: _headers(token: token))
        .timeout(const Duration(seconds: 60));
  }

  // ── Auth ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final res = await _post('/api/usuarios/login', {
      'email': email,
      'password': password,
    });
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw data['mensaje'] ?? data['message'] ?? 'Error al iniciar sesión';
  }

  static Future<Map<String, dynamic>> registro(Map<String, String> body) async {
    final res = await _post('/api/usuarios/registro', body);
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) return data;
    throw data['mensaje'] ?? data['message'] ?? 'Error al registrarse';
  }

  // ── Productos ─────────────────────────────────────────────────────

  static Future<List<dynamic>> getProductos() async {
    final token = await getToken();
    final res = await _get('/api/productos', token: token);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw 'Error al cargar productos';
  }

  static Future<Map<String, dynamic>> getProducto(int id) async {
    final token = await getToken();
    final res = await _get('/api/productos/$id', token: token);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw 'Producto no encontrado';
  }

  // ── Compras ───────────────────────────────────────────────────────

  static Future<List<dynamic>> getComprasUsuario(String idUsuario) async {
    final token = await getToken();
    final res = await _get('/api/compras/usuario/$idUsuario', token: token);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw 'Error al cargar las compras';
  }

  static Future<Map<String, dynamic>> getDetalleCompra(
    int numeroFactura,
  ) async {
    final token = await getToken();
    final res = await _get('/api/compras/$numeroFactura', token: token);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw 'Error al cargar el detalle de la compra';
  }

  static Future<Map<String, dynamic>> realizarCompra(
    Map<String, dynamic> body,
  ) async {
    final token = await getToken();
    final res = await _post('/api/compras', body, token: token);
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) return data;
    throw data['mensaje'] ?? data['message'] ?? 'Error al realizar la compra';
  }

  // ── Perfil ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPerfil(String idUsuario) async {
    final token = await getToken();
    final res = await _get('/api/usuarios/$idUsuario', token: token);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw 'No se pudo cargar el perfil';
  }

  static Future<Map<String, dynamic>> actualizarPerfil(
    String idUsuario,
    Map<String, dynamic> body,
  ) async {
    final token = await getToken();
    final res = await _put(
      '/api/usuarios/$idUsuario/perfil',
      body,
      token: token,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw data['mensaje'] ?? data['message'] ?? 'Error al actualizar el perfil';
  }

  // ── Facturación ───────────────────────────────────────────────────

  static Future<String> getFacturaXml(int idCompra) async {
    final token = await getToken();
    final res = await _post('/api/facturacion', {
      'idCompra': idCompra,
    }, token: token);
    if (res.statusCode == 200) return res.body;
    throw 'Error al obtener la factura XML';
  }

  static Future<List<int>> descargarFacturaXml(int idCompra) async {
    final token = await getToken();
    final res = await _post('/api/facturacion/descargar', {
      'idCompra': idCompra,
    }, token: token);
    if (res.statusCode == 200) return res.bodyBytes;
    throw 'Error al descargar la factura XML';
  }

  static Future<Map<String, dynamic>> getFacturaConsultar(int idCompra) async {
    final token = await getToken();
    final res = await _get(
      '/api/facturacion/consultar/$idCompra',
      token: token,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw 'Error al consultar el comprobante';
  }

  // ── QR ────────────────────────────────────────────────────────────

  static Future<List<int>> getQrCompra(int numeroFactura) async {
    final token = await getToken();
    final res = await _get('/api/compras/$numeroFactura/qr', token: token);
    if (res.statusCode == 200) return res.bodyBytes;
    throw 'Error al obtener el código QR';
  }

  // ── Pagos ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> consultarEstadoPago(
    int numeroFactura,
  ) async {
    final token = await getToken();
    final res = await _get('/api/pagos/$numeroFactura/estado', token: token);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw 'Error al consultar el estado de pago';
  }

  static Future<Map<String, dynamic>> confirmarPago(int numeroFactura) async {
    final token = await getToken();
    final res = await _post(
      '/api/pagos/$numeroFactura/confirmar',
      {},
      token: token,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw data['mensaje'] ?? 'Error al confirmar el pago';
  }

  static Future<Map<String, dynamic>> crearPagoPaypal(int numeroFactura) async {
    final token = await getToken();
    final res = await _post(
      '/api/pagos/paypal/crear/$numeroFactura',
      {},
      token: token,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) return data;
    throw data['mensaje'] ?? 'Error al iniciar pago con PayPal';
  }

  static Future<Map<String, dynamic>> crearPagoPaypalSinOrden(
    Map<String, dynamic> body,
  ) async {
    final token = await getToken();
    final res = await _post('/api/pagos/paypal/crear', body, token: token);
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) return data;
    throw data['mensaje'] ?? 'Error al iniciar pago con PayPal';
  }

  static Future<String> getPaypalClientId() async {
    final token = await getToken();
    final res = await _get('/api/pagos/paypal/client-id', token: token);
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data['clientId'] ?? '';
    throw data['mensaje'] ?? 'Error al obtener el Client ID de PayPal';
  }

  static Future<Map<String, dynamic>> confirmarPagoPaypal(
    int? numeroFactura,
    String token,
    String payerId,
  ) async {
    final tokenSession = await getToken();
    var path =
        '/api/pagos/paypal/success?token=$token&PayerID=$payerId&json=true';
    if (numeroFactura != null && numeroFactura > 0) {
      path += '&numeroFactura=$numeroFactura';
    }
    final res = await _get(path, token: tokenSession);
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw data['mensaje'] ?? 'Error al confirmar pago con PayPal';
  }

  // ── Facturación (GET endpoints) ───────────────────────────────────

  static Future<List<int>> descargarXmlGet(int idCompra) async {
    final token = await getToken();
    final res = await _get(
      '/api/facturacion/$idCompra/xml/descargar',
      token: token,
    );
    if (res.statusCode == 200) return res.bodyBytes;
    throw 'Error al descargar la factura XML';
  }

  static Future<List<int>> descargarPdfGet(int idCompra) async {
    final token = await getToken();
    final res = await _get(
      '/api/facturacion/$idCompra/pdf/descargar',
      token: token,
    );
    if (res.statusCode == 200) return res.bodyBytes;
    throw 'Error al descargar el PDF';
  }

  static Future<Map<String, dynamic>> enviarFacturaPorEmail(
    int idCompra,
  ) async {
    final token = await getToken();
    final res = await _post(
      '/api/facturacion/$idCompra/enviar-email',
      {},
      token: token,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw data['mensaje'] ?? 'Error al enviar la factura por correo';
  }

  static Future<Map<String, dynamic>> anularCompra(int numeroFactura) async {
    final token = await getToken();
    final res = await _delete('/api/compras/$numeroFactura', token: token);
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw data['mensaje'] ?? 'Error al cancelar la compra';
  }
}
