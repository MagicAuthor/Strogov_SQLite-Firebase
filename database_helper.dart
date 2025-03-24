import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE,
      password TEXT,
      firstname TEXT,
      lastname TEXT
    )
  ''');

    await db.execute('''
    CREATE TABLE orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_email TEXT,
      address TEXT,
      created_at TEXT,
      total_amount REAL
    )
  ''');

    await db.execute('''
    CREATE TABLE services (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      price REAL NOT NULL
    )
  ''');

    await db.execute('''
    CREATE TABLE order_services (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER,
      service_id INTEGER,
      FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE,
      FOREIGN KEY(service_id) REFERENCES services(id) ON DELETE CASCADE
    )
  ''');
  }

  // Регистрация пользователя
  Future<int> registerUser(String email, String password, String firstname, String lastname) async {
    final db = await instance.database;
    final id = await db.insert('users', {
      'email': email,
      'password': password,
      'firstname': firstname,
      'lastname': lastname
    });

    try {
      // Сохранение в Firebase
      await _firestore.collection('users').doc(email).set({
        'email': email,
        'password': password,
        'firstname': firstname,
        'lastname': lastname
      });
      print("Данные успешно записаны в Firebase!");
    } catch (e) {
      print("Ошибка записи в Firebase: $e");
    }

    return id;
  }

  // Получение пользователя
  Future<Map<String, dynamic>?> getUser(String email, String password) async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Получение заказов пользователя
  Future<List<Map<String, dynamic>>> getOrders(String userEmail) async {
    final db = await instance.database;
    final orders = await db.query(
      'orders',
      where: 'user_email = ?',
      whereArgs: [userEmail],
      orderBy: 'created_at DESC',
    );

    List<Map<String, dynamic>> ordersList = orders.map((order) => Map<String, dynamic>.from(order)).toList();

    for (var order in ordersList) {
      final orderId = order['id'];
      final services = await db.query(
        'order_services',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      order['services'] = services.map((s) => s['service_id']).toList();
    }

    return ordersList;
  }

  // Добавление заказа
  Future<int> insertOrder(String userEmail, String address, List<int> serviceIds, double totalAmount) async {
    final db = await instance.database;
    final orderId = await db.insert('orders', {
      'user_email': userEmail,
      'address': address,
      'created_at': DateTime.now().toIso8601String(),
      'total_amount': totalAmount,
    });

    for (var serviceId in serviceIds) {
      await db.insert('order_services', {
        'order_id': orderId,
        'service_id': serviceId,
      });
    }

    // Сохранение в Firebase
    await _firestore.collection('orders').doc(orderId.toString()).set({
      'user_email': userEmail,
      'address': address,
      'created_at': DateTime.now().toIso8601String(),
      'total_amount': totalAmount,
      'services': serviceIds
    });

    return orderId;
  }

  // Удаление заказа
  Future<int> deleteOrder(int orderId) async {
    final db = await instance.database;
    await db.delete('order_services', where: 'order_id = ?', whereArgs: [orderId]);
    final result = await db.delete('orders', where: 'id = ?', whereArgs: [orderId]);

    // Удаление из Firebase
    await _firestore.collection('orders').doc(orderId.toString()).delete();

    return result;
  }

  // Обновление заказа
  Future<int> updateOrder(int orderId, String address, List<int> serviceIds, double totalAmount) async {
    final db = await instance.database;

    await db.update(
      'orders',
      {'address': address, 'total_amount': totalAmount},
      where: 'id = ?',
      whereArgs: [orderId],
    );

    await db.delete('order_services', where: 'order_id = ?', whereArgs: [orderId]);

    for (var serviceId in serviceIds) {
      await db.insert('order_services', {'order_id': orderId, 'service_id': serviceId});
    }

    // Обновление в Firebase
    await _firestore.collection('orders').doc(orderId.toString()).update({
      'address': address,
      'total_amount': totalAmount,
      'services': serviceIds
    });

    return orderId;
  }

  // Получение всех услуг
  Future<List<Map<String, dynamic>>> getServices() async {
    final db = await database;
    return await db.query('services');
  }

  // Добавление услуги
  Future<int> insertService(String name, double price) async {
    final db = await database;
    final id = await db.insert(
      'services',
      {'name': name, 'price': price},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Сохранение в Firebase
    await _firestore.collection('services').doc(id.toString()).set({
      'name': name,
      'price': price,
    });

    return id;
  }

  // Удаление услуги
  Future<int> deleteService(int id) async {
    final db = await database;
    final result = await db.delete('services', where: 'id = ?', whereArgs: [id]);

    // Удаление из Firebase
    await _firestore.collection('services').doc(id.toString()).delete();

    return result;
  }

  // Синхронизация услуг между SQLite и Firebase
  Future<void> syncServices() async {
    final db = await database;

    // Получаем услуги из Firebase
    final firebaseServices = await _firestore.collection('services').get();
    final firebaseList = firebaseServices.docs
        .map((doc) => {
      'id': int.tryParse(doc.id) ?? 0,
      'name': doc['name'],
      'price': (doc['price'] as num).toDouble(),
    })
        .toList();

    // Получаем услуги из SQLite
    final localServices = await getServices();

    // Сравнение данных
    final firebaseSet = firebaseList.map((s) => s['id']).toSet();
    final localSet = localServices.map((s) => s['id']).toSet();

    // Добавляем в SQLite отсутствующие услуги
    for (var service in firebaseList) {
      if (!localSet.contains(service['id'])) {
        await db.insert('services', {
          'id': service['id'],
          'name': service['name'],
          'price': service['price'],
        });
      }
    }

    // Добавляем в Firebase отсутствующие услуги
    for (var service in localServices) {
      if (!firebaseSet.contains(service['id'])) {
        await _firestore.collection('services').doc(service['id'].toString()).set({
          'name': service['name'],
          'price': service['price'],
        });
      }
    }
  }
}
