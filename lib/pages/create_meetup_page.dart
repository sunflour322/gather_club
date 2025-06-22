import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gather_club/widgets/custom_notification.dart';
import 'package:gather_club/api_services/auth_service/auth_provider.dart';
import 'package:gather_club/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:gather_club/pages/invite_friends_page.dart';
import 'package:gather_club/api_services/meetup_service/meetup_service.dart';
import 'package:gather_club/api_services/user_service/friend.dart';
import 'dart:developer' as developer;

class CreateMeetupPage extends StatefulWidget {
  final Map<String, dynamic>? selectedPlace;
  final Map<String, dynamic>? meetupToEdit;
  final bool isEditing;

  const CreateMeetupPage(
      {Key? key, this.selectedPlace, this.meetupToEdit, this.isEditing = false})
      : super(key: key);

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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _meetupService = MeetupService(authProvider);

    if (widget.isEditing && widget.meetupToEdit != null) {
      // Заполняем форму данными из существующей встречи
      _nameController.text = widget.meetupToEdit!['name'] ?? '';
      _descriptionController.text = widget.meetupToEdit!['description'] ?? '';

      // Устанавливаем дату и время
      if (widget.meetupToEdit!['scheduledTime'] != null) {
        try {
          final scheduledTime =
              DateTime.parse(widget.meetupToEdit!['scheduledTime']);
          _selectedDate = scheduledTime;
          _selectedTime =
              TimeOfDay(hour: scheduledTime.hour, minute: scheduledTime.minute);
        } catch (e) {
          developer.log('Error parsing scheduledTime: $e');
        }
      }

      // Загружаем список приглашенных друзей, если они есть
      if (widget.meetupToEdit!['participants'] != null) {
        try {
          final participants = widget.meetupToEdit!['participants'] as List;
          _selectedFriends = participants.map((p) {
            final user = p['user'] ?? p;
            return Friend(
              userId: user['userId'],
              username: user['username'] ?? 'Unknown',
              avatarUrl: user['avatarUrl'],
              status: p['status'] ?? 'unknown',
              isOutgoing:
                  false, // Для участников встречи это не исходящий запрос дружбы
            );
          }).toList();
        } catch (e) {
          developer.log('Error parsing participants: $e');
        }
      }
    } else if (widget.selectedPlace != null) {
      _nameController.text = 'Встреча в ${widget.selectedPlace!['name']}';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    // Определяем начальную дату и минимальную дату
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;

    // Если выбранная дата в прошлом (при редактировании), используем её как firstDate
    // иначе используем текущую дату
    final firstDate = initialDate.isBefore(now)
        ? DateTime(initialDate.year, initialDate.month, initialDate.day)
        : DateTime(now.year, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ru', 'RU'),
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
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Localizations.override(
            context: context,
            locale: const Locale('ru', 'RU'),
            child: child!,
          ),
        );
      },
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

  Future<void> _saveMeetup() async {
    developer.log('Starting meetup creation process');
    developer.log('Selected place: ${widget.selectedPlace}');
    developer.log('- Place name: ${widget.selectedPlace!['name']}');
    developer.log('- Place address: ${widget.selectedPlace!['address']}');
    developer.log('- Latitude: ${widget.selectedPlace!['latitude']}');
    developer.log('- Longitude: ${widget.selectedPlace!['longitude']}');
    developer.log('- Place image URL: ${widget.selectedPlace!['imageUrl']}');

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

      final Map<String, dynamic> placeData;
      if (widget.isEditing &&
          widget.meetupToEdit != null &&
          widget.meetupToEdit!['place'] != null) {
        placeData = widget.meetupToEdit!['place'];
      } else {
        placeData = {
          'name': widget.selectedPlace!['name'],
          'address': widget.selectedPlace!['address'],
          'latitude': widget.selectedPlace!['latitude'],
          'longitude': widget.selectedPlace!['longitude'],
          'imageUrl': widget.selectedPlace!['imageUrl'],
        };
      }

      // Определяем ID места
      int placeId;
      if (widget.isEditing &&
          widget.meetupToEdit != null &&
          widget.meetupToEdit!['place'] != null &&
          widget.meetupToEdit!['place']['id'] != null) {
        // Используем ID места из объекта встречи
        placeId = widget.meetupToEdit!['place']['id'];
        developer.log('Using place ID from meetupToEdit: $placeId');
      } else if (widget.selectedPlace != null &&
          widget.selectedPlace!['id'] != null) {
        // Используем ID выбранного места
        placeId = widget.selectedPlace!['id'];
        developer.log('Using place ID from selectedPlace: $placeId');
      } else {
        // Если ID места не найден, используем значение по умолчанию
        placeId = 5;
        developer.log('Using default place ID: $placeId');
      }

      final meetupRequest = {
        'placeId': placeId,
        'name': _nameController.text,
        'description': _descriptionController.text,
        'scheduledTime': scheduledDateTime!.toIso8601String(),
        'invitedUserIds': invitedUserIds,
        'place': placeData,
      };
      developer.log('Prepared meetup request: $meetupRequest');

      Map<String, dynamic> response;
      String successMessage;

      if (widget.isEditing && widget.meetupToEdit != null) {
        // Обновляем существующую встречу
        final meetupId = widget.meetupToEdit!['meetupId'];
        response =
            await _meetupService.updateMeetup(meetupId, userId, meetupRequest);
        successMessage = 'Встреча успешно обновлена';
        developer.log('Received response from updateMeetup: $response');
      } else {
        // Создаем новую встречу
        response = await _meetupService.createMeetup(userId, meetupRequest);
        successMessage = 'Встреча успешно создана';
        developer.log('Received response from createMeetup: $response');
      }

      if (mounted) {
        developer.log('Navigation back with response');
        Navigator.of(context).pop(response);
        CustomNotification.show(
          context,
          successMessage,
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
      // Передаем уже выбранных друзей при переходе на страницу приглашения
      final result = await Navigator.push<List<Friend>>(
        context,
        MaterialPageRoute(
          builder: (context) => InviteFriendsPage(
            initialSelectedFriends: _selectedFriends,
          ),
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
          height: 110, // Увеличиваем высоту для отображения статуса
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedFriends.length,
            itemBuilder: (context, index) {
              final friend = _selectedFriends[index];

              // Определяем цвет и текст статуса
              Color statusColor = AppTheme.accentColor;
              String? statusText;

              // Проверяем статус друга
              switch (friend.status.toUpperCase()) {
                case 'ACCEPTED':
                  statusColor = Colors.green;
                  statusText = 'Принято';
                  break;
                case 'PENDING':
                  statusColor = Colors.orange;
                  statusText = 'Ожидает';
                  break;
                case 'DECLINED':
                  statusColor = Colors.red;
                  statusText = 'Отклонено';
                  break;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: statusText != null
                                  ? statusColor
                                  : AppTheme.accentColor,
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
                        if (statusText != null && widget.isEditing)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      friend.username,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (statusText != null && widget.isEditing)
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
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
        title: Text(
            widget.isEditing ? 'Редактирование встречи' : 'Создание встречи'),
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
                      backgroundColor: AppTheme.accentColor,
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
                onPressed: _isLoading ? null : _saveMeetup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: AppTheme.accentColor,
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
                    : Text(
                        widget.isEditing
                            ? 'Сохранить изменения'
                            : 'Создать встречу',
                        style: const TextStyle(
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
