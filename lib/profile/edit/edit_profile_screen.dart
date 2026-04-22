import 'dart:async';
import 'dart:io';
import '../../create/create_post/media_picker.dart';
import '../../create/upload/upload_manager.dart';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/services/user_session.dart';
import '../../models/note_model.dart';
import '../../chat/inbox/music_picker_sheet.dart';
import 'edit_profile_controller.dart';

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
  bool    _usernameTaken    = false;
  String? _usernameError;
  String  _originalUsername = '';

  @override
  void initState() {
    super.initState();
    _ctrl = EditProfileController();
    _ctrl.loadCurrentProfile(widget.userId).then((_) {
      _originalUsername = _ctrl.usernameController.text;
    });
    _ctrl.addListener(() { if (mounted) setState(() {}); });
    _ctrl.usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.usernameController.removeListener(_onUsernameChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final val = _ctrl.usernameController.text.trim();
    _debounce?.cancel();
    if (val == _originalUsername) {
      setState(() { _usernameError = null; _usernameTaken = false; _checkingUsername = false; });
      return;
    }
    if (val.isEmpty) {
      setState(() { _usernameError = 'Username талаб мешавад'; });
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9._]{3,30}$').hasMatch(val)) {
      setState(() { _usernameError = 'Танҳо ҳарфҳо, рақамҳо, . ва _ (3-30)'; _usernameTaken = false; _checkingUsername = false; });
      return;
    }
    setState(() { _checkingUsername = true; _usernameError = null; _usernameTaken = false; });
    _debounce = Timer(const Duration(milliseconds: 700), () => _checkUsername(val));
  }

  Future<void> _checkUsername(String val) async {
    if (!mounted) return;
    try {
      final taken = await controller.isUsernameTaken(val, _originalUsername);
      if (!mounted) return;
      setState(() { _checkingUsername = false; _usernameTaken = taken; _usernameError = taken ? 'Ин username аллакай банд аст' : null; });
    } catch (_) {
      if (mounted) setState(() { _checkingUsername = false; });
    }
  }

  Future<void> _pickAvatar() async {
    final file = await MediaPicker.pickImageOnly();
    if (file == null || !mounted) return;
    setState(() { _localAvatar = file; _uploadingAvatar = true; });
    try {
      final url = await UploadManager().uploadAvatar(file);
      if (mounted) setState(() { _uploadedAvatarUrl = url; _uploadingAvatar = false; });
    } catch (e) {
      if (mounted) { setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Расм бор нашуд: $e'), backgroundColor: Colors.red.shade800)); }
    }
  }

  Future<void> _openMusicPicker() async {
    final result = await showModalBottomSheet<SongInfo>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, useRootNavigator: true,
      builder: (_) => MusicPickerSheet(initial: _bioSong));
    if (result != null && mounted) setState(() => _bioSong = result);
  }

  Future<void> _save() async {
    if (_usernameTaken || _usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_usernameError ?? 'Username нодуруст'), backgroundColor: Colors.red.shade800)); return;
    }
    if (_checkingUsername) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Лутфан интизор шавед...'), backgroundColor: Colors.orange)); return;
    }
    final ok = await _ctrl.save(bioSong: _bioSong, avatarUrl: _uploadedAvatarUrl);
    if (!mounted) return;
    if (ok) {
      UserSession.username = _ctrl.usernameController.text.trim();
      if (_uploadedAvatarUrl?.isNotEmpty == true) UserSession.avatar = _uploadedAvatarUrl;
      Navigator.pop(context, true);
    } else {
      final err = _ctrl.error ?? 'Хатогӣ';
      final msg = err.contains('409') || err.toLowerCase().contains('taken') ? 'Ин username банд аст' : err;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade800));
    }
  }

  bool get _isOriginal => _ctrl.usernameController.text.trim() == _originalUsername;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Таҳрири профил', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [_ctrl.isSaving
            ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
            : TextButton(onPressed: _save, child: const Text('Сабт', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)))],
      ),
      body: _ctrl.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.storyStart, strokeWidth: 2))
          : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [

        // Avatar
        Center(child: GestureDetector(onTap: _uploadingAvatar ? null : _pickAvatar,
          child: Stack(alignment: Alignment.bottomRight, children: [
            Container(width: 96, height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.card,
                  border: Border.all(color: Colors.white24, width: 2)),
              child: ClipOval(child: _localAvatar != null
                  ? Image.file(_localAvatar!, fit: BoxFit.cover)
                  : (_ctrl.currentAvatarUrl?.isNotEmpty == true
                      ? Image.network(_ctrl.currentAvatarUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Colors.white38, size: 46))
                      : const Icon(Icons.person_rounded, color: Colors.white38, size: 46)))),
            Container(width: 30, height: 30,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0095F6)),
              child: _uploadingAvatar
                  ? const Padding(padding: EdgeInsets.all(7), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16)),
          ]))),
        const SizedBox(height: 6),
        const Text('Аксро тағир бидеҳ', style: TextStyle(color: Color(0xFF0095F6), fontSize: 13)),
        const SizedBox(height: 28),

        // Username
        _label('Номи корбарӣ'),
        const SizedBox(height: 6),
        _buildUsernameField(),
        const SizedBox(height: 20),

        // Bio
        _label('Биография'),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: TextField(controller: _ctrl.bioController, maxLines: 4, maxLength: 150,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Худро муаррифӣ кун...', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 60), child: Icon(Icons.info_outline_rounded, color: Colors.white38, size: 18)),
              border: InputBorder.none, contentPadding: const EdgeInsets.fromLTRB(12,12,12,0),
              counterStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)))),
        const SizedBox(height: 20),

        // Music
        _label('Мусиқии профил'), const SizedBox(height: 6),
        _bioSong == null || _bioSong!.isEmpty
            ? _AddMusicTile(onTap: _openMusicPicker)
            : _MusicCard(song: _bioSong!, onChange: _openMusicPicker, onRemove: () => setState(() => _bioSong = null)),
        const SizedBox(height: 20),

        // Private
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Row(children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white60, size: 20),
            const SizedBox(width: 12),
            const Expanded(child: Text('Профили хусусӣ', style: TextStyle(color: Colors.white, fontSize: 14))),
            Switch(value: _ctrl.isPrivate, onChanged: _ctrl.togglePrivate, activeColor: AppColors.storyStart)])),
        const SizedBox(height: 40),
      ])),
    );
  }

  Widget _buildUsernameField() {
    Color border = Colors.white.withOpacity(0.08);
    if (_usernameTaken || (_usernameError != null && !_isOriginal)) border = Colors.red.withOpacity(0.7);
    else if (!_checkingUsername && !_isOriginal && _ctrl.usernameController.text.length >= 3 && _usernameError == null)
      border = Colors.green.withOpacity(0.6);

    Widget? suffix;
    if (_checkingUsername)
      suffix = const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)));
    else if (_usernameTaken || (_usernameError != null && !_isOriginal))
      suffix = const Icon(Icons.close_rounded, color: Colors.red, size: 20);
    else if (!_isOriginal && _ctrl.usernameController.text.length >= 3 && _usernameError == null)
      suffix = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.2)),
        child: TextField(controller: _ctrl.usernameController, maxLength: 30,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'username', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            prefixIcon: const Icon(Icons.alternate_email_rounded, color: Colors.white38, size: 18),
            suffixIcon: suffix, border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            counterStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)))),
      if (!_isOriginal) ...[
        const SizedBox(height: 5),
        Text(_usernameError ?? (_usernameTaken ? 'Ин username банд аст ✗' : (_checkingUsername ? 'Санҷиш...' : 'Username озод аст ✓')),
            style: TextStyle(fontSize: 12,
                color: (_usernameError != null || _usernameTaken) ? Colors.red : (_checkingUsername ? Colors.white38 : Colors.green))),
      ],
    ]);
  }

  Widget _label(String t) => Align(alignment: Alignment.centerLeft,
    child: Text(t, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)));
}

class _AddMusicTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMusicTile({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white.withOpacity(0.3))),
          child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 17)),
        const SizedBox(width: 12),
        Text('Мусиқӣ илова кун', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
        const Spacer(), Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2))])));
}

class _MusicCard extends StatelessWidget {
  final SongInfo song; final VoidCallback onChange, onRemove;
  const _MusicCard({required this.song, required this.onChange, required this.onRemove});
  String _t(int ms) { final s = ms ~/ 1000; return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'; }
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.3))),
    child: Row(children: [
      ClipRRect(borderRadius: BorderRadius.circular(8),
        child: song.artUrl.isNotEmpty
            ? Image.network(song.artUrl, width: 48, height: 48, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: AppColors.card, child: const Icon(Icons.music_note_rounded, color: Colors.white38)))
            : Container(width: 48, height: 48, color: AppColors.card, child: const Icon(Icons.music_note_rounded, color: Colors.white38))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(song.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(song.artist, style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(_t(song.trackMs), style: const TextStyle(color: Colors.white38, fontSize: 11))])),
      IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.white54, size: 18), onPressed: onChange),
      IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18), onPressed: onRemove)]));
}
