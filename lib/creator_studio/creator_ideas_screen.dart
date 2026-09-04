// lib/creator_studio/creator_ideas_screen.dart
// Ғояҳои мӯҳтаво — пешниҳод аз рӯи мавзӯъҳои ВОҚЕИИ эҷодкор.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'creator_studio_repository.dart';

class CreatorIdeasScreen extends StatefulWidget {
  const CreatorIdeasScreen({super.key});
  @override
  State<CreatorIdeasScreen> createState() => _CreatorIdeasScreenState();
}

class _CreatorIdeasScreenState extends State<CreatorIdeasScreen> {
  final _topic = TextEditingController();
  List<ContentIdea>? _ideas;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final list = await CreatorStudioRepository.instance
          .ideas(topic: _topic.text.trim());
      if (!mounted) return;
      setState(() {
        _ideas = list;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
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
          title: Text(tr('cs.ideas'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            TextField(
              controller: _topic,
              maxLength: 60,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: tr('cs.ideasSub'),
                hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 13),
                filled: true,
                fillColor: AppColors.card,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _generate(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _busy ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(tr('cs.generateIdeas'),
                        style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 18),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: AppColors.red, fontSize: 13))
            else if (_ideas != null && _ideas!.isEmpty)
              // AI метавонад ҷавоб надиҳад — ин хато нест, вале
              // ғояи сохта ҳам нишон дода намешавад.
              Text(tr('cs.ideasEmpty'),
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 13))
            else if (_ideas != null)
              for (final i in _ideas!) _ideaCard(i),
          ],
        ),
      );

  Widget _ideaCard(ContentIdea i) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i.title,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            if (i.hook.isNotEmpty) ...[
              const SizedBox(height: 8),
              _labeled(tr('cs.hook'), i.hook),
            ],
            if (i.idea.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(i.idea,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.35)),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 4, children: [
              if (i.format.isNotEmpty) _meta(tr('cs.format'), i.format),
              if (i.duration.isNotEmpty) _meta(tr('cs.duration'), i.duration),
            ]),
            if (i.cta.isNotEmpty) ...[
              const SizedBox(height: 8),
              _labeled(tr('cs.cta'), i.cta),
            ],
            if (i.hashtags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(i.hashtags.join(' '),
                  style: TextStyle(color: AppColors.neonBlue, fontSize: 12.5)),
            ],
          ],
        ),
      );

  Widget _labeled(String label, String value) => RichText(
        text: TextSpan(children: [
          TextSpan(
              text: '$label: ',
              style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          TextSpan(
              text: value,
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
        ]),
      );

  Widget _meta(String label, String value) => Text('$label: $value',
      style: TextStyle(color: AppColors.textFaint, fontSize: 11.5));
}
