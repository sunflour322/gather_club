import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gather_club/pages/Example.dart';
import 'package:gather_club/api_services/admin_service.dart';
import 'package:gather_club/api_services/auth_service/auth_provider.dart';
import 'package:gather_club/nav_service/nav_page.dart';
import 'package:gather_club/nav_service/routes.dart';
import 'package:gather_club/pages/admin/admin_page.dart';
import 'package:gather_club/pages/admin/place_form_page.dart';
import 'package:gather_club/pages/auth_page.dart';
import 'package:gather_club/pages/reg_page.dart';
import 'package:gather_club/api_services/user_service/avatar_provider.dart';
import 'package:gather_club/api_services/user_location_service.dart';
import 'package:gather_club/api_services/user_service/user.dart';
import 'package:gather_club/api_services/user_service/user_repo.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:gather_club/pages/account_page.dart';
import 'package:gather_club/pages/friend_search_page.dart';
import 'package:gather_club/pages/create_meetup_page.dart';
import 'package:gather_club/pages/chat_page.dart';
import 'package:gather_club/pages/shop_page.dart';
import 'package:gather_club/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(
  //   options: const FirebaseOptions(
  //       apiKey: 'AIzaSyBKakS4dzfbmsFSCP4NzN9eZ6SDLSeCcvo',
  //       appId: '1:874539196455:android:e0b90b6e7b41dc1e472e02',
  //       messagingSenderId: '874539196455',
  //       projectId: 'flutter-films-mukachev',
  //       storageBucket: 'flutter-films-mukachev.appspot.com'),
  // );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Функция для получения текущего пользователя
  Future<User?> _getCurrentUser(BuildContext context) async {
    try {
      print('_getCurrentUser: начало выполнения');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userRepo = UserRepository(http.Client(), authProvider);
      final user = await userRepo.getCurrentUser();

      // Отладочный вывод
      print('Получен пользователь: ${user?.username}');
      print('Роль пользователя: ${user?.role}');

      return user;
    } catch (e) {
      print('Ошибка при получении пользователя: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AvatarProvider()),
        ChangeNotifierProvider<UserLocationService>(
          create: (context) => UserLocationService(
            Provider.of<AuthProvider>(context, listen: false),
          ),
        ),
        Provider<AdminService>(
          create: (context) => AdminService(
            Provider.of<AuthProvider>(context, listen: false),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Gather Club',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ru', 'RU'),
          Locale('en', 'US'),
        ],
        locale: const Locale('ru', 'RU'),
        initialRoute: '/',
        routes: {
          '/': (context) {
            print('Инициализация корневого маршрута');

            // Проверяем авторизацию пользователя
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);

            Future.microtask(() async {
              try {
                final token = await authProvider.getToken();
                if (token != null) {
                  // Пользователь авторизован, перенаправляем на главную страницу
                  print(
                      'Пользователь авторизован, перенаправляем на главную страницу');
                  Navigator.of(context).pushReplacementNamed('/home');
                } else {
                  // Пользователь не авторизован, перенаправляем на страницу авторизации
                  print(
                      'Пользователь не авторизован, перенаправляем на страницу авторизации');
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              } catch (e) {
                print('Ошибка при проверке авторизации: $e');
                // В случае ошибки перенаправляем на страницу авторизации
                Navigator.of(context).pushReplacementNamed('/login');
              }
            });

            // Возвращаем загрузочный экран, который будет заменен
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Загрузка...'),
                  ],
                ),
              ),
            );
          },
          '/login': (context) => AuthPage(),
          '/register': (context) => RegisterScreen(),
          '/home': (context) => NavPage(),
          '/account': (context) => const AccountPage(),
          '/friends/search': (context) => const FriendSearchPage(),
          '/create_meetup': (context) => const CreateMeetupPage(),
          '/chat': (context) => const ChatPage(),
          '/shop': (context) => const ShopPage(),
          '/admin': (context) => const AdminPage(),
          '/admin/place/edit': (context) {
            final args = ModalRoute.of(context)!.settings.arguments
                as Map<String, dynamic>;
            final adminService =
                Provider.of<AdminService>(context, listen: false);
            return PlaceFormPage(
              place: args['place'],
              onSave: args['onSave'],
              adminService: adminService,
            );
          },
          '/admin/place/create': (context) {
            final args = ModalRoute.of(context)!.settings.arguments
                as Map<String, dynamic>;
            final adminService =
                Provider.of<AdminService>(context, listen: false);
            return PlaceFormPage(
              onSave: args['onSave'],
              adminService: adminService,
            );
          },
        },
      ),
    );
  }
}
