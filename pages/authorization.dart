import 'package:flutter/material.dart';
import 'package:pattern_3/database_helper.dart';

class Authorization extends StatefulWidget {
  const Authorization({super.key});

  @override
  State<Authorization> createState() => _AuthorizationState();
}

class _AuthorizationState extends State<Authorization> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstnameController = TextEditingController();
  final _lastnameController = TextEditingController();
  bool _isLoading = false;

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        var user = await DatabaseHelper.instance.getUser(
          _emailController.text,
          _passwordController.text,
        );
        if (user != null) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/main_menu',
                (route) => false,
            arguments: _emailController.text, // Передаем email как аргумент
          );
        } else {
          _showErrorDialog('Неверные учетные данные');
        }
      } else {
        await DatabaseHelper.instance.registerUser(
          _emailController.text,
          _passwordController.text,
          _firstnameController.text,
          _lastnameController.text,
        );
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      _showErrorDialog('Ошибка: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Вход' : 'Регистрация'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (!_isLogin) ...[
                TextFormField(controller: _firstnameController, decoration: const InputDecoration(labelText: 'Имя')),
                TextFormField(controller: _lastnameController, decoration: const InputDecoration(labelText: 'Фамилия')),
              ],
              TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Пароль'), obscureText: true),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _submitForm,
                child: Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
              ),
              TextButton(
                onPressed: _toggleAuthMode,
                child: Text(_isLogin ? 'Нет аккаунта? Зарегистрироваться' : 'Уже есть аккаунт? Войти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
