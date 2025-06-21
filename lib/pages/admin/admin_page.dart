import 'package:flutter/material.dart';
import 'package:gather_club/api_services/auth_service/auth_provider.dart';
import 'package:gather_club/pages/admin/places_management_page.dart';
import 'package:gather_club/api_services/admin_service.dart';
import 'package:gather_club/theme/app_theme.dart';
import 'package:gather_club/pages/Example.dart';
import 'package:provider/provider.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late final AdminService _adminService;

  @override
  void initState() {
    super.initState();
    try {
      print('AdminPage: initState');
      _adminService =
          AdminService(Provider.of<AuthProvider>(context, listen: false));
      print('AdminPage: _adminService создан успешно');
    } catch (e) {
      print('AdminPage: ошибка при инициализации: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель администратора'),
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Возвращаемся на главную страницу
            Navigator.of(context).pushReplacementNamed('/home');

            // Обновляем карту на странице Example.dart
            try {
              // Используем публичный метод для обновления карты
              // Передаем текущий контекст и координаты 0,0, чтобы карта обновилась с текущим местоположением
              ExamplePage.navigateToLocation(context, 0, 0);
              print(
                  'Запрос на обновление карты после выхода из админки отправлен');
            } catch (e) {
              print('Ошибка при обновлении карты: $e');
            }
          },
        ),
      ),
      body: PlacesManagementPage(adminService: _adminService),
    );
  }
}
