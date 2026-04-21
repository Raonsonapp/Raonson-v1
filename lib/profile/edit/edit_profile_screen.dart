import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../create/create_post/media_picker.dart';
import '../../create/upload/upload_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/services/user_session.dart';
import '../../models/note_model.dart';
import '../../chat/inbox/music_picker_sheet.dart';
import 'edit_profile_controller.dart';

// ══════════════════════════════════════════════════════════════════
class EditProfileScreen extends StatefulWidget {
  final String userId;
  const EditProfileScreen({super.key, required this.userId});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final EditProfileController _ctrl;

  SongInfo? _bioSong;
  File?     _localAvatar;
  String?   _uploadedAvatarUrl;
  bool      _uploadingAvatar = false;

  // Username validation
  Timer?  _debounce;
  bool    _checkingUsername = false;
  String? _usernameError;
  bool    _usernameTaken   = false;

  @override
  void initState() {
    super.initState();
    _ctrl = EditProfileController();
    _ctrl.loadCurrentProfile(widget.userId);
    _ctrl.addListener(() { if (mounted) setState(() {}); });
    // Listen to username changes
    _ctrl.usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.usernameController.removeListener(_onUsernameChanged);
    _ctrl.dispose();
    super.dispose();
  }

  // ── Username real-time validation ────────────────────────────
  void _onUsernameChanged() {
    final val = _ctrl.usernameController.text.trim();
    _debounce?.cancel();
    if (val.isEmpty) {
      setState(() { _usernameError = null; _usernameTaken = false; });
      return;
    }

    // Instant format check
    final rx = RegExp(r'^[a-zA-Z0-9._]{3,30}$');
    if (!rx.hasMatch(val)) {
      setState(() {
        _usernameError = 'Танҳо ҳарфҳо, рақамҳо, . ва _ иҷозат дода мешаванд';
        _usernameTaken = false;
      });
      return;
    }

    setState(() { _checkingUsername = true; _usernameError = null; });
    // Debounce 600ms → server check
    _debounce = Timer(const Duration(milliseconds: 600), () => _checkUsername(val));
  }

  Future<void> _checkUsername(String val) async {
    // Агар ҳамон номи ҳозира бошад — занят нест
    if (val == (_ctrl.currentAvatarUrl == null ? '' : '')) {
      setState(() { _checkingUsername = false; _usernameTaken = false; });
      return;
    }
    try {
      final res = await ApiClient.instance.get(
          '/users/check-username', query: {'username': val});
      if (!mounted) return;
      if (res.statusCode == 409 || res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final taken = body['taken'] as bool? ?? (res.statusCode == 409);
        setState(() {
          _checkingUsername = false;
          _usernameTaken    = taken;
          _usernameError    = taken ? 'Ин username аллакай банд аст' : null;
        });
      } else {
        setState(() { _checkingUsername = false; _usernameTaken = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _checkingUsername = false; });
    }
  }

  // ── Avatar upload ────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    final file = await MediaPicker.pickImageOnly();
    if (file == null || !mounted) return;
    setState(() { _localAvatar = file; _uploadingAvatar = true; });
    try {
      final url = await UploadManager().uploadAvatar(file);
      if (mounted) setState(() {
        _uploadedAvatarUrl = url;
        _uploadingAvatar   = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Расм бор нашуд: $e'),
          backgroundColor: Colors.red.shade800));
      }
    }
  }

  // ── Music picker ─────────────────────────────────────────────
  Future<void> _openMusicPicker() async {
    final result = await showModalBottomSheet<SongInfo>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, useRootNavigator: true,
      builder: (_) => MusicPickerSheet(initial: _bioSong));
    if (result != null && mounted) setState(() => _bioSong = result);
  }

  // ── Save ─────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_usernameTaken || _usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Username-ро дуруст кунед'),
        backgroundColor: Colors.red));
      return;
    }
    final ok = await _ctrl.save(
        bioSong: _bioSong, avatarUrl: _uploadedAvatarUrl);
    if (!mounted) return;
    if (ok) {
      // Update session
      UserSession.username = _ctrl.usernameController.text.trim();
      if (_uploadedAvatarUrl != null) UserSession.avatar = _uploadedAvatarUrl;
      Navigator.pop(context, true);
    } else {
      final err = _ctrl.error ?? 'Хатогӣ';
      final msg = err.contains('409') || err.contains('taken')
          ? 'Ин username аллакай банд аст' : err;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: Colors.red.shade800));
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
          onPressed: () => Navigator.pop(context)),
        title: const Text('Таҳрири профил', style: TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          _ctrl.isSaving
              ? const Padding(padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)))
              : TextButton(
                  onPressed: _save,
                  child: const Text('Сабт', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold,
                      fontSize: 15))),
        ],
      ),
      body: _ctrl.isLoading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.storyStart, strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [

                // ── Avatar ──────────────────────────────────────
                Center(child: GestureDetector(
                  onTap: _uploadingAvatar ? null : _pickAvatar,
                  child: Stack(alignment: Alignment.bottomRight, children: [
                    Container(
                      width: 92, height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.card,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 2)),
                      child: ClipOval(child: _localAvatar != null
                          ? Image.file(_localAvatar!, fit: BoxFit.cover)
                          : (_ctrl.currentAvatarUrl?.isNotEmpty == true
                              ? Image.network(_ctrl.currentAvatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.person_rounded,
                                          color: Colors.white38, size: 44))
                              : const Icon(Icons.person_rounded,
                                  color: Colors.white38, size: 44))),
                    ),
                    Container(
                      width: 30, height: 30,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.neonBlue),
                      child: _uploadingAvatar
                          ? const Padding(padding: EdgeInsets.all(6),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 16)),
                  ]),
                )),
                const SizedBox(height: 6),
                const Text('Аксро иваз кун',
                    style: TextStyle(color: AppColors.neonBlue, fontSize: 13)),
                const SizedBox(height: 28),

                // ── Username ────────────────────────────────────
                _FieldLabel('Номи корбарӣ'),
                const SizedBox(height: 6),
                _UsernameField(
                  controller: _ctrl.usernameController,
                  isChecking: _checkingUsername,
                  isTaken:    _usernameTaken,
                  error:      _usernameError,
                ),
                const SizedBox(height: 20),

                // ── Bio ─────────────────────────────────────────
                _FieldLabel('Биография'),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08))),
                  child: TextField(
                    controller: _ctrl.bioController,
                    maxLines: 4, maxLength: 150,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Худро муаррифӣ кун...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 60),
                        child: Icon(Icons.info_outline_rounded,
                            color: Colors.white38, size: 18)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      counterStyle: TextStyle(
                          color: Colors.white.withOpacity(0.2), fontSize: 11))),
                ),
                const SizedBox(height: 20),

                // ── Music ───────────────────────────────────────
                _FieldLabel('Мусиқии профил'),
                const SizedBox(height: 6),
                _bioSong == null || _bioSong!.isEmpty
                    ? _AddMusicTile(onTap: _openMusicPicker)
                    : _MusicCard(
                        song: _bioSong!,
                        onChange: _openMusicPicker,
                        onRemove: () => setState(() => _bioSong = null)),
                const SizedBox(height: 20),

                // ── Private ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08))),
                  child: Row(children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: Colors.white60, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Профили хусусӣ',
                        style: TextStyle(color: Colors.white, fontSize: 14))),
                    Switch(
                      value: _ctrl.isPrivate,
                      onChanged: _ctrl.togglePrivate,
                      activeColor: AppColors.storyStart),
                  ]),
                ),
                const SizedBox(height: 40),
              ]),
            ),
    );
  }
}

