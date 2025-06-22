import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gather_club/api_services/admin_service.dart';
import 'package:gather_club/api_services/place_serice/place.dart';
import 'package:gather_club/theme/app_theme.dart';
import 'package:gather_club/widgets/custom_notification.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gather_club/pages/Example.dart';
import 'package:gather_club/api_services/auth_service/auth_provider.dart';
import 'package:provider/provider.dart';

class PlaceFormPage extends StatefulWidget {
  final Place? place;
  final Function(Map<String, dynamic>) onSave;
  final AdminService adminService;

  const PlaceFormPage({
    Key? key,
    this.place,
    required this.onSave,
    required this.adminService,
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
  int? _selectedCategoryId;
  String? _imageUrl;
  File? _imageFile;
  bool _isUploading = false;
  List<PlaceCategory> _categories = [];
  bool _isLoadingCategories = false;

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
      _selectedCategoryId = widget.place!.categoryId;
      _imageUrl = widget.place!.imageUrl;
    }
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoadingCategories = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final categoryService = PlaceCategoryService(authProvider);
      final categories = await categoryService.getAllCategories();

      setState(() {
        _categories = categories
            .where((c) => c.id != 0)
            .toList(); // Исключаем категорию "Все"
        _isLoadingCategories = false;
      });
    } catch (e) {
      print('Ошибка при загрузке категорий: $e');
      setState(() => _isLoadingCategories = false);

      // Устанавливаем базовые категории в случае ошибки
      _categories = [
        PlaceCategory(id: 1, name: 'Кафе', iconUrl: null, isActive: true),
        PlaceCategory(id: 2, name: 'Рестораны', iconUrl: null, isActive: true),
        PlaceCategory(id: 3, name: 'Парки', iconUrl: null, isActive: true),
        PlaceCategory(id: 4, name: 'Музеи', iconUrl: null, isActive: true),
        PlaceCategory(id: 5, name: 'Кинотеатры', iconUrl: null, isActive: true),
        PlaceCategory(id: 6, name: 'Спорт', iconUrl: null, isActive: true),
        PlaceCategory(id: 7, name: 'Магазины', iconUrl: null, isActive: true),
        PlaceCategory(id: 8, name: 'Отели', iconUrl: null, isActive: true),
        PlaceCategory(
            id: 9, name: 'Образование', iconUrl: null, isActive: true),
      ];

      CustomNotification.show(context, 'Ошибка при загрузке категорий');
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
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      CustomNotification.show(context, 'Ошибка при выборе изображения: $e');
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null || widget.place == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final updatedPlace = await widget.adminService.updatePlaceImage(
        widget.place!.placeId,
        _imageFile!,
      );

      setState(() {
        _imageUrl = updatedPlace.imageUrl;
        _imageFile = null;
        _isUploading = false;
      });

      CustomNotification.show(context, 'Изображение успешно загружено');
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      CustomNotification.show(context, 'Ошибка при загрузке изображения: $e');
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

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
          'categoryId': _selectedCategoryId,
        };

        if (_imageUrl != null && _imageUrl!.isNotEmpty) {
          placeData['imageUrl'] = _imageUrl!;
        }

        // Если это создание нового места и есть выбранное изображение
        if (widget.place == null && _imageFile != null) {
          // Сначала создаем место
          final createdPlace = await widget.adminService.createPlace(placeData);

          // Затем загружаем изображение для созданного места
          final updatedPlace = await widget.adminService.updatePlaceImage(
            createdPlace.placeId,
            _imageFile!,
          );

          // Вызываем колбэк с обновленными данными
          widget.onSave({
            ...placeData,
            'placeId': updatedPlace.placeId,
            'imageUrl': updatedPlace.imageUrl,
          });

          Navigator.of(context).pop();
          CustomNotification.show(context, 'Место создано с изображением');
        }
        // Если это редактирование и есть новое изображение
        else if (widget.place != null && _imageFile != null) {
          // Сначала обновляем данные места
          await widget.adminService
              .updatePlace(widget.place!.placeId, placeData);

          // Затем загружаем новое изображение
          final updatedPlace = await widget.adminService.updatePlaceImage(
            widget.place!.placeId,
            _imageFile!,
          );

          // Вызываем колбэк с обновленными данными
          widget.onSave({
            ...placeData,
            'placeId': widget.place!.placeId,
            'imageUrl': updatedPlace.imageUrl,
          });

          Navigator.of(context).pop();
          CustomNotification.show(
              context, 'Место обновлено с новым изображением');
        }
        // Если нет нового изображения, просто сохраняем данные
        else {
          widget.onSave(placeData);
          Navigator.of(context).pop();
          CustomNotification.show(context, 'Данные сохранены');
        }
      } catch (e) {
        CustomNotification.show(context, 'Ошибка при сохранении: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
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
                        _isLoadingCategories
                            ? const Center(child: CircularProgressIndicator())
                            : DropdownButtonFormField<int>(
                                value: _selectedCategoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Выберите категорию *',
                                  border: OutlineInputBorder(),
                                ),
                                items: _categories.map((category) {
                                  return DropdownMenuItem<int>(
                                    value: category.id,
                                    child: Row(
                                      children: [
                                        Icon(category.icon, size: 20),
                                        const SizedBox(width: 8),
                                        Text(category.name),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCategoryId = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Пожалуйста, выберите категорию';
                                  }
                                  return null;
                                },
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
                        if (_isUploading)
                          const Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 8),
                                Text('Загрузка изображения...'),
                              ],
                            ),
                          )
                        else if (_imageFile != null)
                          Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _imageFile!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Показываем кнопку загрузки только при редактировании существующего места
                                  if (widget.place != null)
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.upload),
                                      label: const Text('Загрузить'),
                                      onPressed: _uploadImage,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accentColor,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  if (widget.place != null)
                                    const SizedBox(width: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Удалить'),
                                    onPressed: () {
                                      setState(() {
                                        _imageFile = null;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else if (_imageUrl != null)
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
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Выбрать из галереи'),
                              onPressed: _pickImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
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
                      icon: _isUploading
                          ? Container(
                              width: 24,
                              height: 24,
                              padding: const EdgeInsets.all(2.0),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isUploading ? 'Сохранение...' : 'Сохранить'),
                      onPressed: _isUploading ? null : _submitForm,
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
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.of(context).pop(),
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
