import 'package:flutter/material.dart';

class AvatarProvider with ChangeNotifier {
  String? _avatarUrl;

  String? get avatarUrl => _avatarUrl;

  void setAvatarUrl(String? url) {
    _avatarUrl = url;
    notifyListeners();
  }
}
