import 'package:flutter/material.dart';
import 'package:gather_club/pages/Example.dart';
import 'package:gather_club/api_services/admin_service.dart';
import 'package:gather_club/api_services/auth_service/auth_provider.dart';
import 'package:gather_club/nav_service/nav_page.dart';
import 'package:gather_club/pages/admin/admin_page.dart';
import 'package:gather_club/pages/admin/place_form_page.dart';
import 'package:gather_club/pages/auth_page.dart';
import 'package:gather_club/pages/reg_page.dart';
import 'package:gather_club/pages/shop_page.dart';
import 'package:gather_club/api_services/user_service/user.dart';
import 'package:gather_club/api_services/user_service/user_repo.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

final routes = {
  '/': (context) => FutureBuilder(
        future: Provider.of<AuthProvider>(context, listen: false).isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.data == true) {
            return FutureBuilder<User?>(
              future: _getCurrentUser(context),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                if (userSnapshot.hasData &&
                    userSnapshot.data?.role == 'ROLE_ADMIN') {
                  return AdminPage();
                }

                return NavPage();
              },
            );
          }
          return AuthPage();
        },
      ),
  '/login': (context) => AuthPage(),
  '/register': (context) => RegisterScreen(),
  '/home': (context) => NavPage(),
  '/admin': (context) => AdminPage(),
  '/shop': (context) => ShopPage(),
  '/admin/place/edit': (context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final adminService = Provider.of<AdminService>(context, listen: false);
    return PlaceFormPage(
      place: args['place'],
      onSave: args['onSave'],
      adminService: adminService,
    );
  },
  '/admin/place/create': (context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final adminService = Provider.of<AdminService>(context, listen: false);
    return PlaceFormPage(
      onSave: args['onSave'],
      adminService: adminService,
    );
  },
};

// Функция для получения текущего пользователя
Future<User?> _getCurrentUser(BuildContext context) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final userRepo = UserRepository(http.Client(), authProvider);
  return await userRepo.getCurrentUser();
}
