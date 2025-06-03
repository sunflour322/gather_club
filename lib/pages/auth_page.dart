import 'package:flutter/material.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/theme/app_theme.dart';
import 'package:provider/provider.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      setState(() {
        _isEmailFocused = _emailFocusNode.hasFocus;
      });
    });
    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Картинка авторизации
              Image.asset(
                'assets/logo.png', // Убедитесь, что добавили изображение в папку assets
                height: 150,
                width: 150,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.account_circle, size: 150),
              ),
              const SizedBox(height: 40),

              // Поле ввода логина
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.grey[200],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите имя или почту';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      icon: const Icon(Icons.email, color: Colors.grey),
                      hintText:
                          _isEmailFocused || _emailController.text.isNotEmpty
                              ? null
                              : 'Почта/Имя',
                      hintStyle: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Поле ввода пароля
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.grey[200],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите пароль';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      icon: const Icon(Icons.lock, color: Colors.grey),
                      hintText: _isPasswordFocused ||
                              _passwordController.text.isNotEmpty
                          ? null
                          : 'Пароль',
                      hintStyle: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
              if (authProvider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    authProvider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 30),

              // Кнопка входа
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: authProvider.isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            final success = await authProvider.login(
                              _emailController.text,
                              _passwordController.text,
                            );
                            if (success && mounted) {
                              Navigator.pushReplacementNamed(context, '/home');
                            }
                          }
                        },
                  child: authProvider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Войти',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Текстовая кнопка "Зарегистрироваться"
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text(
                  'Зарегистрироваться',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
