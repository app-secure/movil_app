import 'package:flutter/material.dart';



const Color kTeal       = Color(0xFF2A7F8F);
const Color kTealDark   = Color(0xFF1E6B7A);
const Color kTealLight  = Color(0xFF3D9BAC);
const Color kBackground = Color(0xFFF4F7F9);
const Color kTextDark   = Color(0xFF1A2F40);
const Color kTextGrey   = Color(0xFF6B7A8D);
const Color kError      = Color(0xFF950606);
const Color kGreen      = Color(0xFF627413);
const Color kGreenLight = Color(0xFFEEF1E0);

const LinearGradient kTealGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1E6B7A), Color(0xFF2A7F8F), Color(0xFF246E7C)],
);

Route createRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;
      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
  );
}
