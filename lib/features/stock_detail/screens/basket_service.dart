import 'package:flutter/material.dart';

class BasketItem {
  final String stockId;
  final String symbol;
  final String companyName;
  int quantity;
  double price;

  BasketItem({
    required this.stockId,
    required this.symbol,
    required this.companyName,
    required this.quantity,
    required this.price,
  });
}

class Basket {
  final String id;
  String name;
  final List<BasketItem> items;
  final DateTime createdAt;

  Basket({required this.id, required this.name, required this.items, required this.createdAt});

  double get totalValue => items.fold(0, (sum, i) => sum + i.quantity * i.price);
}

class BasketService extends ChangeNotifier {
  static final BasketService _instance = BasketService._internal();
  factory BasketService() => _instance;
  BasketService._internal();

  final List<Basket> _baskets = [];
  List<Basket> get baskets => List.unmodifiable(_baskets);

  void createBasket(String name) {
    _baskets.add(Basket(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      items: [],
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void addToBasket(String basketId, BasketItem item) {
    final basket = _baskets.firstWhere((b) => b.id == basketId, orElse: () => throw Exception('Basket not found'));
    final existing = basket.items.where((i) => i.symbol == item.symbol).toList();
    if (existing.isNotEmpty) {
      existing.first.quantity += item.quantity;
    } else {
      basket.items.add(item);
    }
    notifyListeners();
  }

  void removeFromBasket(String basketId, String symbol) {
    final basket = _baskets.firstWhere((b) => b.id == basketId, orElse: () => throw Exception('not found'));
    basket.items.removeWhere((i) => i.symbol == symbol);
    notifyListeners();
  }

  void deleteBasket(String basketId) {
    _baskets.removeWhere((b) => b.id == basketId);
    notifyListeners();
  }
}