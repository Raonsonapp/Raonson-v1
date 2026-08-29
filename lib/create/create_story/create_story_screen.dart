import 'dart:io';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import '../../core/ui/app_icons.dart';
import 'package:flutter/material.dart';
import 'story_editor.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/media_compressor.dart';
import '../../stories/story_repository.dart';
import '../upload/upload_manager.dart';
import '../../core/i18n/strings.dart';

class CreateStoryScreen extends StatefulWidget {
  final File? initialFile;
  final bool  initialIsVideo;
  const CreateStoryScreen({super.key, this.initialFile, this.initialIsVideo = false});
  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  File?  _file;
  bool   _isVideo    = false;
  bool   _isUploading= false;
  String?_error;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _file = widget.initialFile;
      _isVideo = widget.initialIsVideo;
    } else {
      // Рост ба Галереяи телефон — мисли Instagram
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickFromGallery());
    }
  }

  // ── Рост ба Галерея — бе савол, мисли Instagram ──────────────
  // Ба ҷои pickMedia(): он дар баъзе дастгоҳҳо танҳо расм бармегардонд,
  // бинобар ин видео барои сторис интихоб намешуд.
  Future<void> _pickFromGallery() async {
    final picked = await Navigator.push<_PickedMedia>(
      context,
      MaterialPageRoute(builder: (_) => const _StoryMediaPicker()),
    );
    if (picked == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (mounted) {
      setState(() {
        _file    = picked.file;
        _isVideo = picked.isVideo;
        _error   = null;
      });
    }
  }

  Future<void> _publish(File capturedFile, String caption, String audience,
      [Map<String, dynamic>? poll]) async {
    final token = ApiClient.instance.authToken ?? '';
    if (token.isEmpty) return;
    setState(() { _isUploading = true; _error = null; });
    try {
      // ── Фишурдани файл пеш аз бор кардан ─────────────────────
      // Расми ноом (5-10MB) → ~0.5MB, видеои ноом (30-50MB) → ~10-15MB.
      // Инро дар интернети суст 5-10 бор тезтар мекунад.
      File fileToUpload = capturedFile;
      if (_isVideo) {
        try {
          fileToUpload = await MediaCompressor.compressVideo(capturedFile);
        } catch (_) {/* фишурдан наомад — оригинал */}
      }
      // Расм худкор дар UploadManager._maybeCompressImage фишурда мешавад
      // (~72% сифат, ҳадди аксар 1080px).

      // Retry: агар upload дар як бор ноком шавад (интернети суст),
      // 2 маротибаи дигар кӯшиш мекунем.
      String? mediaUrl;
      Object? lastErr;
      for (int i = 0; i < 3; i++) {
        try {
          mediaUrl = await UploadManager().uploadFile(fileToUpload);
          if (mediaUrl.isNotEmpty) break;
        } catch (e) {
          lastErr = e;
          if (i < 2) await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      }
      if (mediaUrl == null || mediaUrl.isEmpty) {
        throw Exception(lastErr?.toString() ?? 'Upload ноком шуд');
      }

      // POST /stories/ ба backend — то 60с барои интернети суст
      final res = await ApiClient.instance.post('/stories/', body: {
        'mediaUrl' : mediaUrl,
        'mediaType': _isVideo ? 'video' : 'image',
        'caption'  : caption,
        // Пештар фиристода намешуд — «дӯстони наздик» ба ҳама мерафт.
        'audience' : audience,
        if (poll != null) 'poll': poll,
      });
      if (res.statusCode >= 400) throw Exception('Story хато ${res.statusCode}');
      // Story-и нав нашр шуд — cache-и disk-и story-ро пок мекунем, то дар
      // навбати оянда StoryRepository stori-и куҳнаро зикр накунад.
      // WebSocket "story:new" аллакай ба StoryController хабар медиҳад, ки
      // stori-и навро дар лаҳза илова кунад (мисли Instagram).
      await StoryRepository.clearAllCaches();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() { _isUploading = false; _error = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null) {
      return const Scaffold(backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white30, strokeWidth: 2)));
    }
    return StoryEditor(media: _file!, isVideo: _isVideo, isUploading: _isUploading,
      onPublish: _publish, onCancel: () => Navigator.pop(context), errorMessage: _error);
  }
}


// ── Интихоби медиа барои сторис (расм + видео) ───────────────────
class _PickedMedia {
  final File file;
  final bool isVideo;
  const _PickedMedia(this.file, this.isVideo);
}

class _StoryMediaPicker extends StatefulWidget {
  const _StoryMediaPicker();
  @override
  State<_StoryMediaPicker> createState() => _StoryMediaPickerState();
}

class _StoryMediaPickerState extends State<_StoryMediaPicker> {
  final List<AssetEntity> _assets = [];
  AssetPathEntity? _album;
  int  _page   = 0;
  bool _loading = true;
  bool _denied  = false;
  bool _hasMore = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      if (mounted) setState(() { _denied = true; _loading = false; });
      return;
    }
    final filter = FilterOptionGroup(
      imageOption: const FilterOption(needTitle: true),
      videoOption: const FilterOption(
        needTitle: true,
        durationConstraint: DurationConstraint(
          min: Duration.zero, max: Duration(hours: 6)),
      ),
      createTimeCond: DateTimeCond(
        min: DateTime.utc(1970), max: DateTime.utc(2100)),
      orders: const [
        OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );
    final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common, onlyAll: true, filterOption: filter);
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

  Future<void> _pick(AssetEntity a) async {
    final f = await a.file;
    if (f == null || !mounted) return;
    Navigator.pop(context, _PickedMedia(f, a.type == AssetType.video));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        title: Text(tr('ui.7a1a87cda7'),
            style: TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(AppIcons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      ),
      body: _denied
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(tr('ui.315f9b5aa3'),
                    style: TextStyle(color: Colors.white54)),
                TextButton(
                    onPressed: PhotoManager.openSetting,
                    child: Text(tr('ui.1ff449882a'),
                        style: TextStyle(color: Color(0xFF0095F6)))),
              ]))
          : _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
                      _loadPage();
                    }
                    return false;
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(2),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 2, crossAxisSpacing: 2),
                    itemCount: _assets.length,
                    itemBuilder: (_, i) {
                      final a = _assets[i];
                      return GestureDetector(
                        onTap: () => _pick(a),
                        child: Stack(fit: StackFit.expand, children: [
                          FutureBuilder<Uint8List?>(
                            future: a.thumbnailDataWithSize(
                                const ThumbnailSize(250, 250)),
                            builder: (_, s) => s.data == null
                                ? Container(color: Colors.white10)
                                : Image.memory(s.data!, fit: BoxFit.cover),
                          ),
                          if (a.type == AssetType.video)
                            const Positioned(
                              right: 4, bottom: 4,
                              child: Icon(AppIcons.play_arrow_rounded,
                                  color: Colors.white, size: 18),
                            ),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}
