import 'package:flutter/material.dart';
import 'package:gather_club/api_services/place_serice/place.dart';
import 'package:gather_club/theme/app_theme.dart';
import 'package:gather_club/widgets/custom_notification.dart';

class PlaceFormPage extends StatefulWidget {
  final Place? place;
  final Function(Map<String, dynamic>) onSave;

  const PlaceFormPage({
    Key? key,
    this.place,
    required this.onSave,
  }) : super(key: key);

  @override
  State<PlaceFormPage> createState() => _PlaceFormPageState();
}

class _PlaceFormPageState extends State<PlaceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _workingHoursController = TextEditingController();
  final _categoryController = TextEditingController();
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.place != null) {
      _nameController.text = widget.place!.name;
      _descriptionController.text = widget.place!.description ?? '';
      _latitudeController.text = widget.place!.latitude.toString();
      _longitudeController.text = widget.place!.longitude.toString();
      _addressController.text = widget.place!.address ?? '';
      _phoneController.text = widget.place!.phone ?? '';
      _workingHoursController.text = widget.place!.workingHours ?? '';
      _categoryController.text = widget.place!.category ?? '';
      _imageUrl = widget.place!.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _workingHoursController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      try {
        // Нормализуем значения широты и долготы, заменяя запятые на точки
        String normalizedLatitude =
            _latitudeController.text.replaceAll(',', '.');
        String normalizedLongitude =
            _longitudeController.text.replaceAll(',', '.');

        final placeData = {
          'name': _nameController.text,
          'description': _descriptionController.text,
          'latitude': double.parse(normalizedLatitude),
          'longitude': double.parse(normalizedLongitude),
          'address': _addressController.text,
          'phone': _phoneController.text,
          'workingHours': _workingHoursController.text,
          'category': _categoryController.text,
        };

        if (_imageUrl != null && _imageUrl!.isNotEmpty) {
          placeData['imageUrl'] = _imageUrl!;
        }

        widget.onSave(placeData);
        Navigator.of(context).pop();
        CustomNotification.show(context, 'Данные сохранены');
      } catch (e) {
        CustomNotification.show(context, 'Ошибка при сохранении: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.place == null ? 'Создать место' : 'Редактировать место'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Сохранить',
            onPressed: _submitForm,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Основная информация',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Название *',
                            hintText: 'Введите название места',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите название';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Описание',
                            hintText: 'Введите описание места',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Местоположение',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latitudeController,
                                decoration: const InputDecoration(
                                  labelText: 'Широта *',
                                  hintText: 'Например: 55.7558',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Введите широту';
                                  }
                                  // Заменяем запятую на точку для корректного парсинга
                                  String normalizedValue =
                                      value.replaceAll(',', '.');
                                  if (double.tryParse(normalizedValue) ==
                                      null) {
                                    return 'Введите корректное число (используйте точку или запятую)';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _longitudeController,
                                decoration: const InputDecoration(
                                  labelText: 'Долгота *',
                                  hintText: 'Например: 37.6173',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Введите долготу';
                                  }
                                  // Заменяем запятую на точку для корректного парсинга
                                  String normalizedValue =
                                      value.replaceAll(',', '.');
                                  if (double.tryParse(normalizedValue) ==
                                      null) {
                                    return 'Введите корректное число (используйте точку или запятую)';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Адрес',
                            hintText: 'Введите адрес места',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Контактная информация',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Телефон',
                            hintText: 'Введите телефон места',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _workingHoursController,
                          decoration: const InputDecoration(
                            labelText: 'Часы работы',
                            hintText: 'Например: Пн-Пт: 9:00-18:00',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Категория',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Категория',
                            hintText: 'Например: Ресторан, Кафе, Парк',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Изображение',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_imageUrl != null)
                          Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _imageUrl!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(Icons.error, size: 50),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.delete),
                                label: const Text('Удалить изображение'),
                                onPressed: () {
                                  setState(() {
                                    _imageUrl = null;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          )
                        else
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.image),
                              label: const Text('Добавить URL изображения'),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    final controller =
                                        TextEditingController(text: _imageUrl);
                                    return Dialog(
                                      child: Container(
                                        padding: const EdgeInsets.all(16.0),
                                        width: 300,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'URL изображения',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            TextField(
                                              controller: controller,
                                              decoration: const InputDecoration(
                                                hintText:
                                                    'Введите URL изображения',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(),
                                                  child: const Text('Отмена'),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _imageUrl = controller
                                                              .text.isNotEmpty
                                                          ? controller.text
                                                          : null;
                                                    });
                                                    Navigator.of(context).pop();
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppTheme.accentColor,
                                                  ),
                                                  child:
                                                      const Text('Сохранить'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Сохранить'),
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Отмена'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
