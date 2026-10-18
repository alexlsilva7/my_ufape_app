# Builds e releases

O workflow `.github/workflows/release.yml` compila Android, Windows x64, Linux x64
e Web. Usa o Flutter 3.47.5, as dependências do `pubspec.lock` e `DATA_SOURCE=local`.
Não lê o `.env` pessoal nem precisa de segredos do Supabase.

Antes de publicar, atualize `version` em `pubspec.yaml`, `.fvmrc` se necessário
e as notas em `docs/release-notes.md`. Depois faça commit e envie a tag:

```powershell
git push origin main
git tag v1.0.0
git push origin v1.0.0
```

A tag deve corresponder à versão do app sem o número de build (`1.0.0+1` →
`v1.0.0`). O workflow executa análise e testes, compila os quatro destinos e só
publica a release quando todos os builds passam. Inclui APK universal, APKs por
arquitetura, AAB, ZIP Windows/Web, TAR.GZ Linux e checksums SHA-256.

Também é possível iniciar o workflow manualmente pelo GitHub Actions. Não use
a mesma versão de uma release existente: incremente a versão antes de publicar
uma atualização. Uma execução com falha não publica pacotes parciais.

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
