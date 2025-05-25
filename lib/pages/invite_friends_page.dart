import 'package:flutter/material.dart';

class InviteFriendsPage extends StatefulWidget {
  const InviteFriendsPage({Key? key}) : super(key: key);

  @override
  State<InviteFriendsPage> createState() => _InviteFriendsPageState();
}

class _InviteFriendsPageState extends State<InviteFriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedFriends = {};
  bool _isLoading = false;
  String _searchQuery = '';

  // TODO: Заменить на реальные данные из API
  final List<Map<String, dynamic>> _mockFriends = [
    {
      'id': '1',
      'name': 'Анна Иванова',
      'avatar': 'https://i.pravatar.cc/150?img=1',
    },
    {
      'id': '2',
      'name': 'Петр Сидоров',
      'avatar': 'https://i.pravatar.cc/150?img=2',
    },
    {
      'id': '3',
      'name': 'Мария Петрова',
      'avatar': 'https://i.pravatar.cc/150?img=3',
    },
  ];

  List<Map<String, dynamic>> _getFilteredFriends(String query) {
    if (query.isEmpty) return _mockFriends;
    return _mockFriends
        .where((friend) => friend['name']
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
  }

  Future<void> _inviteFriends() async {
    if (_selectedFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите хотя бы одного друга'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Реализовать отправку приглашений через API
      await Future.delayed(const Duration(seconds: 1)); // Имитация запроса
      if (mounted) {
        Navigator.pop(context, _selectedFriends.toList());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пригласить друзей'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _inviteFriends,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Готово',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск друзей',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: StatefulBuilder(
              builder: (context, setState) {
                final filteredFriends = _getFilteredFriends(_searchQuery);

                return ListView.builder(
                  itemCount: filteredFriends.length,
                  itemBuilder: (context, index) {
                    final friend = filteredFriends[index];
                    final isSelected = _selectedFriends.contains(friend['id']);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(friend['avatar']),
                      ),
                      title: Text(friend['name']),
                      trailing: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? Colors.green : Colors.grey,
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedFriends.remove(friend['id']);
                          } else {
                            _selectedFriends.add(friend['id']);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
