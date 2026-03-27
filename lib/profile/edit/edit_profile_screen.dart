import 'dart:io';
import '../../create/create_post/media_picker.dart';
import '../../create/upload/upload_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../app/app_theme.dart';
import '../../models/note_model.dart';
import '../../chat/inbox/music_picker_sheet.dart';
import 'edit_profile_controller.dart';

// ═══════════════════════════════════════════════════════════════════
//  EditProfileScreen — username + bio + bio мусиқӣ
// ═══════════════════════════════════════════════════════════════════
class EditProfileScreen extends StatefulWidget {
  final String userId;
  const EditProfileScreen({super.key, required this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final EditProfileController _ctrl;

  // Bio мусиқӣ
  SongInfo? _bioSong;
  bool      _loadingMusic  = false;
  File?     _localAvatar;        // корбар интихоб кардааст, ҳанӯз upload нашуд
  String?   _uploadedAvatarUrl;  // пас аз upload
  bool      _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _ctrl = EditProfileController();
    _ctrl.loadCurrentProfile(widget.userId);
    _ctrl.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Аватар интихоб + upload ──────────────────────────────────
  Future<void> _pickAvatar() async {
    final file = await MediaPicker.pickImageOnly();
    if (file == null || !mounted) return;

    setState(() { _localAvatar = file; _uploadingAvatar = true; });

    try {
      final url = await UploadManager().uploadAvatar(file);
      if (mounted) {
        setState(() {
          _uploadedAvatarUrl = url;
          _uploadingAvatar   = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Расм бор нашуд: $e'),
              backgroundColor: Colors.red.shade800));
      }
    }
  }

  // ── Мусиқии bio кушо ─────────────────────────────────────────
  Future<void> _openMusicPicker() async {
    final result = await showModalBottomSheet<SongInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => MusicPickerSheet(initial: _bioSong),
    );
    if (result != null && mounted) setState(() => _bioSong = result);
  }

  // ── Сабт кун ─────────────────────────────────────────────────
  Future<void> _save() async {
    final ok = await _ctrl.save(bioSong: _bioSong, avatarUrl: _uploadedAvatarUrl);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_ctrl.error ?? 'Хатогӣ'),
            backgroundColor: Colors.red.shade800),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Таҳрири профил',
            style: TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          _ctrl.isSaving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)))
              : TextButton(
                  onPressed: _save,
                  child: const Text('Сабт',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
        ],
      ),
      body: _ctrl.isLoading
          ? const Center(child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [

                // ── Avatar placeholder ───────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: Stack(alignment: Alignment.bottomRight, children: [
                      // Avatar circle
                      Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1A1A1A),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 2),
                        ),
                        child: ClipOval(
                          child: _localAvatar != null
                              ? Image.file(_localAvatar!, fit: BoxFit.cover)
                              : (_ctrl.currentAvatarUrl?.isNotEmpty == true
                                  ? Image.network(_ctrl.currentAvatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.person_rounded,
                                              color: Colors.white38, size: 42))
                                  : const Icon(Icons.person_rounded,
                                      color: Colors.white38, size: 42)),
                        ),
                      ),
                      // Camera badge
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _uploadingAvatar
                              ? Colors.grey : Colors.white,
                        ),
                        child: _uploadingAvatar
                            ? const Padding(
                                padding: EdgeInsets.all(6),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 14),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Username ─────────────────────────────────────
                _FieldLabel('Номи корбарӣ'),
                const SizedBox(height: 6),
                _TextField(
                  controller: _ctrl.usernameController,
                  hint: 'username',
                  icon: Icons.alternate_email_rounded,
                  maxLength: 30,
                ),
                const SizedBox(height: 20),

                // ── Bio ──────────────────────────────────────────
                _FieldLabel('Биография'),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  child: TextField(
                    controller: _ctrl.bioController,
                    maxLines:   4,
                    maxLength:  150,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Худро муаррифӣ кун...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3)),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 60),
                        child: Icon(Icons.info_outline_rounded,
                            color: Colors.white38, size: 18)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(
                          12, 12, 12, 0),
                      counterStyle: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Мусиқии bio ──────────────────────────────────
                _FieldLabel('Мусиқии профил'),
                const SizedBox(height: 6),
                _bioSong == null || _bioSong!.isEmpty
                    ? _AddMusicTile(onTap: _openMusicPicker)
                    : _MusicCard(
                        song: _bioSong!,
                        onChange: _openMusicPicker,
                        onRemove: () => setState(() => _bioSong = null),
                      ),
                const SizedBox(height: 20),

                // ── Private toggle ───────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: Colors.white60, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Профили хусусӣ',
                          style: TextStyle(
                              color: Colors.white, fontSize: 14)),
                    ),
                    Switch(
                      value:    _ctrl.isPrivate,
                      onChanged: _ctrl.togglePrivate,
                      activeColor: Colors.white,
                    ),
                  ]),
                ),
              ]),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text,
        style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String   hint;
  final IconData icon;
  final int      maxLength;
  const _TextField({required this.controller, required this.hint,
      required this.icon, this.maxLength = 50});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: TextField(
      controller: controller,
      maxLength:  maxLength,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText:    hint,
        hintStyle:   TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon:  Icon(icon, color: Colors.white38, size: 18),
        border:      InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        counterStyle: TextStyle(
            color: Colors.white.withOpacity(0.2), fontSize: 11),
      ),
    ),
  );
}

class _AddMusicTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMusicTile({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            border: Border.all(
                color: Colors.white.withOpacity(0.35)),
          ),
          child: const Icon(Icons.music_note_rounded,
              color: Colors.white, size: 17),
        ),
        const SizedBox(width: 12),
        Text('Мусиқӣ илова кун',
            style: TextStyle(
                color: Colors.white.withOpacity(0.5), fontSize: 14)),
        const Spacer(),
        Icon(Icons.chevron_right_rounded,
            color: Colors.white.withOpacity(0.2)),
      ]),
    ),
  );
}

class _MusicCard extends StatelessWidget {
  final SongInfo     song;
  final VoidCallback onChange;
  final VoidCallback onRemove;
  const _MusicCard({required this.song, required this.onChange,
      required this.onRemove});

  String _t(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: Colors.white.withOpacity(0.3)),
    ),
    child: Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: song.artUrl.isNotEmpty
            ? Image.network(song.artUrl,
                width: 46, height: 46, fit: BoxFit.cover)
            : Container(width: 46, height: 46,
                color: const Color(0xFF1A1A1A),
                child: const Icon(Icons.music_note_rounded,
                    color: Colors.white, size: 22)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(song.title,
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(song.artist,
            style: TextStyle(
                color: Colors.white.withOpacity(0.45), fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('${_t(song.startMs)} – ${_t(song.endMs)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 10)),
      ])),
      GestureDetector(
        onTap: onChange,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Text('Иваз',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onRemove,
        child: const Icon(Icons.close_rounded,
            color: Colors.white30, size: 18),
      ),
    ]),
  );
}
