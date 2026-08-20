// lib/shop/sell_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/tajikshop_brand.dart';
import 'shop_repository.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});
  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _repo = ShopRepository();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _caption = TextEditingController();
  final _address = TextEditingController();
  final _whatsapp = TextEditingController();
  final _phone = TextEditingController();
  String _currency = 'TJS';
  File? _image;
  double _lat = 0, _lng = 0;
  bool _gpsOn = false, _publishing = false;
  bool _raonson = true; // харидор ба чати Raonson дарояд

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _caption.dispose();
    _address.dispose();
    _whatsapp.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1440, imageQuality: 82);
    if (x != null) setState(() => _image = File(x.path));
  }

  Future<void> _captureGps() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Иҷозати ҷойгиршавӣ дода нашуд')));
      }
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 12));
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _gpsOn = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _publish() async {
    if (_publishing) return;
    if (_image == null) {
      _snack('Расми маҳсулотро интихоб кунед');
      return;
    }
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.')) ?? 0;
    if (_name.text.trim().isEmpty || price <= 0) {
      _snack('Ном ва нархро дуруст нависед');
      return;
    }
    setState(() => _publishing = true);
    final ok = await _repo.createProduct(
      image: _image!,
      productName: _name.text.trim(),
      price: price,
      currency: _currency,
      caption: _caption.text.trim(),
      shopLat: _lat,
      shopLng: _lng,
      shopAddress: _address.text.trim(),
      contactRaonson: _raonson,
      whatsapp: _whatsapp.text.trim(),
      phone: _phone.text.trim(),
    );
    if (!mounted) return;
    setState(() => _publishing = false);
    if (ok) {
      _snack('Маҳсулот эълон шуд ✓');
      Navigator.pop(context);
    } else {
      _snack('Эълон нашуд');
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          TajikshopBrand.logoCompact(size: 15),
          Text(' — Эълон',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        ]),
        actions: [
          TextButton(
            onPressed: _publishing ? null : _publish,
            child: _publishing
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Эълон',
                    style: TextStyle(
                        color: AppColors.neonBlue,
                        fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Image
        GestureDetector(
          onTap: _pick,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              image: _image != null
                  ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover)
                  : null,
            ),
            child: _image == null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(AppIcons.add_a_photo_rounded,
                        color: AppColors.textFaint, size: 40),
                    const SizedBox(height: 8),
                    Text('Расми маҳсулот',
                        style: TextStyle(color: AppColors.textFaint)),
                  ]))
                : null,
          ),
        ),
        const SizedBox(height: 16),
        _field(_name, 'Номи маҳсулот'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(flex: 2, child: _field(_price, 'Нарх',
              keyboard: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12)),
              child: DropdownButton<String>(
                value: _currency,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: AppColors.surface,
                style: TextStyle(color: AppColors.textPrimary),
                items: const ['TJS', 'USD', 'RUB']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _currency = v ?? 'TJS'),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _field(_caption, 'Тавсиф (ихтиёрӣ)', maxLines: 3),
        const SizedBox(height: 12),
        _field(_address, 'Суроғаи магоза (ихтиёрӣ)'),
        const SizedBox(height: 12),
        // GPS
        InkWell(
          onTap: _captureGps,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(AppIcons.location_on,
                  color: _gpsOn ? Colors.green : AppColors.neonBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    _gpsOn
                        ? 'Ҷойгиршавии магоза сабт шуд ✓'
                        : 'GPS-и магозаро сабт кун (то харидор ёбад)',
                    style: TextStyle(color: AppColors.textPrimary)),
              ),
              if (_gpsOn)
                Icon(AppIcons.check_circle_rounded, color: Colors.green),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Text('Харидор чӣ тавр бо шумо алоқа кунад?',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12)),
          child: SwitchListTile(
            value: _raonson,
            onChanged: (v) => setState(() => _raonson = v),
            activeColor: AppColors.neonBlue,
            title: Text('Чати Raonson',
                style: TextStyle(color: AppColors.textPrimary)),
            secondary: Icon(AppIcons.chat_bubble_rounded,
                color: AppColors.neonBlue),
          ),
        ),
        const SizedBox(height: 10),
        _field(_whatsapp, 'WhatsApp (мас. 992900000000)',
            keyboard: TextInputType.phone),
        const SizedBox(height: 10),
        _field(_phone, 'Рақами телефон (ихтиёрӣ)',
            keyboard: TextInputType.phone),
        const SizedBox(height: 8),
        Text('Метавонед ҳар се роҳро монед — харидор худаш интихоб мекунад.\n'
            'Комиссияи платформа: 5% аз ҳар фуруш.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
      ]),
    );
  }

  Widget _field(TextEditingController c, String hint,
      {int maxLines = 1, TextInputType? keyboard}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textFaint),
        filled: true, fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }
}
