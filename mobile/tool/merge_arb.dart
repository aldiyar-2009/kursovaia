// Merges lib/l10n/parts/*_<locale>.arb into lib/l10n/app_<locale>.arb.
// Temporary helper used while several agents add strings in parallel.
import 'dart:convert';
import 'dart:io';

const locales = ['ru', 'en', 'kk'];
const template = 'ru';

void main() {
  final partsDir = Directory('lib/l10n/parts');
  final merged = <String, Map<String, dynamic>>{};

  for (final locale in locales) {
    final out = <String, dynamic>{'@@locale': locale};
    final files = partsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_$locale.arb'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in data.entries) {
        if (entry.key == '@@locale') continue;
        if (out.containsKey(entry.key)) {
          stderr.writeln('DUPLICATE ${entry.key} in ${file.path}');
          exit(1);
        }
        out[entry.key] = entry.value;
      }
    }
    merged[locale] = out;
  }

  final source = merged[template]!;
  for (final locale in locales.where((l) => l != template)) {
    final target = merged[locale]!;
    for (final key in source.keys) {
      if (key == '@@locale' || key.startsWith('@')) continue;
      if (!target.containsKey(key)) {
        stdout.writeln('MISSING $locale $key');
        target[key] = source[key];
      }
    }
  }

  const encoder = JsonEncoder.withIndent('  ');
  for (final locale in locales) {
    File('lib/l10n/app_$locale.arb')
        .writeAsStringSync('${encoder.convert(merged[locale])}\n');
  }
}
