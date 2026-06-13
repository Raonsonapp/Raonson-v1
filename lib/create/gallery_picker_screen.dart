// lib/create/gallery_picker_screen.dart
// Интихоби медиа мисли Instagram — галереяи дохилӣ (на file picker-и система)
// бо tab-ҳои поён: Публикатсия | Сторис | Reels.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'create_post/create_post_screen.dart';
import 'create_reel/create_reel_screen.dart';
import 'create_story/create_story_screen.dart';

enum CreateMode { post, story, reel }

class GalleryPickerScreen extends StatefulWidget {
  final CreateMode initialMode;
  const GalleryPickerScreen({super.key, this.initialMode = CreateMode.post});
  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  late CreateMode _mode = widget.initialMode;
  final List<AssetEntity> _assets = [];
  bool _loading = true;
  bool _denied = false;
  AssetPathEntity? _album;
  int _page = 0;
  bool _hasMore = true;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  Future<void> _load() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      if (mounted) setState(() { _denied = true; _loading = false; });
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // расм + видео
      onlyAll: true,
    );
    if (albums.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _album = albums.first;
    await _loadPage();
  }

  Future<void> _loadPage() async {
    if (_album == null || !_hasMore) return;
    final batch = await _album!.getAssetListPaged(page: _page, size: 80);
    if (!mounted) return;
    setState(() {
      _assets.addAll(batch);
      _page++;
      _hasMore = batch.length == 80;
      _loading = false;
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      _loadPage();
    }
  }

  Future<void> _onPick(AssetEntity a) async {
    final file = await a.file;
    if (file == null || !mounted) return;
    final isVideo = a.type == AssetType.video;
    Widget editor;
    switch (_mode) {
      case CreateMode.post:
        editor = CreatePostScreen(initialFile: file, initialIsVideo: isVideo);
        break;
      case CreateMode.story:
        editor = CreateStoryScreen(initialFile: file, initialIsVideo: isVideo);
        break;
      case CreateMode.reel:
        editor = CreateReelScreen(initialFile: file);
        break;
    }
    final r = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => editor));
    if (r == true && mounted) Navigator.pop(context, true);
  }

  String get _title => switch (_mode) {
        CreateMode.post => 'Пости нав',
        CreateMode.story => 'Сторис',
        CreateMode.reel => 'Reel',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        centerTitle: true,
        title: Text(_title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: Column(children: [
        Expanded(child: _buildGrid()),
        _buildModeBar(),
      ]),
    );
  }

  Widget _buildGrid() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white30, strokeWidth: 2));
    }
    if (_denied) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_library_outlined,
              color: Colors.white30, size: 48),
          const SizedBox(height: 14),
          const Text('Барои нишон додани галерея иҷозат лозим аст',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => PhotoManager.openSetting(),
            child: const Text('Кушодани танзимот',
                style: TextStyle(color: Color(0xFF0095F6))),
          ),
        ]),
      );
    }
    if (_assets.isEmpty) {
      return const Center(
          child: Text('Расм нест', style: TextStyle(color: Colors.white38)));
    }
    return GridView.builder(
      controller: _scroll,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: _assets.length,
      itemBuilder: (_, i) =>
          _AssetTile(asset: _assets[i], onTap: () => _onPick(_assets[i])),
    );
  }

  Widget _buildModeBar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _modeTab('Публикатсия', CreateMode.post),
            _modeTab('Сторис', CreateMode.story),
            _modeTab('Reels', CreateMode.reel),
          ],
        ),
      ),
    );
  }

  Widget _modeTab(String label, CreateMode m) {
    final sel = _mode == m;
    return GestureDetector(
      onTap: () => setState(() => _mode = m),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : Colors.white38,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15)),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final AssetEntity asset;
  final VoidCallback onTap;
  const _AssetTile({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(fit: StackFit.expand, children: [
        FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(const ThumbnailSize(250, 250)),
          builder: (_, snap) => snap.data != null
              ? Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true)
              : Container(color: const Color(0xFF111111)),
        ),
        if (asset.type == AssetType.video)
          Positioned(
            right: 4, bottom: 4,
            child: Row(children: [
              const Icon(Icons.play_circle_fill, color: Colors.white, size: 16),
              const SizedBox(width: 2),
              Text(_dur(asset.videoDuration),
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ]),
          ),
      ]),
    );
  }

  String _dur(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
