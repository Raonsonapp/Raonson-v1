// lib/effects/create_effect_screen.dart
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import 'effects_repository.dart';

class CreateEffectScreen extends StatefulWidget {
  const CreateEffectScreen({super.key});
  @override
  State<CreateEffectScreen> createState() => _CreateEffectScreenState();
}

class _CreateEffectScreenState extends State<CreateEffectScreen> {
  final _repo = EffectsRepository();
  final _name = TextEditingController();
  final _price = TextEditingController();
  double _bright = 0, _contrast = 1.0, _warm = 0, _sat = 1.0;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  List<double> _matrix() {
    const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
    final sa = _sat;
    final sr = (1 - sa) * lumR, sg = (1 - sa) * lumG, sb = (1 - sa) * lumB;
    final co = _contrast;
    final coOff = 128 * (1 - co);
    final br = _bright, wa = _warm;
    return [
      (sr + sa) * co, sg * co, sb * co, 0, coOff + br + wa,
      sr * co, (sg + sa) * co, sb * co, 0, coOff + br,
      sr * co, sg * co, (sb + sa) * co, 0, coOff + br - wa,
      0, 0, 0, 1, 0,
    ];
  }

  Future<void> _publish() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      _snack('Номи эффектро нависед');
      return;
    }
    setState(() => _saving = true);
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.')) ?? 0;
    final ok = await _repo.createEffect(_name.text.trim(), _matrix(), price);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _snack('Эффект нашр шуд ✓');
      Navigator.pop(context);
    } else {
      _snack('Нашр нашуд — эҳтимол галочка надоред');
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Сохтани эффект',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _publish,
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Нашр',
                    style: TextStyle(
                        color: AppColors.neonBlue,
                        fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Live preview
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(_matrix()),
            child: Container(
              height: 200,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF6B6B), Color(0xFFFECA57),
                    Color(0xFF48DBFB), Color(0xFF1DD1A1),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _slider('Равшанӣ', _bright, -60, 60, (v) => setState(() => _bright = v)),
        _slider('Контраст', _contrast, 0.6, 1.6, (v) => setState(() => _contrast = v)),
        _slider('Гармӣ', _warm, -40, 40, (v) => setState(() => _warm = v)),
        _slider('Сершавӣ', _sat, 0, 2, (v) => setState(() => _sat = v)),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Номи эффект',
            hintStyle: TextStyle(color: AppColors.textFaint),
            filled: true, fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Нарх (0 = ройгон)',
            hintStyle: TextStyle(color: AppColors.textFaint),
            filled: true, fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        Text('Танҳо корбарони галочкадор эффект нашр карда метавонанд. '
            'Аз ҳар фуруши эффект комиссияи 5% ба платформа меравад.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
      ]),
    );
  }

  Widget _slider(String label, double val, double min, double max,
      ValueChanged<double> onCh) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      Slider(
        value: val, min: min, max: max,
        activeColor: AppColors.neonBlue,
        onChanged: onCh,
      ),
    ]);
  }
}
