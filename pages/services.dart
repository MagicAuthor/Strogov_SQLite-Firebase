import 'package:flutter/material.dart';
import 'package:pattern_3/database_helper.dart';

class Services extends StatefulWidget {
  const Services({super.key});

  @override
  State<Services> createState() => _ServicesState();
}

class _ServicesState extends State<Services> {
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _servicePriceController = TextEditingController();
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  // Загрузка списка услуг из базы данных и Firebase
  Future<void> _loadServices() async {
    final services = await DatabaseHelper.instance.getServices();
    setState(() {
      _services = services;
    });

    // Синхронизация с Firebase
    await DatabaseHelper.instance.syncServices();
    final updatedServices = await DatabaseHelper.instance.getServices();
    setState(() {
      _services = updatedServices;
    });
  }

  // Добавление новой услуги в SQLite и Firebase
  Future<void> _addService(String name, double price) async {
    if (name.trim().isNotEmpty && price > 0) {
      await DatabaseHelper.instance.insertService(name, price);
      await DatabaseHelper.instance.syncServices(); // Обновляем Firebase
      _serviceNameController.clear();
      _servicePriceController.clear();
      _loadServices();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Название и цена услуги должны быть корректны")),
      );
    }
  }

  // Удаление услуги из SQLite и Firebase
  Future<void> _deleteService(int id) async {
    await DatabaseHelper.instance.deleteService(id);
    await DatabaseHelper.instance.syncServices(); // Синхронизация после удаления
    _loadServices();
  }

  // Диалог для добавления услуги
  void _showAddServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Добавить услугу"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _serviceNameController,
              decoration: const InputDecoration(
                labelText: "Название услуги",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _servicePriceController,
              decoration: const InputDecoration(
                labelText: "Цена услуги",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _serviceNameController.text;
              final price = double.tryParse(_servicePriceController.text) ?? 0;
              _addService(name, price);
              Navigator.of(context).pop();
            },
            child: const Text("Сохранить"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Услуги",
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black87, Colors.grey],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _services.isEmpty
            ? const Center(child: Text("Нет доступных услуг", style: TextStyle(color: Colors.white)))
            : ListView.builder(
          itemCount: _services.length,
          itemBuilder: (context, index) {
            final service = _services[index];
            return Card(
              margin: EdgeInsets.only(
                top: index == 0 ? 16.0 : 8.0,
                bottom: 8.0,
                left: 16.0,
                right: 16.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                title: Text(service['name'], style: const TextStyle(fontSize: 18)),
                subtitle: Text("Цена: ${service['price'].toStringAsFixed(2)} руб."),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteService(service['id']),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddServiceDialog,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    super.dispose();
  }
}
