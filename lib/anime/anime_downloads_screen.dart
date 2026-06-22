// lib/anime/anime_downloads_screen.dart
// Аниме зеркашшуда — тамошои офлайн (бе интернет, бе лаг).
import 'dart:io';
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import 'anime_player_screen.dart';
import 'download_service.dart';
import '../core/ui/app_icons.dart';

class AnimeDownloadsScreen extends StatefulWidget {
  const AnimeDownloadsScreen({super.key});
  @override
  State<AnimeDownloadsScreen> createState() => _AnimeDownloadsScreenState();
}

class _AnimeDownloadsScreenState extends State<AnimeDownloadsScreen> {
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await DownloadService.list();
    if (mounted) setState(() { _files = f; _loading = false; });
  }

  Future<void> _delete(File f) async {
    await DownloadService.delete(f);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        title: const Text('Зеркашшуда',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.neonBlue, strokeWidth: 2))
          : _files.isEmpty
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(AppIcons.download_done_rounded, color: Colors.white24, size: 48),
                    SizedBox(height: 12),
                    Text('Ҳанӯз чизе зеркашӣ нашудааст',
                        style: TextStyle(color: Colors.white38)),
                  ]),
                )
              : ListView.separated(
                  itemCount: _files.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (_, i) {
                    final f = _files[i];
                    final title = DownloadService.titleOf(f);
                    return ListTile(
                      leading: Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1C),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(AppIcons.play_circle_outline_rounded,
                            color: Colors.white70),
                      ),
                      title: Text(title,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                      trailing: IconButton(
                        icon: const Icon(AppIcons.delete_outline_rounded,
                            color: Colors.white38),
                        onPressed: () => _delete(f),
                      ),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => AnimePlayerScreen(
                            hash: '', title: title, localPath: f.path),
                      )),
                    );
                  },
                ),
    );
  }
}
