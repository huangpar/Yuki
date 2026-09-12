import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'app_theme.dart';

// Adobe Fonts web project. Its license covers websites only: a native iOS/Android
// build needs Museo Sans licensed for app embedding and bundled as an asset instead.
const _adobeFontsKitUrl = 'https://use.typekit.net/axa4xxs.css';
const _adobeFontsFamily = 'museo-sans';

/// Registers every weight of the brand font from the Adobe Fonts kit under
/// [AppTypography.fontFamily].
Future<void> loadBrandFonts() async {
  if (!kIsWeb) return;

  final css = (await http.get(Uri.parse(_adobeFontsKitUrl))).body;
  final loader = FontLoader(AppTypography.fontFamily);
  var faces = 0;

  for (final face in RegExp(r'@font-face\s*\{(.*?)\}', dotAll: true).allMatches(css)) {
    final block = face.group(1)!;
    if (!block.contains('"$_adobeFontsFamily"')) continue;

    // Flutter's font loading expects TTF/OTF, so use the kit's OpenType source.
    final url = RegExp(r'url\("([^"]+)"\)\s*format\("opentype"\)').firstMatch(block)?.group(1);
    if (url == null) continue;

    loader.addFont(http.get(Uri.parse(url)).then((response) {
      if (response.statusCode != 200) {
        throw http.ClientException('Font request failed (${response.statusCode})', response.request?.url);
      }
      return ByteData.sublistView(response.bodyBytes);
    }));
    faces++;
  }

  if (faces == 0) {
    throw StateError('No "$_adobeFontsFamily" faces found in the Adobe Fonts kit');
  }
  await loader.load();
}
