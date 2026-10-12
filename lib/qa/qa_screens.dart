// lib/qa/qa_screens.dart
// «Савол ба ман» — таби «Ҷавобҳо» дар профил, савол додан (метавонад
// беном бошад), қуттии саволҳо барои соҳиб ва танзими «Кӣ савол дода
// метавонад». Сервер: backend/handlers/qa.go.
//
// Беном: сервер номро ба соҳиб ва тамошобинон НАМЕФИРИСТАД — экран ҳам
// онро аз ҷои дигар намегирад.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/feature_kit.dart';
import '../core/utils/server_time.dart';
import '../core/utils/time_ago.dart';
import '../widgets/avatar.dart';

class QAItem {
  final String id, text, answer, status;
  final bool anonymous, canDelete;
  final MiniUser? asker;
  final DateTime? at;
  const QAItem(this.id, this.text, this.answer, this.status, this.anonymous,
      this.canDelete, this.asker, this.at);

  factory QAItem.fromJson(Map<String, dynamic> j) => QAItem(
        (j['_id'] ?? '').toString(),
        (j['text'] ?? '').toString(),
        (j['answer'] ?? '').toString(),
        (j['status'] ?? '').toString(),
        j['anonymous'] == true,
        j['canDelete'] == true,
        MiniUser.fromJson(j['asker']),
        parseServerTime(j['answeredAt'] ?? j['createdAt']),
      );
}

class QAPage {
  final List<QAItem> items;
  final bool canAsk;
  final int pending;
  final String mode;
  const QAPage(this.items, this.canAsk, this.pending, this.mode);
}

class QARepository {
  static List<QAItem> _items(dynamic r) => ((r['questions'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => QAItem.fromJson(e.cast<String, dynamic>()))
      .toList();

  static Future<QAPage> answered(String userId) async {
    final r = await apiJson('GET', '/users/$userId/questions');
    final m = (r['meta'] as Map?) ?? const {};
    return QAPage(_items(r), m['canAsk'] == true,
        (m['pendingCount'] as num?)?.toInt() ?? 0, (m['mode'] ?? '').toString());
  }

  static Future<List<QAItem>> inbox() async => _items(await apiJson('GET', '/qa/inbox'));
  static Future<void> ask(String userId, String text, bool anonymous) =>
      apiJson('POST', '/users/$userId/questions',
          body: {'text': text, 'anonymous': anonymous});
  static Future<void> answer(String id, String text) =>
      apiJson('POST', '/questions/$id/answer', body: {'text': text});
  static Future<void> delete(String id) => apiJson('DELETE', '/questions/$id');
  static Future<void> blockAsker(String id) =>
      apiJson('POST', '/questions/$id/block-asker');
  static Future<String> mode() async =>
      ((await apiJson('GET', '/qa/settings'))['mode'] ?? 'followers').toString();
  static Future<void> setMode(String m) =>
      apiJson('PUT', '/qa/settings', body: {'mode': m});
}

/// Таби «Ҷавобҳо» дар профил.
class ProfileAnswersTab extends StatefulWidget {
  final String userId;
  final bool isMe;
  /// Барои санҷиш иваз мешавад.
  final Future<QAPage> Function(String userId)? load;
  const ProfileAnswersTab(
      {super.key, required this.userId, required this.isMe, this.load});

  @override
  State<ProfileAnswersTab> createState() => _ProfileAnswersTabState();
}

class _ProfileAnswersTabState extends State<ProfileAnswersTab> {
  QAPage? _p;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId.isEmpty) return;
    try {
      final p = await (widget.load ?? QARepository.answered)(widget.userId);
      if (mounted) setState(() { _p = p; _error = false; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _ask() async {
    final sent = await showAskQuestionSheet(context, widget.userId);
    if (sent == true && mounted) showSnack(context, tr('qa.sent'));
  }

  Future<void> _openInbox() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const QAInboxScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return FeatureMessage(
          icon: AppIcons.question_rounded, text: tr('feat.failed'), onRetry: _load);
    }
    final p = _p;
    if (p == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        if (widget.isMe)
          ListTile(
            key: const ValueKey('qa-inbox'),
            leading: const Icon(AppIcons.inbox_rounded, color: AppColors.neonBlue),
            title: Text(tr('qa.inboxCount', {'n': p.pending}),
                style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
            trailing: Icon(AppIcons.chevron_right_rounded, color: AppColors.textFaint),
            onTap: _openInbox,
          )
        else if (p.canAsk)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: ElevatedButton.icon(
              key: const ValueKey('qa-ask'),
              onPressed: _ask,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(AppIcons.question_rounded, size: 18),
              label: Text(tr('qa.ask')),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(tr('qa.closed'),
                style: TextStyle(color: AppColors.textTertiary)),
          ),
        if (p.items.isEmpty)
          FeatureMessage(icon: AppIcons.question_rounded, text: tr('qa.empty')),
        for (final q in p.items)
          QACard(
            item: q,
            onDelete: q.canDelete
                ? () async {
                    try {
                      await QARepository.delete(q.id);
                      _load();
                    } catch (e) {
                      if (context.mounted) showSnack(context, errorText(e));
                    }
                  }
                : null,
          ),
      ]),
    );
  }
}

/// Як савол ва ҷавоб.
class QACard extends StatelessWidget {
  final QAItem item;
  final VoidCallback? onDelete;
  final Widget? trailing;
  const QACard({super.key, required this.item, this.onDelete, this.trailing});

