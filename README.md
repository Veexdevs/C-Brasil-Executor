# C Brasil Executor (CBR)

Editor e executor multiplataforma da linguagem **C Brasil (CBR)**, construído em Dart + Flutter. A identidade visual provisória usa verde, amarelo e azul; a marca está isolada no widget `_BrandMark` para a logo final poder substituí-la sem refazer as telas.

## O que já funciona

- Editor com numeração de linhas, destaque de sintaxe, abrir/salvar `.cbr` e console.
- Interpretador Dart local — o código do usuário não é enviado a um servidor para execução.
- Recursos documentados no repositório de origem `vorgweb/C-Brasil`: expressões numéricas e booleanas, funções numéricas de um parâmetro, arrays mistos, `printf` com interpolação, `scan`, `if/else`, `while`, `for ... in range(...)`, `break`, `continue` e `end`.
- Atalhos didáticos em português usados nas imagens de referência: `inicio`, `fim`, `inteiro`, `escreva`, `se/então/senao/fimse`, `para/faca/fimpara` e `retorne`.
- Limite de instruções para interromper loops acidentais e erros com número de linha.
- Layout adaptável para navegador, celular, tablet e desktop.

O interpretador acompanha o subconjunto atual Cbr 0.6, incluindo as limitações descritas no repositório original. O monitor de upstream detecta novas revisões e dispara novamente validação/empacotamento; uma nova construção da linguagem ainda precisa ser portada e testada no interpretador Dart antes de passar a ser executável.

## Rodar localmente

Instale Flutter stable 3.38.0 ou mais recente e, na raiz do projeto, gere os runners nativos (eles também são criados pelo CI):

```sh
flutter create --platforms=web,android,ios,windows,macos,linux --project-name=c_brasil_executor .
python3 tool/ensure_android_internet.py
flutter pub get
flutter test
flutter run -d chrome       # web
flutter run -d linux        # desktop Linux
```

Comandos de build:

```sh
flutter build web --release
flutter build apk --release
flutter build appbundle --release
flutter build linux --release
flutter build windows --release
flutter build macos --release
flutter build ios --release --no-codesign
```

Para distribuir iOS é necessário assinar o app com certificados e provisioning profile da Apple. O fluxo de CI disponibiliza um `.ipa` sem assinatura para validação/assinatura posterior; ele não pode ser instalado diretamente em um iPhone sem assinatura válida. O executável Windows depende das DLLs e da pasta `data` ao lado do `.exe`; o fluxo publica o bundle completo em ZIP. Para Linux, são publicados um `.tar.gz` independente e um pacote `.deb` (amd64).

## Site e builds automáticos

- `.github/workflows/ci.yml` formata, analisa e testa o interpretador em cada atualização e pull request.
- `.github/workflows/upstream-watch.yml` compila Web, APK/AAB, iOS, Windows, macOS e Linux a cada push (inclusive branches de teste) e consulta `https://github.com/vorgweb/C-Brasil` a cada seis horas. Quando há uma revisão upstream nova, recompila todas as plataformas e cria um pré-lançamento com os bundles. O GitHub Pages é publicado apenas a partir de `main` ou da verificação agendada; tags `v*` publicam um release estável.
- `vercel.json` configura o build Web do Flutter para Vercel: `tool/build_vercel_web.sh` instala/cacheia o SDK Flutter estável e gera `build/web` para publicação estática. O primeiro build pode demorar mais por baixar o SDK.
- Para que `https://c-brasil-executor.vercel.app/` seja público, desative **Vercel Authentication/Deployment Protection** para o domínio `.vercel.app` em **Project Settings → Deployment Protection**. A configuração de proteção fica na conta Vercel, não no repositório.
- No repositório, selecione **Settings → Pages → Build and deployment → GitHub Actions** para ativar o destino do Pages uma vez. O app consulta a revisão upstream ao abrir e periodicamente enquanto está aberto.
- Os bundles também ficam nos artefatos da execução na aba **Actions**. O monitor consulta o endpoint público da API do GitHub; para o deploy e releases, usa as permissões `pages: write`, `id-token: write` e `contents: write`.

O GitHub Pages precisa estar habilitado nas configurações do repositório para a primeira publicação. O monitor atualiza o site e publica novos artefatos quando encontra commits upstream; apps já instalados não se reinstalam sozinhos (a pessoa precisa instalar o novo pacote). O workflow de iOS gera um `.ipa` não assinado, pois certificados Apple não são incluídos no projeto.
