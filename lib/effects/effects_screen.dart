// lib/effects/effects_screen.dart
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../widgets/avatar.dart';
import 'effects_repository.dart';
import 'create_effect_screen.dart';
import '../core/i18n/strings.dart';

class EffectsScreen extends StatefulWidget {
  const EffectsScreen({super.key});
  @override
  State<EffectsScreen> createState() => _EffectsScreenState();
}

class _EffectsScreenState extends State<EffectsScreen> {
  final _repo = EffectsRepository();
  List<EffectItem> _effects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await _repo.getEffects();
    if (!mounted) return;
    setState(() {
      _effects = e;
      _loading = false;
    });
  }

  Future<void> _use(EffectItem e) async {
    await _repo.useEffect(e.id);
    await _repo.saveLocally(e.name, e.matrix);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(e.isPremium
          ? 'Харидорӣ шуд ✓ — акнун дар филтрҳои пост ҳаст'
          : 'Илова шуд ✓ — акнун дар филтрҳои пост ҳаст'),
      backgroundColor: Colors.green,
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('ui.f8bb40968b'),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18,
                fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.neonBlue,
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CreateEffectScreen()));
          _load();
        },
        icon: Icon(AppIcons.add_rounded, color: AppColors.textPrimary),
        label: Text(tr('ui.b979a5a4c1'),
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _effects.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.bolt_rounded,
                      color: AppColors.textFaint, size: 56),
                  const SizedBox(height: 12),
                  Text(tr('ui.1774e9406b'),
                      style: TextStyle(color: AppColors.textFaint, fontSize: 15)),
                  Text(tr('ui.058eba1aae'),
                      style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 12,
                      crossAxisSpacing: 12, childAspectRatio: 0.82,
                    ),
                    itemCount: _effects.length,
                    itemBuilder: (_, i) => _card(_effects[i]),
                  ),
                ),
    );
  }

  Widget _card(EffectItem e) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Preview swatch — эффектро ба намунаи рангин татбиқ мекунем.
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(e.matrix),
            child: Container(
              height: 110,
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
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Row(children: [
              Avatar(imageUrl: e.creatorAvatar, size: 16, name: e.creatorName),
              const SizedBox(width: 4),
              Flexible(
                child: Text(e.creatorName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textFaint, fontSize: 10)),
              ),
              if (e.creatorVerified)
                const Icon(AppIcons.verified_rounded,
                    fill: 1, color: Color(0xFF00C853), size: 11),
            ]),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: e.isPremium
                      ? const Color(0xFFF1C40F)
                      : AppColors.neonBlue,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _use(e),
                child: Text(
                    e.isPremium
                        ? 'Харидан ${e.price.toStringAsFixed(0)}'
                        : 'Истифода',
                    style: TextStyle(
                        color: e.isPremium ? Colors.black : AppColors.textPrimary,
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
