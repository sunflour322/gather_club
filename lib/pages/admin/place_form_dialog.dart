import 'package:flutter/material.dart';
import 'package:gather_club/api_services/place_serice/place.dart';
import 'package:gather_club/theme/app_theme.dart';

class PlaceFormDialog extends StatefulWidget {
  final Place? place;
  final Function(Map<String, dynamic>) onSave;

  const PlaceFormDialog({
    Key? key,
    this.place,
    required this.onSave,
  }) : super(key: key);

  @override
  State<PlaceFormDialog> createState() => _PlaceFormDialogState();
}

class _PlaceFormDialogState extends State<PlaceFormDialog> {
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
      final placeData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'latitude': double.parse(_latitudeController.text),
        'longitude': double.parse(_longitudeController.text),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.place == null ? 'Создать место' : 'Редактировать место',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Название *',
                          hintText: 'Введите название места',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Пожалуйста, введите название';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                          hintText: 'Введите описание места',
                        ),
                        maxLines: 3,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latitudeController,
                              decoration: const InputDecoration(
                                labelText: 'Широта *',
                                hintText: 'Например: 55.7558',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Введите широту';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Введите корректное число';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _longitudeController,
                              decoration: const InputDecoration(
                                labelText: 'Долгота *',
                                hintText: 'Например: 37.6173',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Введите долготу';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Введите корректное число';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Адрес',
                          hintText: 'Введите адрес места',
                        ),
                      ),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Телефон',
                          hintText: 'Введите телефон места',
                        ),
                      ),
                      TextFormField(
                        controller: _workingHoursController,
                        decoration: const InputDecoration(
                          labelText: 'Часы работы',
                          hintText: 'Например: Пн-Пт: 9:00-18:00',
                        ),
                      ),
                      TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Категория',
                          hintText: 'Например: Ресторан, Кафе, Парк',
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
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100,
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(Icons.error, size: 50),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.delete),
                              label: const Text('Удалить изображение'),
                              onPressed: () {
                                setState(() {
                                  _imageUrl = null;
                                });
                              },
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      TextButton.icon(
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
                                          hintText: 'Введите URL изображения',
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: const Text('Отмена'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                _imageUrl =
                                                    controller.text.isNotEmpty
                                                        ? controller.text
                                                        : null;
                                              });
                                              Navigator.of(context).pop();
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.accentColor,
                                            ),
                                            child: const Text('Сохранить'),
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                  ),
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
