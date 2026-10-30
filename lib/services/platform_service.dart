import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'reload_stub.dart'
    if (dart.library.js_interop) 'reload_web.dart' as reload;

/// Resultado da abertura de um arquivo `.cbr`.
class OpenedFile {
  const OpenedFile(this.name, this.content);
  final String name;
  final String content;
}

/// Acesso a arquivos, links e recarregamento, isolando o que é específico de
/// cada plataforma.
abstract final class PlatformService {
  static bool get isWeb => kIsWeb;

  static Future<OpenedFile?> openFile() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Abrir programa C Brasil (.cbr)',
        type: FileType.custom,
        allowedExtensions: const ['cbr', 'txt', 'c'],
      );
      if (files.isEmpty) return null;
      final file = files.first;
      final bytes = await file.readAsBytes();
      return OpenedFile(
        file.name,
        utf8.decode(bytes, allowMalformed: true),
      );
    } catch (_) {
      return null;
    }
  }

  /// Salva o arquivo. No navegador isso baixa o `.cbr`; no desktop abre a
  /// janela de salvar do sistema.
  static Future<String?> saveFile(String name, String content) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final location = await FilePicker.saveFile(
        dialogTitle: 'Salvar programa C Brasil',
        fileName: name,
        mimeType: 'text/plain',
        type: FileType.custom,
        allowedExtensions: const ['cbr', 'txt'],
        bytes: bytes,
      );
      // No navegador o download é disparado pelo próprio plugin e a
      // localização não é informada: devolvemos o nome do arquivo.
      return location?.toString() ?? (kIsWeb ? name : null);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Recarrega a página no navegador (para pegar a versão nova do executor).
  static void reloadApp() => reload.reloadPage();

  static bool get canReload => reload.canReload;
}
