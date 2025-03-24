import 'package:flutter/material.dart';
import 'package:pattern_3/database_helper.dart';

class Orders extends StatefulWidget {
  final String userEmail;

  const Orders({super.key, required this.userEmail});

  @override
  State<Orders> createState() => _OrdersState();
}

class _OrdersState extends State<Orders> {
  final TextEditingController _orderController = TextEditingController();
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> services = [];
  List<int> selectedServiceIds = [];
  double totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadServices();
  }

  Future<void> _loadOrders() async {
    final dbOrders = await DatabaseHelper.instance.getOrders(widget.userEmail);
    setState(() {
      orders = dbOrders;
    });
  }

  Future<void> _loadServices() async {
    final dbServices = await DatabaseHelper.instance.getServices();
    setState(() {
      services = dbServices;
    });
  }

  void _calculateTotal() {
    totalAmount = selectedServiceIds.fold(0.0, (sum, id) {
      final service = services.firstWhere(
            (s) => s['id'] == id,
        orElse: () => {'price': 0.0},
      );
      return sum + (service['price'] as double);
    });
  }

  Future<void> _addOrder(String address) async {
    if (address.trim().isEmpty || selectedServiceIds.isEmpty) return;

    await DatabaseHelper.instance.insertOrder(
      widget.userEmail,
      address,
      selectedServiceIds,
      totalAmount,
    );

    _orderController.clear();
    selectedServiceIds = [];
    await _loadOrders();
  }

  Future<void> _deleteOrder(int id) async {
    await DatabaseHelper.instance.deleteOrder(id);
    await _loadOrders();
  }

  void _showOrderDialog({int? id, String? currentAddress, List<int>? currentServiceIds}) {
    _orderController.text = currentAddress ?? '';
    selectedServiceIds = List<int>.from(currentServiceIds ?? []);
    _calculateTotal();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(id == null ? 'Добавить заказ' : 'Редактировать заказ'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Выберите услуги", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...services.map((service) {
                    return CheckboxListTile(
                      title: Text("${service['name']} - ${service['price']} руб."),
                      value: selectedServiceIds.contains(service['id']),
                      onChanged: (bool? selected) {
                        setState(() {
                          if (selected == true) {
                            selectedServiceIds.add(service['id']);
                          } else {
                            selectedServiceIds.remove(service['id']);
                          }
                          _calculateTotal();
                        });
                      },
                    );
                  }).toList(),
                  TextField(
                    controller: _orderController,
                    decoration: const InputDecoration(labelText: 'Адрес заказа'),
                  ),
                  const SizedBox(height: 10),
                  Text("Итоговая сумма: $totalAmount руб.", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () async {
                  if (id == null) {
                    await _addOrder(_orderController.text);
                  } else {
                    await DatabaseHelper.instance.updateOrder(
                      id,
                      _orderController.text,
                      selectedServiceIds,
                      totalAmount,
                    );
                    await _loadOrders();
                  }
                  Navigator.pop(context);
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои заказы')),
      body: orders.isEmpty
          ? const Center(child: Text('Нет заказов'))
          : ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final orderDate = order['created_at'] != null
              ? DateTime.tryParse(order['created_at'])
              : null;
          final formattedDate = orderDate != null
              ? "${orderDate.day}.${orderDate.month}.${orderDate.year}"
              : "Неизвестно";

          final List<int> serviceIds = (order['services'] is String)
              ? (order['services'] as String)
              .split(',')
              .map((id) => int.tryParse(id) ?? 0)
              .where((id) => id > 0)
              .toList()
              : (order['services'] is List)
              ? (order['services'] as List)
              .map((id) => id is int ? id : int.tryParse(id.toString()) ?? 0)
              .where((id) => id > 0)
              .toList()
              : [];

          final orderServices = serviceIds
              .map((id) => services.firstWhere(
                (s) => s['id'] == id,
            orElse: () => {'name': 'Неизвестная услуга'},
          )['name'])
              .join(', ');

          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text("Заказ от $formattedDate"),
              subtitle: Text(
                "Адрес: ${order['address']}\n"
                    "Услуги: $orderServices\n"
                    "Сумма: ${order['total_amount']} руб.",
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      _showOrderDialog(
                        id: order['id'],
                        currentAddress: order['address'],
                        currentServiceIds: serviceIds,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteOrder(order['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showOrderDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
