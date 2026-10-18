# Builds e releases

O workflow `.github/workflows/release.yml` compila Android, Windows x64, Linux x64
e Web. Usa o Flutter 3.47.5 e as dependências do `pubspec.lock`.
O padrão é `DATA_SOURCE=local`; a execução manual permite escolher `supabase`.
Não lê o `.env` pessoal. A variante Supabase recebe apenas a URL e a chave pública
dos secrets `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` do repositório.

Antes de publicar, atualize `version` em `pubspec.yaml`, `.fvmrc` se necessário
e as notas em `docs/release-notes.md`. Depois faça commit e envie a tag:

```powershell
git push origin main
git tag v1.0.0
git push origin v1.0.0
```

A tag deve corresponder à versão do app sem o número de build (`1.0.0+1` →
`v1.0.0` para local, `v1.0.0-supabase` para Supabase). O workflow executa análise e testes, compila os quatro destinos e só
publica a release quando todos os builds passam. Inclui APK universal, APKs por
arquitetura, AAB, ZIP Windows/Web, TAR.GZ Linux e checksums SHA-256.

Também é possível iniciar o workflow manualmente pelo GitHub Actions. Não use
a mesma versão de uma release existente: incremente a versão antes de publicar
uma atualização. Uma execução com falha não publica pacotes parciais.

## Variante Supabase

Configure no GitHub Actions os secrets `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY`,
usando somente uma chave pública `sb_publishable_...` ou a chave legada de papel
`anon`. O gerador recusa chaves secretas e `service_role`. Inicie manualmente o
workflow com `data_source=supabase` ou envie uma tag terminada em `-supabase`.

```powershell
gh workflow run release.yml --field data_source=supabase
```

Os nomes dos pacotes e a tag incluem `-supabase`, preservando os downloads locais.
O gerador `tool/prepare_release.py` cria `.env.release.json` apenas com os valores
públicos permitidos. Esse arquivo é ignorado pelo Git.

Antes de distribuir, confirme que `anon` pode consultar `courses`, `course_curricula`,
`course_schedules` e `course_contents` com RLS. A compilação não altera permissões
do banco. A consulta acadêmica usa o Supabase diretamente; sugestões ainda passam
pela API pública do site para manter a proteção contra spam.

O job Web executa `dart run tool/validate_supabase.dart` usando os repositórios
reais do app e a configuração pública da release. A publicação exige que a lista
de cursos, os perfis da matriz, as ementas e as ofertas de BCC/2026.2 sejam
carregados sem login. É uma validação somente de leitura; não modifica o banco.

## Builds locais

Na pasta do app, crie `.env` a partir de `.env.example` e mantenha `DATA_SOURCE=local`
para o modo offline. Use o SDK do `.fvmrc`:

```powershell
fvm flutter pub get --enforce-lockfile
fvm flutter analyze
fvm flutter test
fvm flutter build apk --release --dart-define-from-file=.env
fvm flutter build apk --release --split-per-abi --dart-define-from-file=.env
fvm flutter build appbundle --release --dart-define-from-file=.env
fvm flutter build web --release --no-web-resources-cdn --dart-define-from-file=.env
fvm flutter build windows --release --dart-define-from-file=.env
```

No Linux, instale Clang, CMake, Ninja, pkg-config, GTK 3 e liblzma antes de compilar:

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
fvm flutter build linux --release --dart-define-from-file=.env
tar -czf My-UFAPE-linux-x64.tar.gz -C build/linux/x64/release/bundle .
```

Windows precisa do Visual Studio com desenvolvimento desktop C++; Android precisa
do SDK Android e JDK 17. Builds nativos de desktop rodam no sistema correspondente.
Distribua a pasta de release inteira: Windows inclui DLLs e `data/`; Linux inclui
`lib/` e `data/`. Web deve ser servido por HTTP/HTTPS.

O Android atualmente usa assinatura de desenvolvimento. Para lojas, configure uma
chave própria em `android/app/build.gradle.kts`; não versione senhas ou keystores.
