# Ícones do aplicativo

O brasão original em `assets/images/my_ufape_logo_azul.png` mede 440 × 596 px. Os geradores de ícones recebem imagens quadradas; passar o brasão diretamente fazia sua largura e altura serem esticadas para o mesmo tamanho.

O comando abaixo preserva a proporção e centraliza o brasão em telas quadradas antes de gerar os recursos de cada plataforma. Execute dentro de `flutter/`:

```powershell
fvm flutter pub get
fvm dart run tool/generate_icons.dart
```

O gerador usa o brasão existente, sem redesenhá-lo. As imagens exibidas dentro das telas permanecem nos arquivos originais.

| Destino | Recurso |
| --- | --- |
| Windows | ICO com imagens de 16, 24, 32, 48, 64, 128 e 256 px, com transparência |
| Navegador | Favicon de 16 px e revisão de cache no HTML |
| PWA | Ícones normais transparentes e versões maskable opacas com margem própria |
| Android | Ícone tradicional e foreground adaptativo com inset de 20% |
| iOS | Ícones opacos e apple-touch-icon, com fundo `#f8fafc` |

As imagens de preparação ficam em `assets/launcher/`; a configuração das plataformas fica em `flutter_launcher_icons.yaml`. Execute o wrapper completo, pois ele prepara as imagens, chama `flutter_launcher_icons` e finaliza o ICO e os recursos Web.

Depois de gerar os recursos, recompile os destinos desejados:

```powershell
fvm flutter build windows --release --dart-define-from-file=.env
fvm flutter build apk --release --dart-define-from-file=.env
fvm flutter build web --release --no-web-resources-cdn --dart-define-from-file=.env
```

O Windows bloqueia a substituição de um `.exe` aberto, causando `LNK1104`/`LNK1168`. Feche o aplicativo compilado antes de reconstruir na mesma pasta ou compile em uma cópia separada do projeto. Aplicativos instalados precisam receber o novo pacote; atalhos fixados podem continuar exibindo um ícone em cache até serem recriados. O favicon usa uma revisão de URL para solicitar o recurso novo ao navegador.