  @override
  Widget build(BuildContext context) {
    final asker = item.anonymous || item.asker == null
        ? tr('qa.anon')
        : '@${item.asker!.username}';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (item.anonymous || item.asker == null)
            CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.divider,
                child: Icon(AppIcons.question_rounded, size: 14,
                    color: AppColors.textTertiary))
          else
            Avatar(imageUrl: item.asker!.avatar, size: 24, name: item.asker!.username),
          const SizedBox(width: 8),
          Expanded(
            child: Text(asker,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
          ),
          Text(timeAgoShort(item.at),
              style: TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
          if (trailing != null) trailing!,
          if (onDelete != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: tr('feat.delete'),
              onPressed: onDelete,
              icon: Icon(AppIcons.delete_outline_rounded,
                  size: 18, color: AppColors.textFaint),
            ),
        ]),
        const SizedBox(height: 8),
        Text(item.text,
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 15, fontWeight: FontWeight.w600)),
        if (item.answer.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(item.answer,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ),
        ],
      ]),
    );
  }
}

/// Савол додан. true — фиристода шуд.
Future<bool?> showAskQuestionSheet(BuildContext context, String userId) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AskQuestionSheet(userId: userId),
    );

class AskQuestionSheet extends StatefulWidget {
  final String userId;
  final Future<void> Function(String text, bool anonymous)? send;
  const AskQuestionSheet({super.key, required this.userId, this.send});

  @override
  State<AskQuestionSheet> createState() => _AskQuestionSheetState();
}

class _AskQuestionSheetState extends State<AskQuestionSheet> {
  final _c = TextEditingController();
  bool _anon = false;
  bool _sending = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _c.text.trim();
    if (t.length < 3 || _sending) return;
    setState(() => _sending = true);
    try {
      await (widget.send ??
          (t, a) => QARepository.ask(widget.userId, t, a))(t, _anon);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(tr('qa.ask'),
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('qa-text'),
          controller: _c,
          autofocus: true,
          maxLength: 300,
          minLines: 2,
          maxLines: 5,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: tr('qa.askHint'),
            hintStyle: TextStyle(color: AppColors.textFaint),
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        SwitchListTile(
          key: const ValueKey('qa-anon'),
          contentPadding: EdgeInsets.zero,
          value: _anon,
          onChanged: (v) => setState(() => _anon = v),
          title: Text(tr('qa.anonymous'), style: TextStyle(color: AppColors.textPrimary)),
          subtitle: Text(tr('qa.anonymousHint'),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey('qa-send'),
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonBlue, foregroundColor: Colors.white),
            child: Text(tr('qa.send')),
          ),
        ),
      ]),
    );
  }
}

