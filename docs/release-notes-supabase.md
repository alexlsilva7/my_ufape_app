My UFAPE para Android, Windows, Linux e Web, compilado em modo release com **DATA_SOURCE=supabase**.

Corrige os filtros de curso, semestre e identificador: aspas extras nas consultas
faziam a matriz, o catálogo e os horários aparecerem vazios mesmo com leitura
permitida no banco. Os builds anteriores `v1.0.0-supabase` são substituídos por esta correção.

- Cursos, matrizes, disciplinas e horários são consultados diretamente no Supabase.
- Usa a URL do projeto e a chave pública de cliente, sem chave `service_role` ou chave secreta no aplicativo.
- Requer conexão e permissão de leitura das tabelas acadêmicas no Supabase.
- Progresso e preferências continuam salvos no dispositivo.
- O envio de sugestões usa a API do site para preservar a proteção contra spam.

### Downloads

- **Android:** APK universal, APKs por arquitetura (`arm64-v8a`, `armeabi-v7a`, `x86_64`) e AAB.
- **Windows x64:** extraia o ZIP inteiro e execute `my_ufape.exe`, mantendo as DLLs e `data/` ao lado.
- **Linux x64:** extraia o TAR.GZ inteiro e execute `./my_ufape`. Requer GTK 3; consulte o `README.txt` incluído.
- **Web:** extraia o ZIP e sirva por HTTP/HTTPS. Para uso local, execute `python -m http.server 8080` na pasta extraída.
- **SHA256SUMS.txt:** hashes SHA-256 para conferir os downloads.

Os pacotes Android mantêm a assinatura de desenvolvimento do projeto; publicação na Google Play exige configurar uma chave própria. O Windows não possui assinatura Authenticode.

A versão local/offline continua disponível separadamente na release `v1.0.0`.
