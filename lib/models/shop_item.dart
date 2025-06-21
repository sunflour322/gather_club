import 'dart:convert';

class ShopItem {
  final int id;
  final String name;
  final String description;
  final int price;
  final String? previewUrl;
  final bool isDefault;
  final bool isActive;
  final bool isPurchased;
  final bool isCurrentlyActive;

  ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.previewUrl,
    required this.isDefault,
    required this.isActive,
    required this.isPurchased,
    required this.isCurrentlyActive,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json, String type) {
    int id;
    switch (type) {
      case 'profileFrames':
        id = json['frameId'];
        break;
      case 'chatThemes':
        id = json['themeId'];
        break;
      case 'profileBackgrounds':
        id = json['backgroundId'];
        break;
      default:
        throw Exception('Unknown shop item type: $type');
    }

    return ShopItem(
      id: id,
      name: json['name'],
      description: json['description'],
      price: json['price'],
      previewUrl: json['previewUrl'],
      isDefault: json['isDefault'],
      isActive: json['isActive'],
      isPurchased: json['isPurchased'],
      isCurrentlyActive: json['isCurrentlyActive'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'previewUrl': previewUrl,
      'isDefault': isDefault,
      'isActive': isActive,
      'isPurchased': isPurchased,
      'isCurrentlyActive': isCurrentlyActive,
    };
  }
}

class ShopData {
  final List<ShopItem> profileFrames;
  final List<ShopItem> chatThemes;
  final List<ShopItem> profileBackgrounds;
  final int userBalance;

  ShopData({
    required this.profileFrames,
    required this.chatThemes,
    required this.profileBackgrounds,
    required this.userBalance,
  });

  factory ShopData.fromJson(Map<String, dynamic> json) {
    List<ShopItem> profileFrames = (json['profileFrames'] as List)
        .map((item) => ShopItem.fromJson(item, 'profileFrames'))
        .toList();

    List<ShopItem> chatThemes = (json['chatThemes'] as List)
        .map((item) => ShopItem.fromJson(item, 'chatThemes'))
        .toList();

    List<ShopItem> profileBackgrounds = (json['profileBackgrounds'] as List)
        .map((item) => ShopItem.fromJson(item, 'profileBackgrounds'))
        .toList();

    return ShopData(
      profileFrames: profileFrames,
      chatThemes: chatThemes,
      profileBackgrounds: profileBackgrounds,
      userBalance: json['userBalance'],
    );
  }
}

class ShopPurchaseRequest {
  final String itemType;
  final int itemId;

  ShopPurchaseRequest({
    required this.itemType,
    required this.itemId,
  });

  Map<String, dynamic> toJson() {
    return {
      'itemType': itemType,
      'itemId': itemId,
    };
  }
}

class ShopItemActivationRequest {
  final String itemType;
  final int itemId;
  final bool activate;

  ShopItemActivationRequest({
    required this.itemType,
    required this.itemId,
    required this.activate,
  });

  Map<String, dynamic> toJson() {
    return {
      'itemType': itemType,
      'itemId': itemId,
      'activate': activate,
    };
  }
}
