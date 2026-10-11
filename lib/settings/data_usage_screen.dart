// lib/settings/data_usage_screen.dart
// Танзимот → Истифодаи маълумот: «Сарфаи трафик», кэши видео, Reels-и офлайн.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/services/data_saver.dart';
import '../core/ui/app_icons.dart';
import '../reels/offline/offline_reels.dart';
import '../reels/offline/offline_reels_screen.dart';
import '../reels/playback/playback_policy.dart';
import '../reels/playback/reel_playback.dart';

String dataSaverLabel(DataSaverMode m) => switch (m) {
      DataSaverMode.off => tr('data.off'),
      DataSaverMode.on => tr('data.on'),
      DataSaverMode.auto => tr('data.auto'),
    };

String _mb(int bytes) => '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';

class DataUsageScreen extends StatefulWidget {
  const DataUsageScreen({super.key});
  @override
  State<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends State<DataUsageScreen> {
  int? _cache;

  @override
  void initState() {
    super.initState();
    OfflineReels.instance.load();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final n = await ReelPlayback.cacheBytes();
    if (mounted) setState(() => _cache = n);
  }

  Widget _mode(DataSaverMode m, String sub) {
    final ds = DataSaver.instance;
    final sel = ds.mode == m;
    return ListTile(
      onTap: () => ds.setMode(m),
      leading: Icon(sel ? AppIcons.check_circle_rounded : AppIcons.radio_button_unchecked,
          color: sel ? AppColors.neonBlue : AppColors.textFaint),
      title: Text(dataSaverLabel(m), style: TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(sub, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(tr('data.title'), style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([DataSaver.instance, OfflineReels.instance]),
        builder: (ctx, _) => ListView(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(tr('data.saver'),
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          _mode(DataSaverMode.off, tr('data.offSub')),
          _mode(DataSaverMode.on, tr('data.onSub')),
          _mode(DataSaverMode.auto, tr('data.autoSub')),
          const Divider(),
          ListTile(
            leading: Icon(AppIcons.download_rounded, color: AppColors.textPrimary),
            title: Text(tr('offline.title'), style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text('${OfflineReels.instance.items.length} · ${_mb(OfflineReels.instance.totalBytes)}',
                style: TextStyle(color: AppColors.textSecondary)),
            onTap: () => Navigator.push(ctx,
                MaterialPageRoute(builder: (_) => const OfflineReelsScreen())),
          ),
          ListTile(
            leading: Icon(AppIcons.delete_outline_rounded, color: AppColors.textPrimary),
            title: Text(tr('data.clearCache'), style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(_cache == null ? '…' : _mb(_cache!),
                style: TextStyle(color: AppColors.textSecondary)),
            onTap: () async {
              await ReelPlayback.clearCache();
              await _loadCache();
            },
          ),
        ]),
      ),
    );
  }
}
