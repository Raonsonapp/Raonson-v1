// lib/core/i18n/strings.dart
// ════════════════════════════════════════════════════════════════════
//  Lightweight i18n — Тоҷикӣ / Русский / English
//  Usage:  Text(tr('settings.title'))
//  The active language comes from AppSettingsState.instance.lang.
//  Because MaterialApp rebuilds on AppSettingsState changes, every
//  widget that calls tr() re-renders instantly when the language flips.
// ════════════════════════════════════════════════════════════════════
import '../../app/app_settings.dart';

/// Translate [key] into the currently selected app language.
/// Falls back to Tajik, then to the key itself.
String tr(String key) {
  final lang = AppSettingsState.instance.lang;
  final table = _strings[lang] ?? _strings['tj']!;
  return table[key] ?? _strings['tj']?[key] ?? key;
}

const Map<String, Map<String, String>> _strings = {
  // ─────────────────────────────────────────────  TAJIK
  'tj': {
    'settings.title':            'Танзимот',
    'section.account':           'Аккаунт',
    'account.editProfile':       'Таҳрири профил',
    'account.changePassword':    'Иваз кардани рамз',
    'account.email':             'Почтаи электронӣ',
    'account.emailSub':          'Почтаро тағир диҳ',
    'account.phone':             'Рақами телефон',
    'section.appearance':        'Намуд',
    'appearance.theme':          'Мавзӯъ',
    'theme.dark':                'Торик',
    'theme.light':               'Равшан',
    'section.language':          'Забон',
    'language.app':              'Забони барнома',
    'section.privacy':           'Махфият',
    'privacy.settings':          'Танзимоти махфият',
    'section.notifications':     'Огоҳиҳо',
    'notifications.app':         'Огоҳиҳои барнома',
    'section.security':          'Амнияти аккаунт',
    'security.settings':         'Танзимоти амният',
    'account.logout':            'Хуруҷ аз аккаунт',
    'account.delete':            'Аккаунтро нест кун',
    'logout.title':              'Хуруҷ аз аккаунт?',
    'logout.body':               'Шумо аз аккаунти худ мебароед.',
    'logout.action':             'Хуруҷ',
    'delete.title':              'Аккаунтро нест кунем?',
    'delete.body':               'Ин амал бебозгашт аст. Ҳама маълумот нест мешавад.',
    'delete.action':             'Нест кун',
    'common.cancel':             'Бекор',
  },
  // ─────────────────────────────────────────────  RUSSIAN
  'ru': {
    'settings.title':            'Настройки',
    'section.account':           'Аккаунт',
    'account.editProfile':       'Редактировать профиль',
    'account.changePassword':    'Изменить пароль',
    'account.email':             'Электронная почта',
    'account.emailSub':          'Изменить почту',
    'account.phone':             'Номер телефона',
    'section.appearance':        'Оформление',
    'appearance.theme':          'Тема',
    'theme.dark':                'Тёмная',
    'theme.light':               'Светлая',
    'section.language':          'Язык',
    'language.app':              'Язык приложения',
    'section.privacy':           'Конфиденциальность',
    'privacy.settings':          'Настройки конфиденциальности',
    'section.notifications':     'Уведомления',
    'notifications.app':         'Уведомления приложения',
    'section.security':          'Безопасность аккаунта',
    'security.settings':         'Настройки безопасности',
    'account.logout':            'Выйти из аккаунта',
    'account.delete':            'Удалить аккаунт',
    'logout.title':              'Выйти из аккаунта?',
    'logout.body':               'Вы выйдете из своего аккаунта.',
    'logout.action':             'Выйти',
    'delete.title':              'Удалить аккаунт?',
    'delete.body':               'Это действие необратимо. Все данные будут удалены.',
    'delete.action':             'Удалить',
    'common.cancel':             'Отмена',
  },
  // ─────────────────────────────────────────────  ENGLISH
  'en': {
    'settings.title':            'Settings',
    'section.account':           'Account',
    'account.editProfile':       'Edit profile',
    'account.changePassword':    'Change password',
    'account.email':             'Email',
    'account.emailSub':          'Change email',
    'account.phone':             'Phone number',
    'section.appearance':        'Appearance',
    'appearance.theme':          'Theme',
    'theme.dark':                'Dark',
    'theme.light':               'Light',
    'section.language':          'Language',
    'language.app':              'App language',
    'section.privacy':           'Privacy',
    'privacy.settings':          'Privacy settings',
    'section.notifications':     'Notifications',
    'notifications.app':         'App notifications',
    'section.security':          'Account security',
    'security.settings':         'Security settings',
    'account.logout':            'Log out',
    'account.delete':            'Delete account',
    'logout.title':              'Log out?',
    'logout.body':               'You will be logged out of your account.',
    'logout.action':             'Log out',
    'delete.title':              'Delete account?',
    'delete.body':               'This action is irreversible. All data will be deleted.',
    'delete.action':             'Delete',
    'common.cancel':             'Cancel',
  },
};

/// Human-readable language name (always shown in its own script).
String langDisplayName(String code) {
  switch (code) {
    case 'ru': return 'Русский';
    case 'en': return 'English';
    default:   return 'Тоҷикӣ';
  }
}
