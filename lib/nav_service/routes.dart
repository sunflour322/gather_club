import 'package:flutter/material.dart';
import 'package:gather_club/Example.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/nav_service/nav_page.dart';
import 'package:gather_club/pages/auth_page.dart';
import 'package:gather_club/pages/reg_page.dart';
import 'package:provider/provider.dart';

final routes = {
  '/': (context) => FutureBuilder(
        future: Provider.of<AuthProvider>(context, listen: false).isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data == true ? ExamplePage() : AuthPage();
        },
      ),
  '/login': (context) => AuthPage(),
  '/register': (context) => RegisterScreen(),
  '/home': (context) => ExamplePage(),
};
