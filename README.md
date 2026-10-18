# My UFAPE — Flutter e Dart

Aplicativo Flutter nativo reconstruído a partir do código atual do site. Inclui planejamento de horários, matriz e grafo de pré-requisitos, progresso e notas, optativas, catálogo, calendário oficial, backups compatíveis, feedback e administração.

O aplicativo usa JSON local por padrão, sem exigir backend. A variável DATA_SOURCE escolhe local ou Supabase. Os repositórios Dart compartilham contratos; o site React continua preservado.

A home acompanha o design do site: fonte Inter embarcada, logotipo original, fundo pontilhado de 16 px, conteúdo central de até 896 px, cartões de horário/disciplina/matriz, calendário e rodapé com feedback. No celular, os cartões passam para uma coluna. A home usa essa composição própria; as demais telas mantêm a navegação do aplicativo. A licença da fonte está em `assets/fonts/OFL.txt`.

Em telas pequenas ou baixas, o cabeçalho fica mais compacto. Os acessos usam cartões com ícone ao lado do texto; com fontes ampliadas, o conteúdo passa para uma composição vertical. Seleção de curso, calendário e rodapé ajustam quebras de linha e espaçamentos. Os controles superiores e links têm áreas de toque de pelo menos 48 px.

## Preparação e ambiente

Use o FVM dentro de `flutter/`:

```powershell
fvm install 3.47.5
fvm flutter pub get
if (!(Test-Path .env)) { Copy-Item .env.example .env }
```

O `.env` contém somente configuração pública do Flutter. Não use o `.env` do servidor como arquivo de defines. O ambiente é incorporado ao executar ou compilar, portanto alterá-lo exige reiniciar a execução ou gerar outro build.

```dotenv
DATA_SOURCE=local
SUPABASE_URL=
SUPABASE_PUBLISHABLE_KEY=
API_BASE_URL=https://bcc-ufape.vercel.app
APP_VERSION=flutter-1.0.0
```

`local` é o padrão mesmo sem `.env`. O único arquivo de configuração do aplicativo é `flutter/.env`; `.env.example` é apenas o modelo versionado. O `.env` da raiz pertence ao backend/site e não é carregado pelo Flutter.

Se o backend já tem as credenciais do Supabase, `node tool/prepare_env.cjs` copia somente os valores públicos permitidos para o `.env` do Flutter, preservando a escolha de `DATA_SOURCE`.

## Executar localmente

```powershell
fvm flutter run -d windows --dart-define-from-file=.env
# Ou, sem nenhuma configuração:
fvm flutter run -d windows
```

Cursos, currículos, ementas e horários vêm de `assets/data/`. As alterações acadêmicas e os feedbacks ficam em documentos JSON no armazenamento local da plataforma via SharedPreferences. Não alteram os assets, o site ou o Supabase. A administração local dispensa login e salva somente neste dispositivo. A importação/exportação de JSON continua disponível; extração de IA e migração de arquivos do servidor ficam fora do modo local.

No Web é necessário servir os arquivos estáticos, sem iniciar o Express:

```powershell
fvm flutter build web --no-web-resources-cdn --dart-define-from-file=.env
node tool/serve.mjs
```

