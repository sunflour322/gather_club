import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_services/auth_service/auth_provider.dart';
import '../models/shop_item.dart';
import '../api_services/shop_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_notification.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late ShopService _shopService;
  bool _isLoading = true;
  ShopData? _shopData;
  int _userId = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _shopService =
        ShopService(Provider.of<AuthProvider>(context, listen: false));
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = await authProvider.getUserId();
      if (userId == null) {
        throw Exception('Не удалось получить ID пользователя');
      }
      _userId = userId;

      final shopData = await _shopService.getAllShopItems(userId);

      if (mounted) {
        setState(() {
          _shopData = shopData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Ошибка при загрузке данных магазина: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          'Ошибка загрузки данных магазина: $e',
        );
      }
    }
  }

  Future<void> _purchaseItem(String itemType, int itemId) async {
    try {
      setState(() => _isLoading = true);

      String apiItemType;
      switch (itemType) {
        case 'profileFrames':
          apiItemType = 'profile_frame';
          break;
        case 'chatThemes':
          apiItemType = 'chat_theme';
          break;
        case 'profileBackgrounds':
          apiItemType = 'profile_background';
          break;
        default:
          apiItemType = '';
      }

      final request = ShopPurchaseRequest(
        itemType: apiItemType,
        itemId: itemId,
      );

      await _shopService.purchaseItem(_userId, request);

      // Обновляем данные после покупки
      await _loadShopData();

      if (mounted) {
        CustomNotification.show(
          context,
          'Товар успешно куплен!',
        );
      }
    } catch (e) {
      print('Ошибка при покупке товара: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          'Ошибка при покупке товара: $e',
        );
      }
    }
  }

  Future<void> _activateItem(String itemType, int itemId, bool active) async {
    try {
      setState(() => _isLoading = true);

      String apiItemType;
      switch (itemType) {
        case 'profileFrames':
          apiItemType = 'profile_frame';
          break;
        case 'chatThemes':
          apiItemType = 'chat_theme';
          break;
        case 'profileBackgrounds':
          apiItemType = 'profile_background';
          break;
        default:
          apiItemType = '';
      }

      final request = ShopItemActivationRequest(
        itemType: apiItemType,
        itemId: itemId,
        activate: active,
      );

      await _shopService.setItemActive(_userId, request);

      // Обновляем данные после активации/деактивации
      await _loadShopData();

      if (mounted) {
        CustomNotification.show(
          context,
          active ? 'Товар активирован!' : 'Товар деактивирован!',
        );
      }
    } catch (e) {
      print('Ошибка при активации/деактивации товара: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          'Ошибка при активации/деактивации товара: $e',
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Магазин'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Image.asset(
                  'assets/star.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  _shopData?.userBalance.toString() ?? '0',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Рамки'),
            Tab(text: 'Темы чата'),
            Tab(text: 'Фоны профиля'),
          ],
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.black,
          indicatorColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadShopData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildItemsList('profileFrames'),
                  _buildItemsList('chatThemes'),
                  _buildItemsList('profileBackgrounds'),
                ],
              ),
            ),
    );
  }

  Widget _buildItemsList(String itemType) {
    List<ShopItem> items;
    String apiItemType;

    switch (itemType) {
      case 'profileFrames':
        items = _shopData?.profileFrames ?? [];
        apiItemType = 'profile_frame';
        break;
      case 'chatThemes':
        items = _shopData?.chatThemes ?? [];
        apiItemType = 'chat_theme';
        break;
      case 'profileBackgrounds':
        items = _shopData?.profileBackgrounds ?? [];
        apiItemType = 'profile_background';
        break;
      default:
        items = [];
        apiItemType = '';
    }

    if (items.isEmpty) {
      return const Center(
        child: Text('Нет доступных товаров'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildShopItemCard(item, itemType);
      },
    );
  }

  Widget _buildShopItemCard(ShopItem item, String itemType) {
    final bool canBuy =
        _shopData!.userBalance >= item.price && !item.isPurchased;
    final bool canActivate = item.isPurchased && !item.isCurrentlyActive;
    final bool canDeactivate = item.isPurchased && item.isCurrentlyActive;

    String itemTypeRussian;
    switch (itemType) {
      case 'profileFrames':
        itemTypeRussian = 'Рамка';
        break;
      case 'chatThemes':
        itemTypeRussian = 'Тема чата';
        break;
      case 'profileBackgrounds':
        itemTypeRussian = 'Фон профиля';
        break;
      default:
        itemTypeRussian = 'Товар';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.previewUrl != null && item.previewUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.previewUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image_not_supported),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (item.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'По умолчанию',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            )
                          else
                            Row(
                              children: [
                                Image.asset(
                                  'assets/star.png',
                                  width: 16,
                                  height: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.price.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(width: 8),
                          if (item.isPurchased)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Куплено',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          if (item.isCurrentlyActive)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Активно',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canBuy)
                  ElevatedButton(
                    onPressed: () => _purchaseItem(itemType, item.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Купить'),
                  ),
                if (canActivate)
                  ElevatedButton(
                    onPressed: () => _activateItem(itemType, item.id, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Активировать'),
                  ),
                if (canDeactivate)
                  ElevatedButton(
                    onPressed: () => _activateItem(itemType, item.id, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Деактивировать'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
