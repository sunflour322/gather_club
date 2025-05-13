import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final Completer<MapWindow> _mapController = Completer();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Center(
          child: SizedBox(
        width: 300, // или MediaQuery.of(context).size.width
        height: 300, // задайте нужную высоту
        child: YandexMap(
          onMapCreated: (mapWindow) => _mapController.complete(mapWindow),
        ),
      )),
    );
  }
}
