// lib/core/ui/feature_kit.dart
// Ёрдамчиҳои умумии панҷ имконияти нав (даъватнома, пурсиш, савол,
// мактуб ба оянда, чаленҷ): дархости JSON, ҳисоби баръакс, интихоби сана,
// интихоби одамон ва боркунии акс. Ҳамон ApiClient ва UploadManager.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_theme.dart';
import '../../create/upload/upload_manager.dart';
import '../../widgets/avatar.dart';
import '../api/api_client.dart';
import '../i18n/strings.dart';
import 'app_icons.dart';

/// Дархост → JSON. Хатои сервер → [ApiException] (бо `message`).
Future<dynamic> apiJson(String method, String path,
    {Map<String, dynamic>? body, Map<String, String>? query}) async {
  final api = ApiClient.instance;
  final res = switch (method) {
    'POST' => await api.post(path, body: body ?? const {}),
    'PUT' => await api.put(path, body: body ?? const {}),
    'DELETE' => await api.delete(path),
    _ => await api.get(path, query: query),
  };
  if (res.statusCode >= 400) throw ApiException(res.statusCode, res.body);
  if (res.body.isEmpty) return const <String, dynamic>{};
  return jsonDecode(res.body);
}

/// Матни хато барои корбар.
String errorText(Object e) =>
    (e is ApiException ? e.message : null) ?? tr('feat.failed');

void showSnack(BuildContext context, String msg) =>
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(msg)));

/// «2 рӯз 3 соат 5 дақ» ё «03:05:09» (камтар аз як рӯз).
String formatCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final days = d.inDays;
  final h = d.inHours % 24;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (days > 0) return tr('feat.countdown', {'d': days, 'h': h, 'm': m});
  String two(int v) => v.toString().padLeft(2, '0');
  return tr('feat.countdownShort', {'h': two(h), 'm': two(m), 's': two(s)});
}

/// Ҳисоби баръакс то [target]; ҳар сония нав мешавад.
class CountdownText extends StatefulWidget {
  final DateTime target;
  final TextStyle? style;
  final VoidCallback? onDone;
  final String Function(String)? wrap;
  const CountdownText(
      {super.key, required this.target, this.style, this.onDone, this.wrap});

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _t;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_fired && !DateTime.now().isBefore(widget.target)) {
        _fired = true;
        widget.onDone?.call();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = formatCountdown(widget.target.difference(DateTime.now()));
    return Text(widget.wrap?.call(s) ?? s, style: widget.style);
  }
}

/// Сана ва вақт. null — бекор.
Future<DateTime?> pickDateTime(BuildContext context,
    {DateTime? initial, DateTime? first, DateTime? last}) async {
  final now = DateTime.now();
  final init = initial ?? now.add(const Duration(days: 1));
  final date = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: first ?? now,
    lastDate: last ?? now.add(const Duration(days: 730)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
      context: context, initialTime: TimeOfDay.fromDateTime(init));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// «12.10.2026 18:00» (вақти маҳаллӣ).
String formatDateTime(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
}

/// Акс аз галерея → суроғаи боршуда. null — бекор ё хато.
Future<String?> pickAndUploadImage(BuildContext context) async {
  try {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return null;
    final url = await UploadManager().uploadFile(File(x.path));
    return url.isEmpty ? null : url;
  } catch (e) {
    if (context.mounted) showSnack(context, errorText(e));
    return null;
  }
}

/// Корбари хурд барои рӯйхатҳо.
class MiniUser {
  final String id, username, avatar;
  const MiniUser(this.id, this.username, this.avatar);
  static MiniUser? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = (j['_id'] ?? j['id'] ?? '').toString();
    if (id.isEmpty) return null;
    return MiniUser(id, (j['username'] ?? '').toString(),
        (j['avatar'] ?? '').toString());
  }
}

/// Интихоби одамон (ҷустуҷӯ). [multi]=false — як нафар.
Future<List<MiniUser>?> showUserPicker(BuildContext context,
    {bool multi = true, String? title}) {
  return Navigator.of(context).push<List<MiniUser>>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => UserPickerScreen(multi: multi, title: title)));
}

class UserPickerScreen extends StatefulWidget {
  final bool multi;
  final String? title;
  /// Барои санҷиш иваз мешавад.
  final Future<List<MiniUser>> Function(String q)? search;
  const UserPickerScreen(
      {super.key, this.multi = true, this.title, this.search});

  @override
  State<UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends State<UserPickerScreen> {
  final _q = TextEditingController();
  final Map<String, MiniUser> _picked = {};
  List<MiniUser> _results = const [];
  Timer? _debounce;

  static Future<List<MiniUser>> _search(String q) async {
    final r = await apiJson('GET', '/search/users', query: {'q': q});
    return (r is List ? r : const [])
        .map(MiniUser.fromJson)
        .whereType<MiniUser>()
        .toList();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = v.trim();
      if (q.isEmpty) return setState(() => _results = const []);
      try {
        final r = await (widget.search ?? _search)(q);
        if (mounted) setState(() => _results = r);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _toggle(MiniUser u) {
    if (!widget.multi) {
      Navigator.pop(context, [u]);
      return;
    }
    setState(() => _picked.containsKey(u.id)
        ? _picked.remove(u.id)
        : _picked[u.id] = u);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(widget.title ?? tr('feat.search'),
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (widget.multi)
            TextButton(
              onPressed: _picked.isEmpty
                  ? null
                  : () => Navigator.pop(context, _picked.values.toList()),
              child: Text('${tr('poll.done')} (${_picked.length})'),
            ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _q,
            autofocus: true,
            onChanged: _onChanged,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              prefixIcon: Icon(AppIcons.search, color: AppColors.textTertiary),
              hintText: tr('feat.search'),
              hintStyle: TextStyle(color: AppColors.textFaint),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: ListView(children: [
            for (final u in _results)
              ListTile(
                key: ValueKey('pick-${u.id}'),
                leading: Avatar(imageUrl: u.avatar, size: 40, name: u.username),
                title: Text(u.username,
                    style: TextStyle(color: AppColors.textPrimary)),
                trailing: widget.multi
                    ? Icon(
                        _picked.containsKey(u.id)
                            ? AppIcons.check_circle_rounded
                            : AppIcons.radio_button_unchecked,
                        color: _picked.containsKey(u.id)
                            ? AppColors.neonBlue
                            : AppColors.textFaint)
                    : null,
                onTap: () => _toggle(u),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Ҳолати холӣ / хато бо тугмаи «Боз кӯшиш».
class FeatureMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;
  const FeatureMessage(
      {super.key, required this.icon, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary)),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text(tr('feat.retry'))),
          ]),
        ),
      );
}

/// Сарлавҳаи бахш.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}
