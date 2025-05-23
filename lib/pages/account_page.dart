import 'package:flutter/material.dart';
import 'package:gather_club/place_serice/place.dart';
import 'package:gather_club/user_service/user.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  User? _user;
  String? _avatarUrl;
  List<Place> _userPlaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Здесь должна быть логика загрузки данных пользователя
    // Пример:
    /*
    final userRepo = UserRepository(http.Client(), AuthProvider());
    final user = await userRepo.getCurrentUser();
    final avatarUrl = await userRepo.getUserAvatarUrl(user?.userId ?? 0);
    final places = await _loadUserPlaces(user?.userId ?? 0);
    
    setState(() {
      _user = user;
      _avatarUrl = avatarUrl;
      _userPlaces = places;
      _isLoading = false;
    });
    */

    // Временные данные для демонстрации
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _user = User(
        userId: 1,
        username: 'traveler123',
        email: 'user@example.com',
        phoneNumber: '+1234567890',
        bio: 'Люблю путешествовать и находить интересные места!',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        isVerified: true,
      );
      _avatarUrl = 'https://randomuser.me/api/portraits/men/1.jpg';
      _userPlaces = [
        Place(
          placeId: 1,
          name: 'Крутая кофейня',
          description: 'Лучший кофе в городе',
          latitude: 55.7558,
          longitude: 37.6173,
          imageUrl:
              'https://firebasestorage.googleapis.com/v0/b/flutter-films-mukachev.appspot.com/o/GatherClub%2F5d34871cd5504276c974576fd8b96eee.jpg?alt=media&token=ebe5b717-5820-41c2-aa3c-fc2c1e3da68f',
          userImages: [
            PlaceImage(
              imageId: 1,
              imageUrl:
                  'https://firebasestorage.googleapis.com/v0/b/flutter-films-mukachev.appspot.com/o/GatherClub%2F1293618972-1885511239.jpg?alt=media&token=8b5fc161-366a-4b71-9be7-6c05bacd4f68',
              uploadedAt: DateTime.now(),
              isApproved: true,
              likes: 10,
              dislikes: 2,
            ),
          ],
        ),
      ];
      _isLoading = false;
    });
  }

  Future<List<Place>> _loadUserPlaces(int userId) async {
    // Здесь должна быть логика загрузки мест пользователя
    return [];
  }

  Widget _buildProfileHeader() {
    return Container(
      height: MediaQuery.of(context).size.height / 3,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade700, Colors.blue.shade400],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: _avatarUrl != null
                ? NetworkImage(_avatarUrl!)
                : const AssetImage('assets/default_avatar.png')
                    as ImageProvider,
            child: _avatarUrl == null
                ? const Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _user?.username ?? 'Пользователь',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_user?.isVerified ?? false)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Подтвержден',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Информация о пользователе',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20),
            _buildInfoRow(Icons.email, 'Email', _user?.email ?? 'Не указан'),
            _buildInfoRow(
                Icons.phone, 'Телефон', _user?.phoneNumber ?? 'Не указан'),
            _buildInfoRow(Icons.calendar_today, 'Дата регистрации',
                _user?.createdAt?.toLocal().toString().split(' ')[0] ?? ''),
            const SizedBox(height: 8),
            if (_user?.bio?.isNotEmpty ?? false)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'О себе:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_user!.bio!),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : 'Не указано',
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserPlacesSection() {
    if (_userPlaces.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Добавленные места',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _userPlaces.length,
                itemBuilder: (context, index) {
                  final place = _userPlaces[index];
                  return Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            place.imageUrl ?? 'https://via.placeholder.com/180',
                            height: 120,
                            width: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          place.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (place.userImages != null &&
                            place.userImages!.isNotEmpty)
                          Text(
                            'Фото: ${place.userImages!.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    // Здесь можно добавить статистику пользователя
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Статистика',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('12', 'Встреч'),
                _buildStatItem('5', 'Друзей'),
                _buildStatItem('8', 'Мест'),
                _buildStatItem('150', 'Очков'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            _buildUserInfoSection(),
            _buildStatsSection(),
            _buildUserPlacesSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
