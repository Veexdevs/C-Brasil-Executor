import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Um commit do repositório oficial da linguagem.
class UpstreamCommit {
  const UpstreamCommit({
    required this.sha,
    required this.message,
    this.committedAt,
    this.author,
  });

  final String sha;
  final String message;
  final DateTime? committedAt;
  final String? author;

  String get shortSha => sha.length > 7 ? sha.substring(0, 7) : sha;
}

/// Estado da checagem de atualizações da linguagem.
class UpstreamState {
  const UpstreamState({
    this.checking = false,
    this.latest,
    this.error,
    this.checkedAt,
  });

  final bool checking;
  final UpstreamCommit? latest;
  final String? error;
  final DateTime? checkedAt;

  bool get online => error == null && latest != null;

  bool get hasUpdate =>
      latest != null && latest!.sha != UpstreamService.compiledCommit;
}

/// Consulta o repositório oficial `vorgweb/C-Brasil`.
///
/// O executor é recompilado automaticamente sempre que o repositório muda
/// (GitHub Actions + Vercel). Aqui o app apenas confere se existe uma versão
/// mais nova do que a que foi compilada junto e avisa a pessoa.
class UpstreamService extends ChangeNotifier {
  UpstreamService({http.Client? client}) : _client = client ?? http.Client();

  static const String repository = 'vorgweb/C-Brasil';
  static const String repositoryUrl = 'https://github.com/vorgweb/C-Brasil';
  static const String apiUrl = 'https://api.github.com/repos/$repository';

  /// SHA embutido pelo build (`--dart-define=CBR_UPSTREAM_COMMIT=...`).
  static const String compiledCommit = String.fromEnvironment(
    'CBR_UPSTREAM_COMMIT',
    defaultValue: 'desenvolvimento',
  );

  static const String languageVersion = 'Cbr 1.0';

  final http.Client _client;
  UpstreamState _state = const UpstreamState();
  String? _changelog;
  Timer? _timer;

  UpstreamState get state => _state;
  String? get changelog => _changelog;

  static String get compiledShort =>
      compiledCommit.length > 7 ? compiledCommit.substring(0, 7) : compiledCommit;

  void startWatching({Duration interval = const Duration(minutes: 30)}) {
    refresh();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  Future<void> refresh() async {
    if (_state.checking) return;
    _state = UpstreamState(
      checking: true,
      latest: _state.latest,
      checkedAt: _state.checkedAt,
      error: _state.error,
    );
    notifyListeners();
    try {
      final response = await _client
          .get(
            Uri.parse('$apiUrl/commits/main'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        _state = UpstreamState(
          error: 'GitHub respondeu ${response.statusCode}',
          checkedAt: DateTime.now(),
          latest: _state.latest,
        );
        notifyListeners();
        return;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final commit = payload['commit'] as Map<String, dynamic>? ?? const {};
      final author = commit['author'] as Map<String, dynamic>? ?? const {};
      final latest = UpstreamCommit(
        sha: payload['sha'] as String? ?? '',
        message: (commit['message'] as String? ?? '').split('\n').first,
        committedAt: DateTime.tryParse(author['date'] as String? ?? ''),
        author: author['name'] as String?,
      );
      _state = UpstreamState(
        latest: latest,
        checkedAt: DateTime.now(),
      );
      unawaited(_loadChangelog());
      notifyListeners();
    } catch (error) {
      _state = UpstreamState(
        error: 'sem conexão com o GitHub',
        checkedAt: DateTime.now(),
        latest: _state.latest,
      );
      notifyListeners();
    }
  }

  Future<void> _loadChangelog() async {
    if (_changelog != null) return;
    try {
      final response = await _client
          .get(
            Uri.parse('$apiUrl/contents/CHANGELOG.md'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return;
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final content = payload['content'] as String?;
      if (content == null) return;
      _changelog = utf8.decode(base64.decode(content.replaceAll('\n', '')));
      notifyListeners();
    } catch (_) {
      // Sem changelog: a tela Sobre mostra apenas o estado da conexão.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    super.dispose();
  }
}
