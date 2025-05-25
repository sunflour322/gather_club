import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.selectedPlace != null) {
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
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

    return DateFormat('d MMMM y, HH:mm', 'ru').format(dateTime);
  }

  void _createMeetup() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите дату и время встречи')),
      );
      return;
    }

    // TODO: Реализовать создание встречи через API
    print('Creating meetup...');
    print('Name: ${_nameController.text}');
    print('Description: ${_descriptionController.text}');
    print('Date: ${_getFormattedDateTime()}');
    print('Place: ${widget.selectedPlace}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание встречи'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createMeetup,
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
                    'Создать',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.selectedPlace != null)
              Card(
                child: ListTile(
                  leading: widget.selectedPlace!['imageUrl'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            widget.selectedPlace!['imageUrl'],
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.place),
                  title: Text(widget.selectedPlace!['name']),
                  subtitle: Text(widget.selectedPlace!['address'] ?? ''),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название встречи',
                border: OutlineInputBorder(),
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
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Дата и время'),
              subtitle: Text(
                _getFormattedDateTime() ?? 'Не выбрано',
                style: TextStyle(
                  color: _getFormattedDateTime() == null
                      ? Colors.grey
                      : Colors.black87,
                ),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
            ),
            const Divider(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/invite_friends');
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add),
                  SizedBox(width: 8),
                  Text('Пригласить друзей'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
