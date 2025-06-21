import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service/auth_provider.dart';
import '../models/shop_item.dart';

class ShopService {
  static const String baseUrl = 'http://212.67.8.92:8080';
  final AuthProvider _authProvider;

  ShopService(this._authProvider);

  Future<ShopData> getAllShopItems(int userId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/items/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ShopData.fromJson(data);
      } else {
        throw Exception('Ошибка загрузки товаров: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка при получении товаров магазина: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> purchaseItem(
      int userId, ShopPurchaseRequest request) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shop/purchase/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Ошибка покупки товара: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка при покупке товара: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> setItemActive(
      int userId, ShopItemActivationRequest request) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shop/activate/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Ошибка активации/деактивации товара: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка при активации/деактивации товара: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserPurchasedItems(int userId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/purchased/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Ошибка загрузки купленных товаров: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка при получении купленных товаров: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserActiveItems(int userId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/active/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Ошибка загрузки активных товаров: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка при получении активных товаров: $e');
      rethrow;
    }
  }
}
