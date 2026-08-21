import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Community Guidelines',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _header(),
          const SizedBox(height: 20),
          _section('1. Эҳтиром ва Хушмуомилагӣ',
            'Ҳамаи корбарон бояд бо эҳтиром муносибат кунанд. '
            'Нафрат, таҳқир, тамасхур ва дигар рафтори бадмуомила '
            'манъ аст.'),
          _section('2. Бехатарии кӯдакон', null, bullets: [
            'Raonson сиёсати нулл-толеранс ба истисмори кӯдакон (CSAE/CSAM) дорад',
            'Ҳар мӯҳтавое, ки кӯдаконро ба хатар мегузорад, фавран нест карда мешавад',
            'Ҳисобҳои вайронкунанда дарҳол маҳдуд карда мешаванд',
            'Синни ҳадди ақал барои истифода: 13 сол',
          ]),
          _section('3. Мӯҳтавои манъшуда', null, bullets: [
            'Порнография ва мӯҳтавои ошкоро ҷинсӣ',
            'Зӯроварӣ, ваҳшоният ва тарғиби ҷангу терроризм',
            'Мӯҳтавои нафратангез алайҳи нажод, дин, миллат ё ҷинс',
            'Маводи CSAM/CSAE (бехатарии кӯдакон)',
            'Маълумоти шахсии дигарон бе розигӣ',
            'Спам, фиребгарӣ ва мӯҳтавои гумроҳкунанда',
            'Тарғиби маводи мухаддир ё фаъолияти ғайриқонунӣ',
          ]),
          _section('4. Моликият ва ҳуқуқи муаллиф',
            'Танҳо мӯҳтавоеро нашр кунед, ки ҳуқуқи он ба шумо тааллуқ '
            'дорад ё иҷозаи истифодаро доред. Вайронкунии ҳуқуқи муаллиф '
            'боиси нест кардани мӯҳтаво ва маҳдудкунии ҳисоб мешавад.'),
          _section('5. Спам ва худтаблиғ',
            'Фиристодани паёмҳои такрорӣ, линкҳои нолозим ё мӯҳтавои '
            'автоматӣ манъ аст. Худтаблиғ бояд мӯътадил ва дар '
            'доираи қоидаҳо бошад.'),
          _section('6. Маҳрамият ва маълумоти шахсӣ',
            'Маълумоти шахсии дигар шахсонро бе розигии онҳо '
            'нашр накунед. Ин шомили суратҳо, рақами телефон, '
            'суроға ва маълумоти молиявӣ мешавад.'),
          _section('7. Тиҷорат ва Tajikshop',
            'Фурӯшандагон бояд маҳсулоти ҳақиқиро нишон диҳанд. '
            'Фиреб дар нарх, сифат ё тавсиф боиси маҳдудкунии '
            'ҳисоб мешавад. Комиссияи 5% ба ҳар фурӯш татбиқ мешавад.'),
          _section('8. Шикоят кардан',
            'Агар мӯҳтавои вайронкунанда бинед, лутфан тавассути '
            'тугмаи шикоят (🚩) хабар диҳед. Барои бехатарии кӯдакон '
            'категорияи "Бехатарии кӯдакон"-ро интихоб кунед — '
            'ин шикоятҳо дар навбати аввал баррасӣ мешаванд.'),
          _section('9. Ҷаримаҳо', null, bullets: [
            'Огоҳӣ барои вайронкунии аввал',
            'Маҳдудкунии муваққатии ҳисоб барои вайронкунии такрорӣ',
            'Нест кардани мӯҳтаво барои вайронкуниҳои ҷиддӣ',
            'Маҳдудкунии доимии ҳисоб барои CSAE/CSAM ё вайронкуниҳои вазнин',
            'Ҳамкорӣ бо мақомоти ҳуқуқӣ дар асоси дархости расмӣ',
          ]),
          _section('10. Тамос',
            'Барои саволҳо ё хабардиҳӣ:\n'
            'ehsonmahmadmurodov@gmail.com'),
          const SizedBox(height: 16),
          Text('Санаи навсозӣ: Август 2026',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.neonBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(AppIcons.people_outline_rounded, color: AppColors.neonBlue, size: 32),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Community Guidelines',
                style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Қоидаҳо барои ҷомеаи бехатар ва дӯстона.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        )),
      ]),
    );
  }

  Widget _section(String title, String? body, {List<String>? bullets}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        if (body != null)
          Text(body, style: TextStyle(color: AppColors.textSecondary,
              fontSize: 14, height: 1.5)),
        if (bullets != null)
          ...bullets.map((b) => Padding(
            padding: const EdgeInsets.only(left: 8, top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ', style: TextStyle(color: AppColors.textSecondary,
                  fontSize: 14)),
              Expanded(child: Text(b,
                  style: TextStyle(color: AppColors.textSecondary,
                      fontSize: 14, height: 1.4))),
            ]),
          )),
      ]),
    );
  }
}
