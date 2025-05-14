import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gather_club/Example.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/nav_service/nav_page.dart';
import 'package:gather_club/nav_service/routes.dart';
import 'package:gather_club/pages/auth_page.dart';
import 'package:gather_club/pages/reg_page.dart';
import 'package:provider/provider.dart';
import 'package:yandex_maps_mapkit/init.dart' as init;

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
  init.initMapkit(apiKey: 'c9779f9c-08da-40fd-b236-5f3af3b435ba');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MaterialApp(
        title: 'Auth Demo',
        theme: ThemeData(
          primarySwatch: Colors.orange,
        ),
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => FutureBuilder(
                future: Provider.of<AuthProvider>(context, listen: false)
                    .isLoggedIn(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }
                  return snapshot.data == true ? NavPage() : AuthPage();
                },
              ),
          '/login': (context) => AuthPage(),
          '/register': (context) => RegisterScreen(),
          '/home': (context) => NavPage(),
        },
      ),
    );
  }
}
