# C Brasil (cbr)

Editor e executor da linguagem C Brasil, desenvolvido em Dart e Flutter. O interpretador roda localmente no app; o código do usuário não é enviado para um servidor.

## Recursos

- Editor com destaque de sintaxe, numeração de linhas e atalhos.
- Console para saída, erros e entrada de dados.
- Abrir e salvar arquivos `.cbr`.
- Documentação e exemplos dos dialetos original e didático.
- Builds para Web, Android, iOS, Windows, macOS e Linux.

## Desenvolvimento local

Requer Flutter stable 3.38 ou superior.

```sh
flutter pub get
flutter test
flutter run -d chrome
```

Builds:

```sh
flutter build web --release
flutter build apk --release
flutter build appbundle --release
flutter build ios --release --no-codesign
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

O build iOS não é assinado. Para instalar em um iPhone ou publicar na App Store, é necessário assinar o app com certificados e provisioning profile da Apple. O bundle Windows inclui DLLs e dados necessários ao lado do executável; Linux é empacotado em `tar.gz`.

## CI e atualizações

- `.github/workflows/ci.yml` executa análise, testes, conformidade com o compilador oficial e build Web em pushes e pull requests.
- `.github/workflows/upstream.yml` verifica diariamente o repositório `vorgweb/C-Brasil`. Se a suíte de conformidade passar, registra o commit e dispara o workflow de distribuição. Se houver divergência, abre uma issue para portar e testar as mudanças antes de publicar.
- `.github/workflows/release.yml` gera Web, APK/AAB, IPA sem assinatura, Windows, macOS e Linux. Pode ser iniciado manualmente, por uma tag `v*` ou pela sincronização upstream; os arquivos são publicados no GitHub Releases.
- `tool/build_vercel_web.sh` prepara o Flutter Web para a Vercel. A visibilidade pública e a proteção do domínio são configuradas no projeto Vercel.

O app não consulta o GitHub nem mostra estado de conexão. A verificação upstream e a publicação de builds ocorrem nos workflows do repositório.
