import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'core/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/productos_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final loggedIn = await ApiService.isLoggedIn();
  runApp(MyApp(startLoggedIn: loggedIn));
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
        colorScheme: ColorScheme.fromSeed(seedColor: kTeal),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: startLoggedIn ? const ProductosScreen() : const LoginScreen(),
    );
  }
}
