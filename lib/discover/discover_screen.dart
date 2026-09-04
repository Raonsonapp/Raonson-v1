// lib/discover/discover_screen.dart
// ════════════════════════════════════════════════════════════════════
//  «Кашфи имрӯз».
//
//  Ҳар бахш аз маълумоти ВОҚЕИИ сервер меояд. Бахши холӣ пинҳон
//  мешавад — рӯйхати холӣ ба корбар сабаби бозгашт намедиҳад.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/app_settings.dart';
import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../profile/profile_screen.dart';

/// Тренди як мавзӯъ.
class TrendItem {
  final String slug;
  final int current;
  /// null = фоиз маънодор нест ва НИШОН ДОДА НАМЕШАВАД.
  final double? changePct;

  const TrendItem({
    required this.slug,
    required this.current,
    required this.changePct,
  });

  factory TrendItem.fromJson(Map<String, dynamic> j) => TrendItem(
        slug: (j['slug'] ?? '').toString(),
        current: (j['current'] as num?)?.toInt() ?? 0,
        changePct: (j['changePct'] as num?)?.toDouble(),
      );
}

/// Эҷодкор дар рӯйхати кашфиёт.
class DiscoverPerson {
  final String userId, username, avatar, bio, reason;
  final bool verified;
  final int followers, similarity;

  const DiscoverPerson({
    required this.userId,
    required this.username,
    required this.avatar,
    required this.bio,
    required this.reason,
    required this.verified,
    required this.followers,
    required this.similarity,
  });

  factory DiscoverPerson.fromJson(Map<String, dynamic> j) => DiscoverPerson(
        userId: (j['userId'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        avatar: (j['avatar'] ?? '').toString(),
        bio: (j['bio'] ?? '').toString(),
        reason: (j['reason'] ?? '').toString(),
        verified: j['verified'] == true,
        followers: (j['followersCount'] as num?)?.toInt() ?? 0,
        similarity: (j['similarity'] as num?)?.toInt() ?? 0,
      );
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<TrendItem> _trends = const [];
  List<DiscoverPerson> _rising = const [];
  List<DiscoverPerson> _suggested = const [];
  List<Map<String, dynamic>> _topics = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await ApiClient.instance.get('/discover');
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) {
        throw Exception((b['message'] ?? '').toString());
      }
      List<T> parse<T>(String key, T Function(Map<String, dynamic>) f) =>
          ((b[key] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => f(e.cast<String, dynamic>()))
              .toList();

      if (!mounted) return;
      setState(() {
        _trends = parse('trends', TrendItem.fromJson);
        _rising = parse('risingCreators', DiscoverPerson.fromJson);
        _suggested = parse('suggestedPeople', DiscoverPerson.fromJson);
        _topics = ((b['topicsForYou'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(AppIcons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(tr('dc.title'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700)),
        ),
        body: _body(),
      );

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.error_outline, size: 40, color: AppColors.red),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            TextButton(onPressed: _load, child: Text(tr('common.retry'))),
          ]),
        ),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());

    final lang = AppSettingsState.instance.lang;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _section(tr('dc.trending')),
          if (_trends.isEmpty)
            _hint(tr('dc.noTrends'))
          else
            Wrap(spacing: 8, runSpacing: 8, children: _trends.map(_trendChip).toList()),
          if (_topics.isNotEmpty) ...[
            const SizedBox(height: 22),
            _section(tr('dc.topicsForYou')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _topics.map((t) {
                final name = _topicName(t, lang);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(name,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                );
              }).toList(),
            ),
          ],
          if (_rising.isNotEmpty) ...[
            const SizedBox(height: 22),
            _section(tr('dc.risingCreators')),
            for (final p in _rising) _personTile(p, showReason: true),
          ],
          if (_suggested.isNotEmpty) ...[
            const SizedBox(height: 22),
            _section(tr('dc.suggested')),
            for (final p in _suggested) _personTile(p, showReason: false),
          ],
          if (_rising.isEmpty && _suggested.isEmpty) ...[
            const SizedBox(height: 22),
            _hint(tr('dc.noPeople')),
          ],
        ],
      ),
    );
  }

  String _topicName(Map<String, dynamic> t, String lang) {
    final key = lang == 'ru'
        ? 'nameRu'
        : lang == 'en'
            ? 'nameEn'
            : 'nameTj';
    final v = (t[key] ?? '').toString();
    return v.isEmpty ? (t['slug'] ?? '').toString() : v;
  }

  /// Тренд бо фоиз — ё бе он, вақте фоиз маънодор нест.
  Widget _trendChip(TrendItem t) {
    final up = (t.changePct ?? 0) >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(t.slug,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        if (t.changePct != null)
          Text('${up ? '+' : ''}${t.changePct!.round()}%',
              style: TextStyle(
                  color: up ? AppColors.verified : AppColors.textTertiary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700))
        else
          // Фоиз маънодор нест — ба ҷои рақами гумроҳкунанда
          // танҳо «Нав» нишон дода мешавад.
          Text(tr('dc.newTopic'),
              style: TextStyle(
                  color: AppColors.neonBlue,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _personTile(DiscoverPerson p, {required bool showReason}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: p.userId)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(children: [
                ClipOval(
                  child: p.avatar.isEmpty
                      ? Container(
                          width: 44,
                          height: 44,
                          color: AppColors.divider,
                          child: Icon(AppIcons.person,
                              color: AppColors.textFaint, size: 20))
                      : CachedNetworkImage(
                          imageUrl: p.avatar,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                              width: 44, height: 44, color: AppColors.divider),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(p.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (p.verified) ...[
                          const SizedBox(width: 4),
                          Icon(AppIcons.verified_rounded,
                              size: 13, color: AppColors.verified),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        // Сабаб аз сигнали ВОҚЕИИ сервер меояд.
                        showReason && p.reason.isNotEmpty
                            ? tr('dc.reason.${p.reason}')
                            : (p.similarity > 0
                                ? tr('aifeed.similarity', {'n': p.similarity})
                                : (p.bio.isEmpty ? '' : p.bio)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      );

  Widget _hint(String text) => Text(text,
      style: TextStyle(color: AppColors.textTertiary, fontSize: 13));
}