/// Қуттии саволҳои ҷавобнадода (соҳиб).
class QAInboxScreen extends StatefulWidget {
  final Future<List<QAItem>> Function()? load;
  const QAInboxScreen({super.key, this.load});

  @override
  State<QAInboxScreen> createState() => _QAInboxScreenState();
}

class _QAInboxScreenState extends State<QAInboxScreen> {
  List<QAItem>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await (widget.load ?? QARepository.inbox)();
      if (mounted) setState(() { _items = r; _error = false; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _answer(QAItem q) async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(q.text),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 1000,
          maxLines: 5,
          minLines: 2,
          decoration: InputDecoration(hintText: tr('qa.answerHint')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(tr('feat.cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, c.text.trim()),
              child: Text(tr('qa.answer'))),
        ],
      ),
    );
    c.dispose();
    if (text == null || text.isEmpty) return;
    try {
      await QARepository.answer(q.id, text);
      _load();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    }
  }

  Future<void> _menu(QAItem q, String action) async {
    try {
      if (action == 'block') {
        await QARepository.blockAsker(q.id);
        if (mounted) showSnack(context, tr('qa.blocked'));
      } else {
        await QARepository.delete(q.id);
      }
      _load();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('qa.inbox'), style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            tooltip: tr('qa.settings'),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const QASettingsScreen())),
            icon: const Icon(AppIcons.settings_outlined),
          ),
        ],
      ),
      body: _error
          ? FeatureMessage(icon: AppIcons.inbox_rounded, text: tr('feat.failed'),
              onRetry: _load)
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? FeatureMessage(icon: AppIcons.inbox_rounded,
                      text: tr('qa.inboxEmpty'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(children: [
                        for (final q in items)
                          GestureDetector(
                            onTap: () => _answer(q),
                            child: QACard(
                              item: q,
                              trailing: PopupMenuButton<String>(
                                icon: Icon(AppIcons.more_horiz,
                                    color: AppColors.textTertiary),
                                onSelected: (a) => _menu(q, a),
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'delete',
                                      child: Text(tr('feat.delete'))),
                                  PopupMenuItem(value: 'block',
                                      child: Text(tr('qa.blockAsker'))),
                                ],
                              ),
                            ),
                          ),
                      ]),
                    ),
    );
  }
}

/// «Кӣ савол дода метавонад» (Танзимот).
class QASettingsScreen extends StatefulWidget {
  const QASettingsScreen({super.key});
  @override
  State<QASettingsScreen> createState() => _QASettingsScreenState();
}

class _QASettingsScreenState extends State<QASettingsScreen> {
  String? _mode;

  @override
  void initState() {
    super.initState();
    QARepository.mode().then((m) {
      if (mounted) setState(() => _mode = m);
    }).catchError((_) {
      if (mounted) setState(() => _mode = 'followers');
    });
  }

  Future<void> _set(String m) async {
    final old = _mode;
    setState(() => _mode = m);
    try {
      await QARepository.setMode(m);
    } catch (e) {
      if (mounted) {
        setState(() => _mode = old);
        showSnack(context, errorText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('qa.settings'), style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: _mode == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(children: [
              for (final m in const ['everyone', 'followers', 'off'])
                RadioListTile<String>(
                  value: m,
                  groupValue: _mode,
                  onChanged: (v) => _set(v ?? m),
                  title: Text(tr('qa.mode.$m'),
                      style: TextStyle(color: AppColors.textPrimary)),
                ),
            ]),
    );
  }
}
