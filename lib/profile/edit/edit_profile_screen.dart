// lib/profile/edit/edit_profile_screen.dart
// Raonson Edit Profile — full Instagram UX
// Fields: Name, Username, Bio, Website, Gender, Location, Birthday
// Avatar: Camera / Gallery + image_cropper (circle + square + free)
// Username: realtime duplicate check
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/services/user_session.dart';
import '../profile_repository.dart';
import 'edit_profile_controller.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;
  const EditProfileScreen({super.key, required this.userId});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final EditProfileController _ctrl;
  final _repo = ProfileRepository(ApiClient.instance);

  File?    _localAvatar;
  String?  _uploadedAvatarUrl;
  bool     _uploadingAvatar = false;

  // Username realtime validation
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

  // ── Username validation ──────────────────────────────────────────
  void _onUsernameChanged() {
    final val = _ctrl.usernameController.text.trim();
    _debounce?.cancel();
    if (val == _originalUsername) {
      setState(() { _usernameError = null; _usernameTaken = false; _checkingUsername = false; });
      return;
    }
    if (val.isEmpty) {
      setState(() => _usernameError = 'Username талаб мешавад');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9._]{3,30}$').hasMatch(val)) {
      setState(() {
        _usernameError = 'Танҳо ҳарфҳо, рақамҳо, . ва _ (3-30)';
        _usernameTaken = false;
        _checkingUsername = false;
      });
      return;
    }
    setState(() { _checkingUsername = true; _usernameError = null; _usernameTaken = false; });
    _debounce = Timer(const Duration(milliseconds: 600),
        () => _checkUsername(val));
  }

  Future<void> _checkUsername(String val) async {
    if (!mounted) return;
    try {
      final taken = await _repo.isUsernameTaken(val, _originalUsername);
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        _usernameTaken    = taken;
        _usernameError    = taken ? 'Ин username аллакай банд аст' : null;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingUsername = false);
    }
  }

  // ── Avatar pick + crop ───────────────────────────────────────────
  void _avatarTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        ListTile(leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
            title: const Text('Галерея', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(context); _pick(ImageSource.gallery); }),
        ListTile(leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
            title: const Text('Камера', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(context); _pick(ImageSource.camera); }),
        if ((_ctrl.currentAvatarUrl ?? '').isNotEmpty || _localAvatar != null)
          ListTile(leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Расмро нест кун', style: TextStyle(color: Colors.redAccent)),
              onTap: () { Navigator.pop(context); _removeAvatar(); }),
        const SizedBox(height: 8),
      ])),
    );
  }

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(source: source, imageQuality: 92);
    if (xfile == null) return;
    // Open Instagram-style cropper
    final cropped = await ImageCropper().cropImage(
      sourcePath: xfile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle:  'Расмро танзим кун',
          toolbarColor:  Colors.black,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.neonBlue,
          backgroundColor: Colors.black,
          cropStyle:  CropStyle.circle,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x5,
            CropAspectRatioPreset.original,
          ],
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title:      'Расмро танзим кун',
          cropStyle:  CropStyle.circle,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x5,
            CropAspectRatioPreset.original,
          ],
        ),
      ],
    );
    if (cropped == null || !mounted) return;
    setState(() { _localAvatar = File(cropped.path); _uploadingAvatar = true; });
    try {
      final url = await _repo.uploadAvatar(File(cropped.path));
      if (mounted) setState(() { _uploadedAvatarUrl = url; _uploadingAvatar = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        _snack('Расм бор нашуд: $e', isError: true);
      }
    }
  }

  void _removeAvatar() {
    setState(() { _localAvatar = null; _uploadedAvatarUrl = ''; });
  }

  // ── Save ─────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_usernameTaken || _usernameError != null) {
      _snack(_usernameError ?? 'Username нодуруст', isError: true);
      return;
    }
    if (_checkingUsername) {
      _snack('Лутфан интизор шавед...', isError: false);
      return;
    }
    final ok = await _ctrl.save(
      avatarUrl:  _uploadedAvatarUrl,
      removeAvatar: _uploadedAvatarUrl == '',
    );
    if (!mounted) return;
    if (ok) {
      UserSession.username = _ctrl.usernameController.text.trim();
      if (_uploadedAvatarUrl?.isNotEmpty == true) {
        UserSession.avatar = _uploadedAvatarUrl;
      }
      Navigator.pop(context, true);
    } else {
      final err = _ctrl.error ?? 'Хатогӣ';
      final msg = err.contains('409') || err.toLowerCase().contains('taken')
          ? 'Ин username банд аст' : err;
      _snack(msg, isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade800 : null,
      duration: const Duration(seconds: 2)));
  }

  bool get _isOriginal =>
      _ctrl.usernameController.text.trim() == _originalUsername;

  // ── BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Таҳрири профил',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15))),
        ],
      ),
      body: _ctrl.isLoading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.neonBlue, strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Avatar ─────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: _uploadingAvatar ? null : _avatarTap,
                      child: Stack(alignment: Alignment.bottomRight, children: [
                        Container(
                          width: 96, height: 96,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.card,
                              border: Border.all(
                                  color: Colors.white24, width: 2)),
                          child: ClipOval(child: _avatarWidget())),
                        Container(
                          width: 30, height: 30,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.neonBlue),
                          child: _uploadingAvatar
                              ? const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 16)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: GestureDetector(
                      onTap: _uploadingAvatar ? null : _avatarTap,
                      child: const Text('Аксро тағир бидеҳ',
                          style: TextStyle(
                              color: AppColors.neonBlue, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Name (fullName) ────────────────────────────
                  _label('Ном'),
                  const SizedBox(height: 6),
                  _field(
                      controller: _ctrl.nameController,
                      hint: 'Ном ва насаб',
                      icon: Icons.person_outline_rounded,
                      maxLength: 60),
                  const SizedBox(height: 18),

                  // ── Username ───────────────────────────────────
                  _label('Номи корбарӣ'),
                  const SizedBox(height: 6),
                  _buildUsernameField(),
                  const SizedBox(height: 18),

                  // ── Bio ────────────────────────────────────────
                  _label('Биография'),
                  const SizedBox(height: 6),
                  _bioField(),
                  const SizedBox(height: 18),

                  // ── Website ────────────────────────────────────
                  _label('Веб-сайт'),
                  const SizedBox(height: 6),
                  _field(
                      controller: _ctrl.websiteController,
                      hint: 'https://example.com',
                      icon: Icons.link_rounded,
                      keyboardType: TextInputType.url),
                  const SizedBox(height: 18),

                  // ── Gender ────────────────────────────────────
                  _label('Ҷинс'),
                  const SizedBox(height: 6),
                  _GenderSelector(
                      value:    _ctrl.gender,
                      onChange: (v) => setState(() => _ctrl.gender = v)),
                  const SizedBox(height: 18),

                  // ── Location ──────────────────────────────────
                  _label('Макон'),
                  const SizedBox(height: 6),
                  _field(
                      controller: _ctrl.locationController,
                      hint: 'Шаҳри шумо',
                      icon: Icons.location_on_outlined),
                  const SizedBox(height: 18),

                  // ── Birthday ──────────────────────────────────
                  _label('Таваллуд'),
                  const SizedBox(height: 6),
                  _BirthdayPicker(
                      value:    _ctrl.birthday,
                      onChange: (d) => setState(() => _ctrl.birthday = d)),
                  const SizedBox(height: 24),

                  // ── Private toggle ────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: _boxDec(),
                    child: Row(children: [
                      const Icon(Icons.lock_outline_rounded,
                          color: Colors.white60, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Профили хусусӣ',
                          style: TextStyle(color: Colors.white, fontSize: 14))),
                      Switch(
                          value:     _ctrl.isPrivate,
                          onChanged: _ctrl.togglePrivate,
                          activeColor: AppColors.neonBlue),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }

  // Avatar display logic
  Widget _avatarWidget() {
    if (_localAvatar != null) {
      return Image.file(_localAvatar!, fit: BoxFit.cover, width: 96, height: 96);
    }
    final url = _uploadedAvatarUrl == ''
        ? null : (_ctrl.currentAvatarUrl ?? '');
    if (url != null && url.isNotEmpty) {
      return Image.network(url, fit: BoxFit.cover, width: 96, height: 96,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.person_rounded, color: Colors.white38, size: 48));
    }
    return const Icon(Icons.person_rounded, color: Colors.white38, size: 48);
  }

  Widget _buildUsernameField() {
    Color borderColor = Colors.white.withOpacity(0.08);
    if (_usernameTaken || (_usernameError != null && !_isOriginal)) {
      borderColor = Colors.red.withOpacity(0.7);
    } else if (!_checkingUsername && !_isOriginal &&
        _ctrl.usernameController.text.length >= 3 &&
        _usernameError == null) {
      borderColor = Colors.green.withOpacity(0.6);
    }

    Widget? suffix;
    if (_checkingUsername) {
      suffix = const Padding(padding: EdgeInsets.all(12),
          child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)));
    } else if (_usernameTaken ||
        (_usernameError != null && !_isOriginal)) {
      suffix = const Icon(Icons.close_rounded, color: Colors.red, size: 20);
    } else if (!_isOriginal &&
        _ctrl.usernameController.text.length >= 3 &&
        _usernameError == null) {
      suffix = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2)),
        child: TextField(
          controller: _ctrl.usernameController,
          maxLength:  30,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText:   'username',
            hintStyle:  TextStyle(color: Colors.white.withOpacity(0.3)),
            prefixIcon: const Icon(Icons.alternate_email_rounded,
                color: Colors.white38, size: 18),
            suffixIcon:  suffix,
            border:      InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            counterStyle: TextStyle(
                color: Colors.white.withOpacity(0.2), fontSize: 11)),
        ),
      ),
      if (!_isOriginal) ...[
        const SizedBox(height: 4),
        Text(
          _usernameError ?? (_usernameTaken
              ? 'Ин username банд аст ✗'
              : (_checkingUsername ? 'Санҷиш...' : 'Username озод аст ✓')),
          style: TextStyle(fontSize: 12, color:
            (_usernameError != null || _usernameTaken)
                ? Colors.red
                : (_checkingUsername ? Colors.white38 : Colors.green)),
        ),
      ],
    ]);
  }

  Widget _bioField() {
    return Container(
      decoration: _boxDec(),
      child: TextField(
        controller: _ctrl.bioController,
        maxLines:   4,
        maxLength:  150,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText:  'Худро муаррифӣ кун...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 60),
              child: Icon(Icons.info_outline_rounded,
                  color: Colors.white38, size: 18)),
          border:      InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          counterStyle: TextStyle(
              color: Colors.white.withOpacity(0.2), fontSize: 11)),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: _boxDec(),
      child: TextField(
        controller:   controller,
        maxLength:    maxLength,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText:   hint,
          hintStyle:  TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: Colors.white38, size: 18),
          border:     InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          counterStyle: TextStyle(
              color: Colors.white.withOpacity(0.2), fontSize: 11)),
      ),
    );
  }

  Widget _label(String t) {
    return Text(t,
        style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600));
  }

  BoxDecoration _boxDec() => BoxDecoration(
    color: const Color(0xFF111111),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.white.withOpacity(0.08)),
  );

  Widget _handle() => Center(child: Container(
    width: 36, height: 4,
    margin: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
        color: Colors.white24, borderRadius: BorderRadius.circular(2))));
}

