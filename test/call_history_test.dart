// test/call_history_test.dart
// Экрани «Зангҳо»: сатрҳо (воридотӣ/содиротӣ/аздастрафта бо давомнокӣ),
// саҳифабандӣ, занги дубора, «Паём», нест кардан, холӣ ва хато.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raonson/calls/active_call.dart';
import 'package:raonson/calls/call_history.dart';
import 'package:raonson/calls/call_payload.dart';
import 'package:raonson/calls/call_strings.dart';
import 'package:raonson/calls/missed_call_notifier.dart';
import 'package:raonson/models/user_model.dart';

Map<String, dynamic> row(String id, String user,
        {String dir = 'incoming',
        String status = 'completed',
        String type = 'voice',
        int dur = 0}) =>
    {
      'id': id,
      'direction': dir,
      'status': status,
      'type': type,
      'videoUsed': false,
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      'durationSec': dur,
      'peer': {'id': 'u_$user', '_id': 'u_$user', 'username': user, 'avatar': ''},
    };

class FakeRepo extends CallHistoryRepository {
  FakeRepo(this.pages);
  final List<CallHistoryPage> pages;
  final cursors = <String?>[];
  final deleted = <String>[];
  bool cleared = false;
  bool fail = false;

  @override
  Future<CallHistoryPage> fetch({String? cursor, int limit = 30}) async {
    cursors.add(cursor);
    if (fail) throw Exception('offline');
    final i = cursor == null ? 0 : int.parse(cursor);
    return pages[i];
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);
  @override
  Future<void> clear() async => cleared = true;
}

CallHistoryPage page(List<Map<String, dynamic>> rows, String? next) => (
      items: rows.map((r) => CallLogEntry.fromJson(r)!).toList(),
      next: next,
    );

void main() {
  group('CallLogEntry', () {
    test('аз JSON-и сервер', () {
      final e = CallLogEntry.fromJson(
          row('1', 'ali', dir: 'outgoing', type: 'video', dur: 125))!;
      expect(e.outgoing, isTrue);
      expect(e.isVideo, isTrue);
      expect(e.peer.username, 'ali');
      expect(e.subtitle, '${CallStrings.t('outgoing')} · 2:05');
    });

    test('аздастрафта ва сатри бе ҳамсӯҳбат', () {
      final e = CallLogEntry.fromJson(row('2', 'vali', status: 'missed'))!;
      expect(e.missed, isTrue);
      expect(e.subtitle, CallStrings.t('missedShort'));
      expect(CallLogEntry.fromJson({'id': 'x'}), isNull);
    });

    test('давомнокӣ', () {
      expect(formatDuration(5), '0:05');
      expect(formatDuration(3725), '1:02:05');
    });
  });

  group('огоҳиномаи «аздастрафта»', () {
    test('payload бармегардад; дигар payload — не', () {
      const c = IncomingCall(
          callId: '0f8fad5b-d9cb-469f-a165-70867728950e',
          callerId: 'u1',
          callerName: 'ali',
          callerAvatar: '',
          isVideo: true);
      final back = MissedCallNotifier.parse(MissedCallNotifier.payloadFor(c))!;
      expect(back.callerId, 'u1');
      expect(back.isVideo, isTrue);
      expect(MissedCallNotifier.parse('chat:abc'), isNull);
      expect(MissedCallNotifier.parse('missedcall:{broken'), isNull);
      expect(MissedCallNotifier.handle('chat:abc', null, null), isFalse);
    });
  });

  group('CallHistoryScreen', () {
    Future<void> pump(WidgetTester tester, Widget w) async {
      await tester.pumpWidget(MaterialApp(home: w));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('сатрҳо, занги дубора, «Паём»', (tester) async {
      final calls = <String>[];
      final msgs = <String>[];
      final repo = FakeRepo([
        page([
          row('1', 'ali', status: 'missed'),
          row('2', 'vali', dir: 'outgoing', type: 'video', dur: 65),
        ], null),
      ]);
      await pump(
          tester,
          CallHistoryScreen(
            repository: repo,
            onCall: (UserModel p, CallType t) => calls.add('${p.username}:${t.name}'),
            onMessage: (p) => msgs.add(p.username),
          ));
      expect(find.text('ali'), findsOneWidget);
      expect(find.text('vali'), findsOneWidget);
      expect(find.textContaining(CallStrings.t('missedShort')), findsOneWidget);
      expect(find.textContaining('1:05'), findsOneWidget);

      await tester.tap(find.byKey(const Key('history_call_2')));
      await tester.tap(find.text('ali'));
      await tester.tap(find.byKey(const Key('history_msg_1')));
      expect(calls, ['vali:video', 'ali:voice']);
      expect(msgs, ['ali']);
    });

    testWidgets('саҳифаи дуюм ҳангоми ҳаракат ба поён', (tester) async {
      final repo = FakeRepo([
        page([for (var i = 0; i < 20; i++) row('a$i', 'u$i')], '1'),
        page([row('b0', 'last')], null),
      ]);
      await pump(tester, CallHistoryScreen(repository: repo));
      expect(repo.cursors, [null]);
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump();
      await tester.pump();
      expect(repo.cursors, [null, '1']);
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump();
      expect(find.text('last'), findsOneWidget);
      expect(repo.cursors, [null, '1'], reason: 'саҳифаи охир — дигар дархост не');
    });

    testWidgets('холӣ', (tester) async {
      await pump(tester, CallHistoryScreen(repository: FakeRepo([page([], null)])));
      expect(find.byKey(const Key('history_empty')), findsOneWidget);
    });

    testWidgets('хато → «Аз нав»', (tester) async {
      final repo = FakeRepo([page([row('1', 'ali')], null)])..fail = true;
      await pump(tester, CallHistoryScreen(repository: repo));
      expect(find.byKey(const Key('history_retry')), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.byKey(const Key('history_retry')));
      await tester.pump();
      await tester.pump();
      expect(find.text('ali'), findsOneWidget);
    });

    testWidgets('нест кардан (swipe) ва тоза кардани ҳама', (tester) async {
      final repo = FakeRepo([
        page([row('1', 'ali'), row('2', 'vali')], null)
      ]);
      await pump(tester, CallHistoryScreen(repository: repo));
      await tester.drag(find.text('ali'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('ali'), findsNothing);
      expect(repo.deleted, ['1']);
      await tester.tap(find.byKey(const Key('history_clear')));
      await tester.pump();
      expect(repo.cleared, isTrue);
      expect(find.byKey(const Key('history_empty')), findsOneWidget);
    });
  });
}