Abra [http://127.0.0.1:8787](http://127.0.0.1:8787). O proxy de API do servidor estático só é usado pelos fluxos remotos, quando escolhidos.

## Supabase

No `.env`, altere `DATA_SOURCE=supabase` e preencha a URL e a chave publicável. Cursos, currículos, ementas, horários e administração acadêmica passam a acessar o Supabase diretamente. Cache e preferências continuam locais e os caches são separados por provedor.

O banco precisa das tabelas existentes e da migração `../supabase/migrations/20261018162901_flutter_direct_repositories.sql`. Ela habilita leitura dos documentos acadêmicos públicos e restringe as alterações por RLS a contas com `app_metadata.academic_admin=true`. Esse atributo deve ser atribuído por um administrador no Supabase, nunca por `user_metadata` ou pelo próprio aplicativo. Faça login novamente após alterar a autorização. A migração foi preparada no repositório, sem aplicação automática em produção.

A sessão permanece em memória. Nenhuma chave secreta, `service_role`, senha ou chave de IA entra no build Flutter. A documentação de configuração está em [repositórios](docs/repositorios.md).

O envio público de feedback continua usando o endpoint protegido de `API_BASE_URL` para preservar o controle contra spam. A leitura e a edição administrativa dos feedbacks usam o Supabase com RLS.

## Compatibilidade com a API existente

`DATA_SOURCE=api` preserva o backend Express, inclusive extrações por IA e migrações do servidor. Use `API_BASE_URL` e, para login, as credenciais públicas do Supabase. O modo é opcional; não participa da execução local padrão.

## Comandos de desenvolvimento, build e release

Execute os comandos desta seção dentro de `flutter/`. Os exemplos usam PowerShell; os comandos `fvm`, `flutter` e `node` também podem ser executados em outros shells. Os trechos de empacotamento e checksums usam recursos do PowerShell.

### Preparar e conferir as ferramentas

```powershell
fvm install 3.47.5
fvm flutter --version
fvm flutter doctor -v
fvm flutter pub get
fvm flutter devices
if (!(Test-Path .env)) { Copy-Item .env.example .env }
```

| Destino | Ferramentas necessárias | Sistema para compilar |
| --- | --- | --- |
| Web | Flutter; Node.js para `tool/serve.mjs` | Windows, macOS ou Linux |
| Windows x64 | Visual Studio com a carga **Desenvolvimento para desktop com C++** e Windows SDK | Windows |
| Android | Android SDK, JDK 17 e NDK `28.2.13676358`, usado pelo SDK Flutter fixado | Windows, macOS ou Linux |
| iOS / IPA | Xcode, ferramentas de linha de comando, CocoaPods e assinatura configurada para distribuição | macOS |

Para aceitar as licenças Android, quando indicado pelo diagnóstico:

```powershell
fvm flutter doctor --android-licenses
```

O projeto contém os destinos `web/`, `windows/`, `android/` e `ios/`. macOS desktop e Linux desktop ainda não têm projetos nativos neste repositório.

### Executar em debug, profile ou release

```powershell
# Windows: desenvolvimento com hot reload
fvm flutter run -d windows --dart-define-from-file=.env

# Windows: medição de desempenho e execução otimizada
fvm flutter run -d windows --profile --dart-define-from-file=.env
fvm flutter run -d windows --release --dart-define-from-file=.env

# Web: desenvolvimento no Chrome
fvm flutter run -d chrome --dart-define-from-file=.env

# Android ou iOS: substitua ID_DO_DISPOSITIVO pelo ID de flutter devices
fvm flutter run -d ID_DO_DISPOSITIVO --dart-define-from-file=.env
fvm flutter run -d ID_DO_DISPOSITIVO --profile --dart-define-from-file=.env
fvm flutter run -d ID_DO_DISPOSITIVO --release --dart-define-from-file=.env
```

Use um aparelho físico para os modos profile/release de iOS. Todos os exemplos usam o provedor definido no `.env`; `DATA_SOURCE=local` mantém o funcionamento sem API. Para executar com os padrões do código, omita `--dart-define-from-file=.env`.

### Validação antes do release

```powershell
fvm flutter analyze
fvm flutter test

# Conferir formatação sem modificar arquivos
fvm dart format --output=none --set-exit-if-changed lib test

# Gerar novamente as capturas de widgets da home e das telas acadêmicas
fvm flutter test test/home_design_test.dart test/matrix_design_test.dart test/schedule_design_test.dart test/catalog_design_test.dart --dart-define=HOME_SCREENSHOTS=true --dart-define=MATRIX_SCREENSHOTS=true --dart-define=SCHEDULE_SCREENSHOTS=true --dart-define=CATALOG_SCREENSHOTS=true
```

### Web: release, prévia e publicação estática

```powershell
# Release padrão: inclui os recursos do renderizador no próprio build
fvm flutter build web --release --no-web-resources-cdn --dart-define-from-file=.env

# Servir o resultado localmente
node tool/serve.mjs
```

Saída: `build/web/`. Abra [http://127.0.0.1:8787](http://127.0.0.1:8787) e use `Ctrl + F5` após recompilar. Para publicar, envie **todo o conteúdo** de `build/web/` para a hospedagem estática; o comando de build não publica automaticamente. `tool/serve.mjs` é uma prévia local vinculada a `127.0.0.1`.

Variações opcionais, executadas separadamente:

```powershell
# Build para investigar desempenho
fvm flutter build web --profile --no-web-resources-cdn --dart-define-from-file=.env

# WebAssembly com fallback JavaScript; validar nos navegadores de destino
fvm flutter build web --release --wasm --no-web-resources-cdn --dart-define-from-file=.env

# Hospedagem em uma subpasta: substitua /my-ufape/ pelo caminho publicado
fvm flutter build web --release --base-href=/my-ufape/ --no-web-resources-cdn --dart-define-from-file=.env
```

Cada build Web substitui a mesma pasta de saída. A prévia `tool/serve.mjs` serve a aplicação na raiz; para conferir um `--base-href` diferente, use uma hospedagem que monte o conteúdo na subpasta correspondente.

### Windows x64: executável e ZIP de distribuição

```powershell
fvm flutter build windows --debug --dart-define-from-file=.env
fvm flutter build windows --profile --dart-define-from-file=.env
fvm flutter build windows --release --dart-define-from-file=.env

# Abrir o executável do release
& .\build\windows\x64\runner\Release\my_ufape.exe

# Empacotar depois de concluir o build release
New-Item -ItemType Directory -Force -Path build/releases | Out-Null
Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath build/releases/My-UFAPE-windows-x64.zip -Force
```

Saídas: `build/windows/x64/runner/Debug/`, `Profile/` ou `Release/`, conforme o modo escolhido. Distribua a pasta `Release/` completa ou o ZIP, incluindo as DLLs e `data/`. O `.exe` isolado não contém todos os recursos. O ZIP é um pacote portátil; esses comandos não geram instalador nem assinatura do executável.

### Android: APK de teste, release universal e por arquitetura

```powershell
# APK para depuração
fvm flutter build apk --debug --dart-define-from-file=.env

# APK para investigar desempenho
fvm flutter build apk --profile --dart-define-from-file=.env

# APK release universal: um arquivo para as arquiteturas incluídas
fvm flutter build apk --release --dart-define-from-file=.env

# Alternativa: APKs menores, separados por arquitetura
fvm flutter build apk --release --split-per-abi --dart-define-from-file=.env
```

Saídas em `build/app/outputs/flutter-apk/`:

| Comando | Arquivo |
| --- | --- |
| `apk --debug` | `app-debug.apk` |
| `apk --profile` | `app-profile.apk` |
| `apk --release` | `app-release.apk` |
| `apk --release --split-per-abi` | `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`, `app-x86_64-release.apk` |

Para instalar o APK universal já compilado em um Android conectado, com `adb` disponível no PATH:

```powershell
adb devices
adb -s ID_DO_DISPOSITIVO install -r build/app/outputs/flutter-apk/app-release.apk
```

### Android: AAB para distribuição pela loja

```powershell
fvm flutter build appbundle --release --dart-define-from-file=.env
```

Saída: `build/app/outputs/bundle/release/app-release.aab`. O AAB é enviado à loja; não é instalado diretamente com `adb install`.

**Assinatura atual:** `android/app/build.gradle.kts` usa `signingConfigs.getByName("debug")` também no release. APKs e AABs gerados assim servem para avaliação. Antes de publicar, configure o keystore e a assinatura própria de release nesse arquivo. Gerar o AAB não configura a assinatura de produção nem envia o aplicativo para a loja.

### iOS: build e IPA, somente no macOS

Execute em um terminal do macOS, dentro de `flutter/`, depois de preparar o mesmo `.env`. Configure a equipe de desenvolvimento e a assinatura no projeto Xcode antes de gerar o IPA:

```sh
fvm flutter pub get
open ios/Runner.xcworkspace

# Compilar sem assinar, para verificar a compilação
fvm flutter build ios --release --no-codesign --dart-define-from-file=.env

# Gerar arquivo Xcode e IPA com a assinatura configurada
fvm flutter build ipa --release --dart-define-from-file=.env

# Alternativa: usar opções de exportação previamente criadas no Xcode
fvm flutter build ipa --release --export-options-plist=CAMINHO/ExportOptions.plist --dart-define-from-file=.env
```

Saídas: aplicação em `build/ios/iphoneos/`, arquivo Xcode em `build/ios/archive/` e IPA em `build/ios/ipa/`. `--no-codesign` não gera um aplicativo pronto para instalar/distribuir. Os comandos iOS ainda não foram validados neste ambiente Windows; a geração do IPA depende dos certificados e perfis da conta Apple.

### Definir a versão de um release

O padrão vem de `version: 1.0.0+1` no `pubspec.yaml`: versão pública `1.0.0`, número de build `1`. Para substituir esses valores em uma compilação, acrescente `--build-name` e `--build-number`:

```powershell
# Exemplo: próxima versão 1.0.1, build 2
fvm flutter build windows --release --build-name=1.0.1 --build-number=2 --dart-define-from-file=.env
fvm flutter build apk --release --build-name=1.0.1 --build-number=2 --dart-define-from-file=.env
fvm flutter build appbundle --release --build-name=1.0.1 --build-number=2 --dart-define-from-file=.env
```

No macOS, use as mesmas opções com `fvm flutter build ipa`. Para tornar a versão o padrão do projeto, atualize `pubspec.yaml`. Aumente o número de build a cada nova distribuição pela loja. `APP_VERSION` no `.env` é uma identificação enviada no feedback; não substitui a versão nativa definida pelo Flutter. Atualize esse valor para identificar o release nos relatos.

### Empacotar Web e gerar checksums

Depois de gerar os releases desejados, execute dentro de `flutter/`. Os nomes fixos dos ZIPs e o manifesto são substituídos a cada execução:

```powershell
New-Item -ItemType Directory -Force -Path build/releases | Out-Null

# Pacote estático Web
Compress-Archive -Path build/web/* -DestinationPath build/releases/My-UFAPE-web.zip -Force

# Pacote Windows completo
Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath build/releases/My-UFAPE-windows-x64.zip -Force

# Hashes dos artefatos existentes; caminhos relativos à pasta flutter/
$releaseArtifacts = @(
  'build/web/main.dart.js',
  'build/releases/My-UFAPE-web.zip',
  'build/releases/My-UFAPE-windows-x64.zip',
  'build/app/outputs/flutter-apk/app-release.apk',
  'build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk',
  'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
  'build/app/outputs/flutter-apk/app-x86_64-release.apk',
  'build/app/outputs/bundle/release/app-release.aab'
)
$checksumLines = foreach ($releaseArtifact in $releaseArtifacts) {
  if (Test-Path -LiteralPath $releaseArtifact) {
    $releaseHash = (Get-FileHash -LiteralPath $releaseArtifact -Algorithm SHA256).Hash.ToLowerInvariant()
    "$releaseHash  $releaseArtifact"
  }
}
Set-Content -LiteralPath build/releases/SHA256SUMS.txt -Value $checksumLines -Encoding ascii
Get-Content build/releases/SHA256SUMS.txt
```

Inclua na entrega somente os artefatos gerados para a versão desejada. Arquivos de builds anteriores podem continuar em `build/`; o manifesto registra o conteúdo existente, sem verificar se todos os destinos foram recompilados juntos. Para um IPA, execute `Get-FileHash` no arquivo exportado ou use `shasum -a 256 build/ios/ipa/*.ipa` no macOS.

### Limpeza, ícones e diagnóstico de build

```powershell
# Limpeza opcional: remove os builds e arquivos gerados do Flutter
fvm flutter clean
fvm flutter pub get

# Regenerar ícones após alterar sua configuração ou os assets de origem
fvm dart run flutter_launcher_icons

# Diagnóstico e log detalhado de um build
fvm flutter doctor -v
fvm flutter build apk --release --dart-define-from-file=.env --verbose
```

Depois de `flutter clean`, gere novamente os destinos necessários antes de empacotar. Use `--no-pub` nos comandos de build somente quando `fvm flutter pub get` já tiver sido executado para o estado atual das dependências. A configuração Kotlin do projeto já contorna o problema de cache incremental entre os discos C: e G:; os detalhes estão em [validação](docs/validacao.md).

## Dados e organização

O mapa dos módulos e suas responsabilidades está em [Organização do código Flutter](docs/estrutura-codigo.md). Tema e navegação ficam separados da inicialização; cartões, resumo da matriz, cálculo da grade semanal e animações de blocos têm componentes próprios, com dados e callbacks explícitos.

`assets/data/` inclui os nove cursos cadastrados e sete ofertas semestrais, consultados em 18/10/2026, incluindo BCC 2026.2. Para atualizar a cópia pela API publicada:

```powershell
node tool/sync_offline_api.mjs https://bcc-ufape.vercel.app
```

Para usar um diretório com os JSONs originais, logotipos e calendário:

```powershell
node tool/sync_assets.mjs CAMINHO_DO_DIRETORIO_DE_DADOS
```

A sincronização altera apenas os assets de origem. Gere um novo build depois dela. As alterações já persistidas no dispositivo têm precedência sobre os assets e não são sobrescritas pela atualização.

O backup geral fica em **Preferências**. Na matriz, **Opções de progresso** exporta/importa o JSON compatível somente com o curso/perfil aberto; um arquivo de outro perfil é recusado. **Limpar progresso** pede confirmação e remove notas, horas e escolhas pessoais desse perfil. Conclusões compartilhadas pelo mesmo código seguem a regra do site.

A página de horários acompanha a versão React: cabeçalho com semestre, lista lateral de disciplinas, períodos e pesquisa, filtros de turno em botões e grade semanal com cartões índigo uniformes. Aulas longas ocupam vários blocos em um único cartão. Conclusões ficam em verde e conflitos em âmbar. No celular, use as abas **Disciplinas** e **Minha grade**; **Salvar imagem** exporta o PNG. A comparação com o site está documentada em `docs/engenharia-reversa-horarios.md`.

Os horários têm transições curtas ao adicionar/remover aulas, trocar turnos, pesquisar e marcar conclusões. Blocos existentes se reposicionam sem repetir a entrada. Movimento reduzido e navegação acessível desativam essas animações; a exportação captura a grade no estado final.

**Salvar imagem** gera um documento claro de 2300 px de largura, com logotipo, curso, semestre, quantidade de matérias e data, seguindo o modelo do site. A imagem inclui todos os turnos selecionados e tem o mesmo formato no celular e no desktop. A coluna de sábado só aparece quando há uma aula válida selecionada nele, também na visualização interativa. Exemplo: [imagem exportada](docs/screenshots/horarios-exportacao.png).

A navegação global fica no menu **⋮ do cabeçalho**, com Início, Horário, Matriz, Disciplinas, Calendário, Preferências e Administração. O aplicativo não reserva uma coluna lateral para navegação no desktop. A lista de disciplinas na tela de horários continua sendo parte do planejador.

O catálogo acompanha a referência React: conteúdo centralizado em 896 px, faixa de pesquisa e filtros, dois cartões por linha no desktop e uma coluna no celular. Os cartões mostram código, período, carga horária e créditos quando informados na fonte. O cartão e o botão de informação abrem as ementas. O cabeçalho mostra a data real de atualização do currículo, quando disponível. Tema escuro e texto ampliado têm layouts adaptados.

A matriz segue a composição da versão React: grade em largura total, filtros fixos no topo no desktop, cabeçalhos escuros por período, cartões compactos brancos/âmbar/verdes por status e resumo de carga horária, ACEX e ACC abaixo. No celular, inicia com a lista compacta por período; o botão de visualização permite abrir a matriz ampla. Toque em um cartão para alternar o status. O ícone do canto ou toque prolongado abre detalhes e notas. No desktop e na Web, o botão direito abre um menu com detalhes, status e edição de optativas. Optativas têm um botão próprio de definição/edição e a inclusão fica no último período. Pré-requisitos ficam em rosa e disciplinas liberadas em verde-água ao destacar um cartão. A fonte Inter também é usada nessa tela.

Na matriz, a roda do mouse rola a página normalmente. Segure **Ctrl** para usar a roda como zoom, mantendo o ponto sob o cursor fixo e sem rolar a página ao mesmo tempo. Os botões de zoom e o gesto de pinça continuam disponíveis.

No celular, os cartões usam texto maior e mais altura. A matriz ampla mantém colunas de pelo menos 220 px e permite navegar horizontalmente, sem comprimir todos os períodos na tela. Os atalhos de período e controles de zoom ficam acima do grafo. O menu **⋯** reúne ajuda, importação, exportação e limpeza do progresso; a limpeza mantém a confirmação. Ao pesquisar depois de deslocar a matriz, os resultados voltam à área visível preservando o zoom.

As mudanças de status animam cores e ícones; o resumo acompanha o progresso com transições curtas. O destaque de pré-requisitos combina opacidade gradual e desenho dos vínculos. Pesquisa, filtros e troca entre matriz/lista preservam a interação; a pesquisa mantém o zoom aplicado. Movimento reduzido e navegação acessível desativam as animações personalizadas.

Ao abrir a definição de optativa, a pesquisa recebe foco automaticamente; no modo manual, o foco vai para o nome. Os cartões da lista de horários e os blocos da grade semanal também têm menu de botão direito com detalhes, seleção/remoção e conclusão. Os menus usam as regras existentes de conflito e conclusão. Com um cartão focado, `Shift + F10` ou a tecla de menu de contexto abre as mesmas ações; `Esc` fecha sem alterar os dados.

Os ícones usam o logotipo existente. Para regenerá-los: `fvm dart run flutter_launcher_icons`.

- `lib/app/app_repositories.dart`: composição e injeção das implementações.
- `lib/domain/repositories/`: interfaces dos repositórios.
- `lib/data/repositories/`: implementações separadas em `api/`, `supabase/` e `local/`.
- `lib/core/`: modelos, transporte HTTP, estado e regras acadêmicas.
- `lib/features/`: telas públicas, calendário, feedback e administração.
- `lib/services/files.dart`: importação/exportação de arquivos.
- `test/`: regras, snapshots reais, autenticação e interfaces responsivas.
- `docs/engenharia-reversa.md`: rastreabilidade, decisões e limites observados.
- `docs/validacao.md`: resultados dos testes e builds desta entrega.

As alterações administrativas seguem o provedor escolhido: dispositivo no modo local, RLS no Supabase ou servidor no modo API. Confira a prévia e salve explicitamente para aplicar os dados.

As telas usam contratos de repositório; a autenticação específica do Supabase fica em `SupabaseAuthRepository`. Consulte [repositórios e injeção de dependências](docs/repositorios.md) para o mapa dos contratos, ciclo de vida das sessões e exemplos de substituição.
