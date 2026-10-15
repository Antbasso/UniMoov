import 'dart:io';

import 'tokens_codegen.dart';

const tokensPath = '../docs/design-system/tokens.json';
const outputPath = 'lib/core/theme/tokens.g.dart';

Future<void> main() async {
  final source = File(tokensPath).readAsStringSync();
  File(outputPath).writeAsStringSync(generateTokens(source));
  final format = await Process.run('dart', ['format', '--line-length', '100', outputPath]);
  if (format.exitCode != 0) throw ProcessException('dart', ['format'], '${format.stderr}');
  stdout.writeln('$outputPath généré depuis $tokensPath');
}
