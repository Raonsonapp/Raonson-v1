import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'story_editor.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/media_compressor.dart';
import '../upload/upload_manager.dart';

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
  Future<void> _pickFromGallery() async {
    final xf = await ImagePicker().pickMedia();
    if (xf == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final path    = xf.path.toLowerCase();
    final isVideo = path.endsWith('.mp4') || path.endsWith('.mov') ||
                    path.endsWith('.avi') || path.endsWith('.mkv');
    if (mounted) setState(() { _file = File(xf.path); _isVideo = isVideo; _error = null; });
  }

  Future<void> _publish(File capturedFile, String caption) async {
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
      });
      if (res.statusCode >= 400) throw Exception('Story хато ${res.statusCode}');
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
