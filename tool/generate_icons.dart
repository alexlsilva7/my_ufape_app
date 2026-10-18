import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

const _revision = '20261018-portrait';
const _canvasSize = 1024;

/// Launcher generators resize their source to a square. Prepare a square
/// canvas first so the original portrait crest never gets stretched.
img.Image _canvas(img.Image source, int crestHeight, {bool opaque = false}) {
  final result = img.Image(
    width: _canvasSize,
    height: _canvasSize,
    numChannels: 4,
  );
  if (opaque) img.fill(result, color: img.ColorRgba8(248, 250, 252, 255));
  final crest = img.copyResize(
    source,
    height: crestHeight,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    result,
    crest,
    dstX: (_canvasSize - crest.width) ~/ 2,
    dstY: (_canvasSize - crest.height) ~/ 2,
  );
  return result;
}

void _save(String path, img.Image image) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
}

void main() {
  if (!File('flutter_launcher_icons.yaml').existsSync()) {
    stderr.writeln(
      'Execute na pasta flutter/: fvm dart run tool/generate_icons.dart',
    );
    exitCode = 1;
    return;
  }
  final source = img.decodePng(
    File('assets/images/my_ufape_logo_azul.png').readAsBytesSync(),
  );
  if (source == null) {
    throw StateError('Não foi possível ler o brasão original.');
  }
  final transparent = _canvas(source, 896);
  final store = _canvas(source, 780, opaque: true);
  final maskable = _canvas(source, 640, opaque: true);
  _save('assets/launcher/launcher_icon.png', transparent);
  _save('assets/launcher/launcher_icon_store.png', store);

  final generator = Process.runSync(
    Platform.resolvedExecutable,
    ['run', 'flutter_launcher_icons'],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  stdout.write(generator.stdout);
  stderr.write(generator.stderr);
  if (generator.exitCode != 0) {
    exitCode = generator.exitCode;
    return;
  }

  // Embed native small sizes instead of making the taskbar downsample 256 px.
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(
    img.IcoEncoder().encodeImages([
      for (final size in [16, 24, 32, 48, 64, 128, 256])
        img.copyResize(
          transparent,
          width: size,
          interpolation: img.Interpolation.average,
        ),
    ]),
  );

  // Maskable PWA icons need their own safe area and an opaque background.
  for (final size in [192, 512]) {
    _save(
      'web/icons/Icon-maskable-$size.png',
      img.copyResize(
        maskable,
        width: size,
        interpolation: img.Interpolation.average,
      ),
    );
  }
  _save(
    'web/icons/apple-touch-icon.png',
    img.copyResize(store, width: 192, interpolation: img.Interpolation.average),
  );

  final manifestFile = File('web/manifest.json');
  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  for (final icon in manifest['icons'] as List) {
    icon['src'] = '${(icon['src'] as String).split('?').first}?v=$_revision';
  }
  manifestFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('    ').convert(manifest)}\n',
  );
  final htmlFile = File('web/index.html');
  var html = htmlFile.readAsStringSync();
  html = html.replaceAll(
    RegExp(r'favicon\.png(?:\?[^"\s]*)?'),
    'favicon.png?v=$_revision',
  );
  html = html.replaceAll(
    RegExp(r'href="icons/(?:Icon-192|apple-touch-icon)\.png(?:\?[^"\s]*)?"'),
    'href="icons/apple-touch-icon.png?v=$_revision"',
  );
  html = html.replaceAll(
    RegExp(r'href="manifest\.json(?:\?[^"\s]*)?"'),
    'href="manifest.json?v=$_revision"',
  );
  htmlFile.writeAsStringSync(html);

  stdout.writeln(
    'Brasão ${source.width}×${source.height}: proporção preservada nos ícones de Windows, Android, iOS e Web.',
  );
}
