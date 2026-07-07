// lib/shop/shop_repository.dart
import 'dart:convert';
import 'dart:io';
import '../core/api/api_client.dart';
import '../create/upload/upload_manager.dart';

class Product {
  final String id, productName, currency, shopAddress, caption, image;
  final double price, shopLat, shopLng;
  final bool inStock;
  final String sellerId, sellerName, sellerAvatar;
  final bool sellerVerified;
  final bool contactRaonson;
  final String whatsapp, phone;
  final bool featured;
  final int salePct;
  Product({
    required this.id, required this.productName, required this.currency,
    required this.shopAddress, required this.caption, required this.image,
    required this.price, required this.shopLat, required this.shopLng,
    required this.inStock, required this.sellerId, required this.sellerName,
    required this.sellerAvatar, required this.sellerVerified,
    this.contactRaonson = true, this.whatsapp = '', this.phone = '',
    this.featured = false, this.salePct = 0,
  });

  bool   get onSale     => salePct > 0;
  double get salePrice  => price * (1 - salePct / 100);
  String get salePriceLabel =>
      '${salePrice.toStringAsFixed(salePrice % 1 == 0 ? 0 : 2)} $currency';
  factory Product.fromJson(Map<String, dynamic> j) {
    final s = (j['seller'] ?? {}) as Map;
    return Product(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      productName: (j['productName'] ?? '').toString(),
      currency: (j['currency'] ?? 'TJS').toString(),
      shopAddress: (j['shopAddress'] ?? '').toString(),
      caption: (j['caption'] ?? '').toString(),
      image: (j['image'] ?? '').toString(),
      price: (j['price'] as num?)?.toDouble() ?? 0,
      shopLat: (j['shopLat'] as num?)?.toDouble() ?? 0,
      shopLng: (j['shopLng'] as num?)?.toDouble() ?? 0,
      inStock: j['inStock'] != false,
      sellerId: (s['_id'] ?? s['id'] ?? '').toString(),
      sellerName: (s['username'] ?? '').toString(),
      sellerAvatar: (s['avatar'] ?? '').toString(),
      sellerVerified: s['verified'] == true,
      contactRaonson: j['contactRaonson'] != false,
      whatsapp: (j['shopWhatsapp'] ?? '').toString(),
      phone: (j['shopPhone'] ?? '').toString(),
      featured: j['featured'] == true,
      salePct: (j['salePct'] as num?)?.toInt() ?? 0,
    );
  }

  Future<bool> setSale(String postId, int pct, int days) async {
    try {
      final r = await ApiClient.instance.put('/posts/$postId/sale',
          body: {'salePct': pct, 'saleDays': days});
      return r.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleFeature(String postId) async {
    try {
      final r = await ApiClient.instance.post('/posts/$postId/feature');
      if (r.statusCode >= 400) return false;
      return (jsonDecode(r.body)['featured'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> getTranslations(String postId) async {
    try {
      final r = await ApiClient.instance.get('/posts/$postId/translations');
      if (r.statusCode >= 400) return {};
      final t = (jsonDecode(r.body)['translations'] ?? {}) as Map;
      return t.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setTranslations(String postId, Map<String, String> t) async {
    try {
      await ApiClient.instance.put('/posts/$postId/translations', body: t);
    } catch (_) {}
  }

  Future<bool> updateProduct(String postId,
      {String? name, double? price, bool? inStock}) async {
    try {
      final r = await ApiClient.instance.put('/posts/$postId/product', body: {
        if (name != null) 'productName': name,
        if (price != null) 'price': price,
        if (inStock != null) 'inStock': inStock,
      });
      return r.statusCode < 400;
    } catch (_) {
      return false;
    }
  }
  String get priceLabel => '${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} $currency';
}

class ShopRepository {
  final _api = ApiClient.instance;

  Future<List<Product>> getProducts() async {
    try {
      final r = await _api.get('/shop');
      if (r.statusCode >= 400) return [];
      final body = jsonDecode(r.body);
      final list = (body['products'] ?? []) as List;
      return list
          .map((e) => Product.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> placeOrder(String postId, {String note = ''}) async {
    try {
      final r = await _api.post('/posts/$postId/order', body: {'note': note});
      return r.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  /// Маҳсулоти нав эълон мекунад (пости is_product).
  Future<bool> createProduct({
    required File image,
    required String productName,
    required double price,
    required String currency,
    required String caption,
    required double shopLat,
    required double shopLng,
    required String shopAddress,
    bool contactRaonson = true,
    String whatsapp = '',
    String phone = '',
  }) async {
    try {
      final url = await UploadManager().uploadFile(image);
      if (url.isEmpty) return false;
      final r = await _api.post('/posts/', body: {
        'caption': caption,
        'media': [
          {'url': url, 'type': 'image'}
        ],
        'isProduct': true,
        'price': price,
        'currency': currency,
        'productName': productName,
        'shopLat': shopLat,
        'shopLng': shopLng,
        'shopAddress': shopAddress,
        'contactRaonson': contactRaonson,
        'shopWhatsapp': whatsapp,
        'shopPhone': phone,
      });
      return r.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> myOrders() => _orders('/orders/');
  Future<List<Map<String, dynamic>>> sellingOrders() =>
      _orders('/orders/selling');

  Future<List<Map<String, dynamic>>> _orders(String path) async {
    try {
      final r = await _api.get(path);
      if (r.statusCode >= 400) return [];
      final body = jsonDecode(r.body);
      final list = (body['orders'] ?? []) as List;
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }
}
