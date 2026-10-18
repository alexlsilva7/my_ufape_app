My UFAPE — Linux x64

Extraia o pacote inteiro, mantenha as pastas data/ e lib/ junto ao executável
e execute ./my_ufape. Não execute o aplicativo dentro do arquivo compactado.

Requer Linux x64 com GTK 3 e ambiente gráfico. Compilado no Ubuntu 22.04.
No Ubuntu/Debian, instale as dependências de execução com:
  sudo apt install libgtk-3-0 liblzma5

Para criar um atalho, adapte Exec e Icon em my_ufape.desktop para os caminhos
absolutos do executável e de my_ufape.png na pasta extraída. Depois copie o
atalho para ~/.local/share/applications/.

A fonte de dados está indicada nas notas da release e ao final deste arquivo.
Na variante local, usa JSON embarcado e funciona offline. Na variante Supabase,
consulta os dados acadêmicos diretamente no Supabase e requer conexão.
