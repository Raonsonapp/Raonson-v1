import 'package:flutter/material.dart';
import '../app/app_theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text('Сиёсати махфият',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17,
                fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _h('Сиёсати махфияти Raonson'),
          _p('Санаи навсозӣ: 1 август 2026'),
          const SizedBox(height: 16),
          _h('1. Маълумоти ҷамъоварӣшаванда'),
          _p('Raonson маълумоти зеринро ҷамъ мекунад:\n'
              '• Маълумоти шахсӣ: ном, номи корбарӣ, email, рақами телефон\n'
              '• Мӯҳтаво: акс, видео, паёмҳо, шарҳҳо, ҳикояҳо\n'
              '• Маълумоти дастгоҳ: ID-и дастгоҳ, модел, системаи оператсионӣ\n'
              '• Ҷойгиршавӣ: танҳо ҳангоми мубодила дар чат (бо иҷозат)\n'
              '• Контактҳо: танҳо рақамҳо барои ёфтани дӯстон (бо иҷозат, нигоҳ дошта намешаванд)'),
          const SizedBox(height: 12),
          _h('2. Истифодаи маълумот'),
          _p('Мо маълумотро барои мақсадҳои зерин истифода мебарем:\n'
              '• Кор кардани ҳисоб ва хизматрасонӣ\n'
              '• Нишон додани мӯҳтавои мувофиқ\n'
              '• Таблиғоти шахсигардонидашуда (Yandex Ads SDK)\n'
              '• Огоҳиҳои push (Firebase Cloud Messaging)\n'
              '• Беҳтар кардани барнома ва ислоҳи хатогиҳо'),
          const SizedBox(height: 12),
          _h('3. SDK-ҳои тарафи сеюм'),
          _p('Raonson SDK-ҳои зеринро истифода мебарад:\n'
              '• Firebase (аутентификатсия, нигоҳдории файл, push-огоҳиҳо)\n'
              '• Yandex Mobile Ads (таблиғот)\n'
              '• Agora RTC (зангҳои видеоӣ ва овозӣ)\n\n'
              'Ҳар як SDK сиёсати махфияти худро дорад.'),
          const SizedBox(height: 12),
          _h('4. Нигоҳдории маълумот'),
          _p('Маълумоти шумо дар серверҳои бехатар нигоҳ дошта мешавад. '
              'Шумо метавонед ҳар вақт ҳисоби худро нест кунед, '
              'ки тамоми маълумоти шуморо аз серверҳо пок мекунад.'),
          const SizedBox(height: 12),
          _h('5. Ҳуқуқи корбар'),
          _p('Шумо ҳуқуқ доред:\n'
              '• Маълумоти худро бинед ва тағйир диҳед\n'
              '• Ҳисоби худро нест кунед\n'
              '• Аз огоҳиҳо даст кашед\n'
              '• Розигии таблиғотро бекор кунед'),
          const SizedBox(height: 12),
          _h('6. Кӯдакон'),
          _p('Raonson барои кӯдакони зери 13 сол пешбинӣ нашудааст. '
              'Мо дониста маълумоти кӯдакони зери 13-ро ҷамъ намекунем.'),
          const SizedBox(height: 12),
          _h('7. Тамос'),
          _p('Барои саволҳо дар бораи махфият:\nEmail: support@raonson.app'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text('Шартҳои истифода',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17,
                fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _h('Шартҳои истифодаи Raonson'),
          _p('Санаи навсозӣ: 1 август 2026'),
          const SizedBox(height: 16),
          _h('1. Қабули шартҳо'),
          _p('Бо истифодаи Raonson шумо бо ин шартҳо розӣ мешавед. '
              'Агар розӣ набошед, лутфан барномаро истифода набаред.'),
          const SizedBox(height: 12),
          _h('2. Ҳисоб'),
          _p('• Синни шумо бояд 13 ва аз он болотар бошад\n'
              '• Шумо масъули нигоҳдории рамзи ҳисоби худ ҳастед\n'
              '• Як шахс то 3 ҳисоб дошта метавонад'),
          const SizedBox(height: 12),
          _h('3. Мӯҳтаво'),
          _p('Шумо масъули мӯҳтавое ҳастед, ки нашр мекунед. '
              'Мӯҳтавои зерин манъ аст:\n'
              '• Порнография ва мӯҳтавои ҷинсӣ\n'
              '• Хушунат ва таҳдид\n'
              '• Нафрат ва табъиз\n'
              '• Спам ва фиребгарӣ\n'
              '• Вайрон кардани ҳуқуқи муаллиф'),
          const SizedBox(height: 12),
          _h('4. Шикоят'),
          _p('Шумо метавонед мӯҳтаво ва корбаронро шикоят кунед. '
              'Мо шикоятҳоро баррасӣ мекунем ва мӯҳтавои вайронкунандаро нест мекунем.'),
          const SizedBox(height: 12),
          _h('5. Нест кардани ҳисоб'),
          _p('Шумо метавонед ҳар вақт ҳисоби худро нест кунед. '
              'Пас аз нест кардан, тамоми маълумот пок мешавад ва қобили барқарорсозӣ нест.'),
          const SizedBox(height: 12),
          _h('6. Тағйироти шартҳо'),
          _p('Мо метавонем ин шартҳоро тағйир диҳем. '
              'Дар ин сурат, мо шуморо тавассути огоҳӣ хабардор мекунем.'),
          const SizedBox(height: 12),
          _h('7. Тамос'),
          _p('Барои саволҳо: support@raonson.app'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

Widget _h(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600)));

Widget _p(String text) => Text(text,
    style: TextStyle(
        color: AppColors.textSecondary, fontSize: 14, height: 1.6));
