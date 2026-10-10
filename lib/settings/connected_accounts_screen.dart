// lib/settings/connected_accounts_screen.dart
//
// Танзимот → «Ҳисобҳои пайвастшуда»: TajikShop.
//
//   • пайваст: ном ва почтаи ПӮШИДА, «TajikShop-ро кушоед» (бе парол),
//     «Ҷудо кардан»;
//   • пайваст нест: «Пайваст кардан» — TajikShop кушода мешавад, корбар
//     дар он ворид шуда «Ба Raonson гузаред»-ро мезанад ва TajikShop ӯро
//     бо код бармегардонад (ниг. TajikshopSignInScreen).
//
// Инчунин [openTajikshopApp] — тугмаҳои «TajikShop» дар хона, мағоза ва
// Танзимот.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/sso/tajikshop_sso.dart';
import '../core/ui/tajikshop_brand.dart';
import 'settings_screen.dart' show ChangePasswordScreen;

/// «TajikShop-ро кушоед»: бо ҳамин ҳисоб, агар пайваст бошад; вагарна
/// пешниҳоди пайванд ё танҳо кушодан.
Future<void> openTajikshopApp(BuildContext context) async {
  final sso = TajikshopSso.instance;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final nav = Navigator.of(context);
  var dialogOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
        child: CircularProgressIndicator(color: TajikshopBrand.primary)),
  ).then((_) => dialogOpen = false);
  final h = await sso.handoff();
  if (dialogOpen && nav.mounted) nav.pop();
  if (!context.mounted) return;

  if (h.linked || h.reason == 'offline') {
    await sso.openLink(h.deepLink, h.fallback);
    if (h.reason == 'session_expired') {
      messenger?.showSnackBar(SnackBar(content: Text(tr('sso.sessionExpired'))));
    }
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TajikshopBrand.logo(size: 22),
          const SizedBox(height: 14),
          Text(tr('sso.notLinkedTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(tr('sso.notLinkedBody'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: TajikshopBrand.primary,
                  foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(sheet);
                nav.push(MaterialPageRoute(
                    builder: (_) => const ConnectedAccountsScreen()));
              },
              child: Text(tr('sso.linkMine')),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(sheet);
              sso.openLink(h.deepLink, h.fallback);
            },
            child: Text(tr('sso.justOpen'),
                style: TextStyle(color: AppColors.textTertiary)),
          ),
        ]),
      ),
    ),
  );
}

class ConnectedAccountsScreen extends StatefulWidget {
  const ConnectedAccountsScreen({super.key});

  @override
  State<ConnectedAccountsScreen> createState() =>
      _ConnectedAccountsScreenState();
}

class _ConnectedAccountsScreenState extends State<ConnectedAccountsScreen>
    with WidgetsBindingObserver {
  TajikshopStatus? _status;
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

  TajikshopSso get _sso => TajikshopSso.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sso.linkChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sso.linkChanged.removeListener(_load);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Аз TajikShop баргашт — шояд пайванд ҳоло сохта шуд.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final s = await _sso.repo.status();
    if (!mounted) return;
    setState(() {
      _status = s ?? _status;
      _failed = s == null && _status == null;
      _loading = false;
    });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : null));
  }

  Future<void> _link() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr('sso.linkExplainTitle'),
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(tr('sso.linkExplain'),
            style: TextStyle(color: AppColors.textSecondary, height: 1.45)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(tr('sso.cancel'))),
          TextButton(
              key: const Key('sso-open-to-link'),
              onPressed: () => Navigator.pop(d, true),
              child: Text(tr('sso.openTajikshop'),
                  style: const TextStyle(
                      color: TajikshopBrand.primary,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (go != true) return;
    await _sso.setLinkIntent();
    await _sso.openPlain();
  }

  Future<void> _unlink() async {
    final st = _status;
    if (st == null) return;
    if (!st.hasPassword) {
      final set = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: AppColors.surface,
          content: Text(tr('sso.err.passwordRequired'),
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(tr('sso.cancel'))),
            TextButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(tr('sso.setPassword'))),
          ],
        ),
      );
      if (set == true && mounted) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const ChangePasswordScreen(firstPassword: true)));
        _load();
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr('sso.unlinkTitle'),
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(tr('sso.unlinkBody'),
            style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(tr('sso.cancel'))),
          TextButton(
              key: const Key('sso-unlink-confirm'),
              onPressed: () => Navigator.pop(d, true),
              child: Text(tr('sso.unlink'),
                  style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await _sso.repo.unlink();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.outcome == SsoOutcome.failed) {
      _snack(r.message, error: true);
    } else {
      _snack(tr('sso.unlinked'));
      _sso.linkChanged.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('sso.title'),
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr('sso.desc'),
                style: TextStyle(
                    color: AppColors.textTertiary, fontSize: 13.5, height: 1.4)),
            const SizedBox(height: 16),
            _card(),
          ],
        ),
      ),
    );
  }

  Widget _card() {
    final st = _status;
    Widget inner;
    if (_loading) {
      inner = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
            child: CircularProgressIndicator(color: TajikshopBrand.primary)),
      );
    } else if (st == null || _failed) {
      inner = Column(children: [
        Text(tr('account.err.network'),
            style: TextStyle(color: AppColors.textSecondary)),
        TextButton(onPressed: _load, child: Text(tr('sso.retry'))),
      ]);
    } else {
      inner = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TajikshopBrand.logo(size: 20),
          const Spacer(),
          _chip(st.linked),
        ]),
        const SizedBox(height: 14),
        if (st.linked) ...[
          if ((st.account?.name ?? '').isNotEmpty)
            Text(st.account!.name,
                key: const Key('sso-linked-name'),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          if ((st.account?.email ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(st.account!.email,
                key: const Key('sso-linked-email'),
                style: TextStyle(color: AppColors.textSecondary)),
          ],
          if (st.account?.linkedAt != null) ...[
            const SizedBox(height: 2),
            Text(
                tr('sso.linkedSince', {
                  'date': _fmtDate(st.account!.linkedAt!.toLocal()),
                }),
                style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
          ],
          const SizedBox(height: 16),
          _button(tr('sso.openApp'), () => openTajikshopApp(context),
              key: const Key('sso-open-app')),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              key: const Key('sso-unlink'),
              onPressed: _busy ? null : _unlink,
              child: Text(tr('sso.unlink'),
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          ),
        ] else ...[
          Text(tr('sso.linkExplain'),
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 16),
          if (!st.configured)
            Text(tr('sso.notConfigured'),
                key: const Key('sso-not-configured'),
                style: const TextStyle(color: Colors.orangeAccent)),
          if (st.configured)
            _button(tr('sso.link'), _link, key: const Key('sso-link')),
        ],
      ]);
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TajikshopBrand.primary.withOpacity(0.25)),
      ),
      child: inner,
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Widget _chip(bool linked) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (linked ? TajikshopBrand.primary : AppColors.textFaint)
              .withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(linked ? tr('sso.statusLinked') : tr('sso.statusNotLinked'),
            style: TextStyle(
                color: linked ? TajikshopBrand.primary : AppColors.textFaint,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );

  Widget _button(String label, VoidCallback onTap, {Key? key}) => SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          key: key,
          style: ElevatedButton.styleFrom(
              backgroundColor: TajikshopBrand.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: onTap,
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}
