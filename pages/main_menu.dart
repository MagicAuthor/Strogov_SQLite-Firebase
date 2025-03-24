import 'package:flutter/material.dart';

class MainMenu extends StatelessWidget {
  final String userEmail;

  const MainMenu({super.key, required this.userEmail});

  // Список email администраторов
  static const List<String> adminEmails = [
    'admin@example.com',
    'the.author.of.magic@gmail.com',
  ];

  @override
  Widget build(BuildContext context) {
    // Проверяем, является ли пользователь администратором
    bool isAdmin = adminEmails.contains(userEmail);

    return Scaffold(
      appBar: AppBar(title: const Text('Заказы похоронный дом')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/orders', arguments: userEmail);
              },
              child: const Text('Заказы'),
            ),
            if (isAdmin) // Отображаем кнопку только для администраторов
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/services');
                },
                child: const Text('Управление услугами'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
              child: const Text('Выйти'),
            ),
          ],
        ),
      ),
    );
  }
}
