import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gather_club/widgets/custom_notification.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:gather_club/pages/invite_friends_page.dart';
import 'package:gather_club/meetup_service/meetup_service.dart';
import 'package:gather_club/user_service/friend.dart';
import 'dart:developer' as developer;

class CreateMeetupPage extends StatefulWidget {
  final Map<String, dynamic>? selectedPlace;

  const CreateMeetupPage({Key? key, this.selectedPlace}) : super(key: key);

  @override
  State<CreateMeetupPage> createState() => _CreateMeetupPageState();
}

class _CreateMeetupPageState extends State<CreateMeetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  List<Friend> _selectedFriends = [];
  late MeetupService _meetupService;

  @override
  void initState() {
    super.initState();
    if (widget.selectedPlace != null) {
      _nameController.text = 'Встреча в ${widget.selectedPlace!['name']}';
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _meetupService = MeetupService(authProvider);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      if (_selectedTime == null) {
        _selectTime();
      }
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  String? _getFormattedDateTime() {
    if (_selectedDate == null || _selectedTime == null) return null;

    final date = _selectedDate!;
    final time = _selectedTime!;
    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
  }

  DateTime? _getScheduledDateTime() {
    if (_selectedDate == null || _selectedTime == null) return null;

    final date = _selectedDate!;
    final time = _selectedTime!;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _createMeetup() async {
    developer.log('Starting meetup creation process');
    developer.log('Selected place: ${widget.selectedPlace}');

    if (!_formKey.currentState!.validate()) {
      developer.log('Form validation failed');
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      developer.log('Date or time not selected');
      CustomNotification.show(
        context,
        'Выберите дату и время встречи',
      );
      return;
    }

    if (widget.selectedPlace == null) {
      developer.log('Place not selected');
      CustomNotification.show(
        context,
        'Выберите место встречи',
      );
      return;
    }

    setState(() => _isLoading = true);
    developer.log('Setting loading state to true');

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = await authProvider.getUserId();
      developer.log('Got user ID: $userId');

      final scheduledDateTime = _getScheduledDateTime();
      developer.log('Scheduled date time: $scheduledDateTime');

      final invitedUserIds = _selectedFriends.map((e) => e.userId).toList();
      developer.log('Selected friends IDs: $invitedUserIds');

      final meetupRequest = {
        'placeId': widget.selectedPlace!['id'],
        'name': _nameController.text,
        'description': _descriptionController.text,
        'scheduledTime': scheduledDateTime!.toIso8601String(),
        'invitedUserIds': invitedUserIds,
      };
      developer.log('Prepared meetup request: $meetupRequest');

      final response = await _meetupService.createMeetup(userId, meetupRequest);
      developer.log('Received response from createMeetup: $response');

      if (mounted) {
        developer.log('Navigation back with response');
        Navigator.of(context).pop(response);
        CustomNotification.show(
          context,
          'Встреча успешно создана',
        );

        // Обновляем список чатов
        Navigator.pushNamed(context, '/chat');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error during meetup creation',
        error: e,
        stackTrace: stackTrace,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          'Ошибка при создании встречи: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _navigateToInviteFriends() async {
    developer.log('Navigating to invite friends page');
    try {
      final result = await Navigator.push<List<Friend>>(
        context,
        MaterialPageRoute(
          builder: (context) => const InviteFriendsPage(),
        ),
      );

      developer.log('Received result from invite friends: $result');

      if (result != null && mounted) {
        setState(() => _selectedFriends = result);
        developer.log('Updated selected friends: $_selectedFriends');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error during friend selection',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Widget _buildSelectedFriends() {
    if (_selectedFriends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Приглашенные друзья',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedFriends.length,
            itemBuilder: (context, index) {
              final friend = _selectedFriends[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: friend.avatarUrl != null
                            ? Image.network(
                                friend.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/default_avatar.png',
                                    fit: BoxFit.cover,
                                  );
                                },
                              )
                            : Image.asset(
                                'assets/default_avatar.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      friend.username,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание встречи'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.selectedPlace != null)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: widget.selectedPlace!['imageUrl'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(
                                            widget.selectedPlace!['imageUrl']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: Colors.grey[200],
                              ),
                              child: widget.selectedPlace!['imageUrl'] == null
                                  ? const Icon(Icons.place,
                                      size: 30, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.selectedPlace!['name'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (widget.selectedPlace!['address'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        widget.selectedPlace!['address'],
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Название встречи',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      prefixIcon: const Icon(Icons.event),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите название встречи';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Описание',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      prefixIcon: const Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Дата и время'),
                      subtitle: Text(
                        _getFormattedDateTime() ?? 'Не выбрано',
                        style: TextStyle(
                          color: _getFormattedDateTime() == null
                              ? Colors.grey
                              : Colors.black87,
                        ),
                      ),
                      onTap: _selectDate,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _navigateToInviteFriends,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_add),
                        const SizedBox(width: 8),
                        Text(
                          _selectedFriends.isEmpty
                              ? 'Пригласить друзей'
                              : 'Выбрано друзей: ${_selectedFriends.length}',
                        ),
                      ],
                    ),
                  ),
                  if (_selectedFriends.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSelectedFriends(),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createMeetup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Создать встречу',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
