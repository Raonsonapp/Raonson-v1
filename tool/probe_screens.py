#!/usr/bin/env python3
"""Ҳар экрани бе-параметрро ҳамчун саҳифаи АЛОҲИДА мекушояд ва хатоҳоро чоп мекунад.

Бо ҳамин усул хатои «экрани сиёҳ ҳангоми фиристодан ба чат» ёфт шуд.
Истифода:  python3 tool/probe_screens.py && flutter test test/_probe_screens_test.dart
Баъд файли test/_probe_screens_test.dart-ро нест кунед.
"""
import re, pathlib
screens = []
for f in sorted(pathlib.Path('lib').rglob('*.dart')):
    s = f.read_text(errors='ignore')
    for m in re.finditer(r'class (\w+(?:Screen|Page)) extends (StatefulWidget|StatelessWidget)', s):
        n = m.group(1)
        if re.search(r'const\s+' + n + r'\s*\(\s*\{\s*super\.key\s*,?\s*\}\s*\)', s):
            screens.append((n, str(f)))
files = sorted({p for _, p in screens}); pref = {p: f"s{i}" for i, p in enumerate(files)}
imports = "\n".join(f"import 'package:raonson/{p[4:]}' as {pref[p]};" for p in files)
cases = ",\n".join(f"  '{n}': () => const {pref[p]}.{n}()" for n, p in screens)
pathlib.Path('test/_probe_screens_test.dart').write_text(f"""import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
{imports}
final Map<String, Widget Function()> screens = {{
{cases},
}};
void main() {{
  for (final e in screens.entries) {{
    testWidgets(e.key, (t) async {{
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) {{ final m = d.exceptionAsString();
        if (!m.contains('overflowed')) errors.add(m.split('\\n').first); }};
      await t.pumpWidget(MaterialApp(home: Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => e.value())),
          child: const Text('go')))));
      await t.tap(find.text('go'));
      for (var i = 0; i < 10; i++) {{ await t.pump(const Duration(milliseconds: 100)); }}
      FlutterError.onError = old;
      // ignore: avoid_print
      if (errors.isNotEmpty) print('❌ ${{e.key}}: ${{errors.first}}');
    }});
  }}
}}
""")
print(f"{len(screens)} экран → test/_probe_screens_test.dart")