// ── Gender selector ────────────────────────────────────────────────────
class _GenderSelector extends StatelessWidget {
  final String? value;
  final void Function(String?) onChange;
  const _GenderSelector({required this.value, required this.onChange});

  static const _opts = [
    ('Нишон дода нашавад', null),
    ('Мард', 'male'),
    ('Зан',  'female'),
    ('Дигар', 'other'),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1C1C1E),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)))),
            const Padding(padding: EdgeInsets.only(bottom: 10),
              child: Text('Ҷинс', style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
            ..._opts.map((o) => RadioListTile<String?>(
              title: Text(o.$1, style: const TextStyle(color: Colors.white)),
              value:     o.$2,
              groupValue: value,
              activeColor: AppColors.neonBlue,
              onChanged: (v) { Navigator.pop(context); onChange(v); })),
            const SizedBox(height: 8),
          ])),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Row(children: [
          const Icon(Icons.wc_rounded, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(
            _opts.firstWhere((o) => o.$2 == value,
                orElse: () => _opts.first).$1,
            style: const TextStyle(color: Colors.white, fontSize: 14))),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.white24, size: 20),
        ]),
      ),
    );
  }
}

// ── Birthday picker ────────────────────────────────────────────────────
class _BirthdayPicker extends StatelessWidget {
  final DateTime? value;
  final void Function(DateTime?) onChange;
  const _BirthdayPicker({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context:      context,
          initialDate:  value ?? DateTime(2000),
          firstDate:    DateTime(1900),
          lastDate:     DateTime.now(),
          builder:      (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.neonBlue,
                surface: Color(0xFF1C1C1E)),
            ),
            child: child!,
          ),
        );
        onChange(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Row(children: [
          const Icon(Icons.cake_outlined, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(
            value != null
                ? DateFormat('dd.MM.yyyy').format(value!)
                : 'Санаи таваллуд',
            style: TextStyle(
              color: value != null ? Colors.white : Colors.white38,
              fontSize: 14))),
          if (value != null)
            GestureDetector(
              onTap: () => onChange(null),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white38, size: 18)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.white24, size: 20),
        ]),
      ),
    );
  }
}
