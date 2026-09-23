import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/wellbeing/usage_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// «Вақти шумо» — мисли Instagram.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('вақт ба рӯзи дуруст ҷамъ мешавад', () {
    final t = UsageTracker.instance;
    t.days.value = {};
    final d = DateTime(2026, 9, 23, 10);
    t.add(d, 600);
    t.add(d.add(const Duration(hours: 2)), 300);
    expect(t.secondsOn(d), 900);
  });

  test('танҳо 7 рӯзи охир нигоҳ дошта мешавад', () {
    final t = UsageTracker.instance;
    t.days.value = {};
    final d = DateTime(2026, 9, 23);
    t.add(d.subtract(const Duration(days: 10)), 100);
    t.add(d, 50);
    expect(t.days.value.length, 1);
    expect(t.week(d).length, 7);
    expect(t.week(d).last.value, 50);
  });

  test('формат', () {
    expect(formatUsage(59 * 60), '59д');
    expect(formatUsage(3600 + 5 * 60), '1с 5д');
  });
}
