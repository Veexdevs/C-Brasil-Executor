import 'package:web/web.dart' as web;

/// No navegador, recarregar a página busca a versão mais nova do executor.
bool get canReload => true;

void reloadPage() => web.window.location.reload();
