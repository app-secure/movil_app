import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'core/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final loggedIn = await ApiService.isLoggedIn();
  bool puedeEntrar = false;
  if (loggedIn) {
    final activo = await ApiService.isUsuarioActivo();
    if (activo) {
      puedeEntrar = true;
    } else {
      await ApiService.clearSession();
    }
  }
  runApp(MyApp(startLoggedIn: puedeEntrar));
}

class MyApp extends StatelessWidget {
  final bool startLoggedIn;
  const MyApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TechStore360',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kTeal, brightness: Brightness.light),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: startLoggedIn ? const AuthWrapper() : const LoginScreen(),
    );
  }
}
