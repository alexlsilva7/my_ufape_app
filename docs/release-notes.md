My UFAPE para Android, Windows, Linux e Web, compilado em modo release.

- Matriz curricular, planejamento de horários, catálogo e calendário acadêmico.
- Dados locais embarcados: funciona offline por padrão, sem depender da API ou do Supabase.
- Layout responsivo, animações e menus de contexto no desktop/web.
- Exportação da grade em imagem e backup do progresso.

### Downloads

- **Android:** o APK sem arquitetura no nome é universal. Os APKs `arm64-v8a`, `armeabi-v7a` e `x86_64` são alternativas menores para cada arquitetura. O AAB é o pacote Android App Bundle.
- **Windows x64:** extraia o ZIP inteiro e execute `my_ufape.exe`, mantendo as DLLs e a pasta `data` ao lado do executável.
- **Linux x64:** extraia o `.tar.gz` inteiro e execute `./my_ufape`. Requer GTK 3; consulte o `README.txt` incluído.
- **Web:** extraia o ZIP e sirva seu conteúdo por HTTP/HTTPS. Para uso local, execute `python -m http.server 8080` na pasta extraída e abra `http://localhost:8080`.
- **SHA256SUMS.txt:** hashes SHA-256 de todos os pacotes para conferir a integridade dos downloads.

### Assinatura

Os pacotes Android usam a chave de desenvolvimento prevista na configuração atual do projeto. Para publicar na Google Play, é necessário configurar uma chave de assinatura própria e gerar um novo AAB. O pacote Windows não possui assinatura Authenticode.