// ── Username field бо validation ────────────────────────────────────
class _UsernameField extends StatelessWidget {
  final TextEditingController controller;
  final bool    isChecking;
  final bool    isTaken;
  final String? error;

  const _UsernameField({
    required this.controller,
    required this.isChecking,
    required this.isTaken,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.white.withOpacity(0.08);
    if (isTaken) borderColor = Colors.red.withOpacity(0.6);
    else if (!isChecking && error == null && controller.text.isNotEmpty)
      borderColor = Colors.green.withOpacity(0.5);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2)),
        child: TextField(
          controller: controller,
          maxLength: 30,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'username',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            prefixIcon: const Icon(Icons.alternate_email_rounded,
                color: Colors.white38, size: 18),
            suffixIcon: isChecking
                ? const Padding(padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white38)))
                : isTaken
                    ? const Icon(Icons.close_rounded,
                        color: Colors.red, size: 20)
                    : (error == null && controller.text.length >= 3)
                        ? const Icon(Icons.check_circle_outline_rounded,
                            color: Colors.green, size: 20)
                        : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            counterStyle: TextStyle(
                color: Colors.white.withOpacity(0.2), fontSize: 11))),
      ),
      if (error != null || isTaken) ...[
        const SizedBox(height: 6),
        Text(
          isTaken ? 'Ин username аллакай банд аст' : (error ?? ''),
          style: const TextStyle(color: Colors.red, fontSize: 12)),
      ] else if (!isChecking && controller.text.length >= 3) ...[
        const SizedBox(height: 6),
        const Text('Username озод аст ✓',
            style: TextStyle(color: Colors.green, fontSize: 12)),
      ],
    ]);
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 12, fontWeight: FontWeight.w600)));
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
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            border: Border.all(color: Colors.white.withOpacity(0.35))),
          child: const Icon(Icons.music_note_rounded,
              color: Colors.white, size: 17)),
        const SizedBox(width: 12),
        Text('Мусиқӣ илова кун',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
        const Spacer(),
        Icon(Icons.chevron_right_rounded,
            color: Colors.white.withOpacity(0.2)),
      ]),
    ));
}

class _MusicCard extends StatelessWidget {
  final SongInfo song;
  final VoidCallback onChange, onRemove;
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
      border: Border.all(color: Colors.white.withOpacity(0.3))),
    child: Row(children: [
      if (song.artUrl.isNotEmpty)
        ClipRRect(borderRadius: BorderRadius.circular(8),
          child: Image.network(song.artUrl, width: 48, height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  width: 48, height: 48, color: AppColors.card,
                  child: const Icon(Icons.music_note_rounded,
                      color: Colors.white38))))
      else
        Container(width: 48, height: 48, color: AppColors.card,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.music_note_rounded, color: Colors.white38)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(song.name, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(song.artist, style: const TextStyle(
            color: Colors.white54, fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(_t(song.durationMs), style: const TextStyle(
            color: Colors.white38, fontSize: 11)),
      ])),
      IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.white54, size: 18),
          onPressed: onChange),
      IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
          onPressed: onRemove),
    ]),
  );
}
