import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

// Profile IDs may contain '/', e.g. the published Letras profile "Perfil 4/2024".
String safeFileName(String name) =>
    name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');

Future<String?> importJson() async {
  final result = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (result == null) return null;
  final bytes = await result.readAsBytes();
  return utf8.decode(bytes).replaceFirst('\uFEFF', '');
}

Future<void> saveJson(String name, Object data) => saveBytes(
  name.endsWith('.json') ? name : '$name.json',
  Uint8List.fromList(
    utf8.encode(
      data is String ? data : const JsonEncoder.withIndent('  ').convert(data),
    ),
  ),
);

Future<void> saveBytes(String name, Uint8List bytes) async {
  await FilePicker.saveFile(
    dialogTitle: 'Salvar arquivo',
    fileName: safeFileName(name),
    bytes: bytes,
    mimeType: name.endsWith('.json')
        ? 'application/json'
        : name.endsWith('.pdf')
        ? 'application/pdf'
        : name.endsWith('.png')
        ? 'image/png'
        : 'application/octet-stream',
  );
}
