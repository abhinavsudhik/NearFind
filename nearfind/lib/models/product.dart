import 'package:cloud_firestore/cloud_firestore.dart';

class RetailerStock {
  final String retailerId;
  final String retailerName;
  final int price;
  final int stock;

  const RetailerStock({
    required this.retailerId,
    required this.retailerName,
    required this.price,
    required this.stock,
  });

  factory RetailerStock.fromMap(Map<String, dynamic> map) {
    return RetailerStock(
      retailerId: map['retailerId'] as String,
      retailerName: map['retailerName'] as String,
      price: (map['price'] as num).toInt(),
      stock: (map['stock'] as num).toInt(),
    );
  }
}

class Product {
  final String id;
  final String name;
  final List<RetailerStock> retailers;

  const Product({
    required this.id,
    required this.name,
    required this.retailers,
  });

  bool get isAvailableAnywhere => retailers.any((r) => r.stock > 0);

  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final retailerList = (data['retailers'] as List<dynamic>?)
            ?.map((e) => RetailerStock.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    return Product(
      id: doc.id,
      name: data['name'] as String,
      retailers: retailerList,
    );
  }
}
