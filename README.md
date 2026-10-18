<div align="center">

  <img src="assets/images/my_ufape_logo_azul.png" alt="My UFAPE Logo" width="120" />

  # My UFAPE

  **Aplicativo multiplataforma moderno para planejamento de horários, matriz curricular e acompanhamento acadêmico dos estudantes da Universidade Federal do Agreste de Pernambuco (UFAPE).**

  [![Flutter](https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.13.4-0175C2?logo=dart&logoColor=white)](https://dart.dev)
  [![Plataformas](https://img.shields.io/badge/Plataformas-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20Web-blue)](#-plataformas-suportadas)
  [![Testes](https://img.shields.io/badge/Testes-93%20passed-success?logo=checkmarx&logoColor=white)](#-testes-e-validação)
  [![Licença MIT](https://img.shields.io/badge/Licen%C3%A7a-MIT-green.svg)](https://opensource.org/licenses/MIT)

</div>

---

## 📜 Histórico & Diferenças em Relação ao App Original

É importante destacar a distinção clara de proposta e funcionamento entre os projetos do ecossistema:

### ⚠️ Diferença Fundamental de Escopo

> [!IMPORTANT]
> **Este aplicativo NÃO possui todas as funções do My UFAPE original e NÃO realiza extração direta (*web scraping*) do portal SIGA.**
>
> Enquanto o app original conectava-se à conta individual do aluno para raspar notas, faltas e turmas do portal acadêmico em tempo real, **este projeto é focado estritamente no planejamento acadêmico e consulta curricular**: ele utiliza **informações oficiais já previamente extraídas e estruturadas** dos cursos da UFAPE (matrizes curriculares, ementas completas, ofertas semestrais de horários e calendário oficial). O estudante não precisa inserir nenhuma credencial do SIGA.

### Comparativo dos Projetos

1. 📱 **O App Móvel Original ([alexlsilva7/my_ufape](https://github.com/alexlsilva7/my_ufape))**:
   - **Proposta:** Acesso pessoal do estudante ao SIGA.
   - **Como funcionava:** Fazia *web scraping* automatizado via WebView com login do aluno, extraindo notas, histórico individual, faltas e turmas correntes diretamente do portal da universidade.
   - **Tecnologias:** Flutter, Isar Community (banco NoSQL local), Routefly e Shorebird.

2. 🌐 **A Plataforma Web Curricular ([alexlsilva7/grade_academica_app](https://github.com/alexlsilva7/grade_academica_app))**:
   - **Proposta:** Planejador de horários e visualizador de matrizes curriculares da UFAPE.
   - **Como funciona:** Plataforma em React, TypeScript e Supabase para simulação de grade sem choques, cálculo de pré-requisitos liberados, catálogo de ementas e exportação em imagem.

3. 🚀 **Este Repositório — My UFAPE App ([alexlsilva7/my_ufape_app](https://github.com/alexlsilva7/my_ufape_app))**:
   - **Proposta:** Versão nativa multiplataforma do planejador acadêmico.
   - **Como funciona:** Opera sobre as **informações de horários, grade e disciplinas já extraídas e consolidadas** (embarcadas em JSON em `assets/data/` ou servidas via Supabase/API).
   - **Vantagens desta abordagem:**
     - **Segurança e privacidade:** Não solicita nem armazena login e senha institucionais do SIGA.
     - **100% Offline-First:** Funciona imediatamente mesmo se o SIGA estiver fora do ar ou sem sinal de internet.
     - **Multiplataforma:** Compilável para Android, iOS, Windows x64 e Web com alta performance gráfica.
     - **Interoperabilidade:** Backups de progresso e preferências são compatíveis 1:1 com a plataforma web.

---

## ✨ Funcionalidades Principais

- 📅 **Planejador de Grade Horária Semestral**:
  - Filtros por turnos (Manhã, Tarde, Noite).
  - Identificação visual imediata de aulas já cursadas (verde) e detecção de conflitos de horário (âmbar).
  - Inclusão automática de coluna de sábado quando houver disciplina selecionada.
  - Aulas de múltiplos blocos agrupadas de forma contínua e fluida.
  - **Exportação em PNG em alta definição (2300 px de largura)** com logotipo oficial, semestre, total de matérias e data.
- 🗺️ **Matriz Curricular & Grafo de Pré-Requisitos**:
  - Exibição em grade ampla no desktop ou lista compacta no celular.
  - **Destaque inteligente de dependências**: ao selecionar uma matéria, os pré-requisitos pendentes são destacados em rosa e as disciplinas liberadas em verde-água.
  - **Navegação avançada no desktop**: use `Ctrl + Scroll` para zoom com foco pontual do cursor, além de gestos de pinça e botões de escala.
  - **Resumo de carga horária em tempo real**: acompanhamento de disciplinas obrigatórias, optativas, horas de extensão (ACEX) e complementares (ACC).
  - **Editor flexível de optativas**: escolha disciplinas do catálogo ou adicione matérias avulsas personalizadas.
- 📖 **Catálogo de Cursos e Disciplinas**:
  - Ementas oficiais completas, objetivos e conteúdo programático.
  - Busca instantânea e filtros por período e tipo de componente.
  - Exibição de carga horária e créditos.
- 📆 **Calendário Acadêmico Oficial da UFAPE**:
  - Navegação visual pelas páginas oficiais digitalizadas em alta resolução com prévia do mês corrente.
- 💾 **Persistência Local & Backups**:
  - Armazenamento em SharedPreferences sem rastreamento nem necessidade de login.
  - Importação e exportação de backups por curso/perfil ou globais.
- 🛡️ **Painel Administrativo & Feedback**:
  - Administração simplificada local ou nuvem via Supabase com autenticação segura baseada em `app_metadata.academic_admin` e RLS.
  - Envio de feedback diretamente pelo aplicativo.

---

## 📸 Demonstração Visual

| Grade Horária Oficial | Matriz Curricular & Pré-requisitos |
| :---: | :---: |
| ![Grade Horária](docs/screenshots/horarios-desktop.png) | ![Matriz Curricular](docs/screenshots/matriz-desktop.png) |

| Imagem PNG Exportada (2300px) | Catálogo de Disciplinas |
| :---: | :---: |
| ![Exportação da Grade](docs/screenshots/horarios-exportacao.png) | ![Catálogo](docs/screenshots/catalogo-desktop.png) |

---

## 🏛️ Arquitetura do Software

O projeto segue os princípios da **Clean Architecture** e separação em camadas com injeção de dependências:

```
lib/
├── app/                  # Orquestração do app, navegação (academic_navigation) e DI
├── core/                 # Modelos imutáveis, tema, transporte HTTP e regras de negócio
├── domain/repositories/  # Contratos abstratos (Course, Schedule, Feedback, Admin, Storage)
├── data/repositories/    # Implementações desacopladas dos repositórios:
│   ├── local/            # Provedor padrão: SharedPreferences + JSONs de assets/data
│   ├── supabase/         # Provedor cloud direto com RLS seguro
│   └── api/              # Provedor via API REST legada (Express)
├── features/             # Telas e componentes visuais modularizados:
│   ├── home/             # Página inicial responsiva
│   ├── academic/         # Horários, Matriz, Catálogo e componentes especializados
│   ├── calendar/         # Calendário oficial da UFAPE
│   ├── feedback/         # Modal de sugestões e contato
│   ├── settings/         # Gerenciamento de backups, servidor e preferências
│   └── admin/            # Painel de controle acadêmico
└── services/             # Utilitários de arquivos e geração de imagem para exportação
```

Consulte a documentação técnica detalhada em:
- [Organização e Arquitetura do Código](docs/estrutura-codigo.md)
- [Repositórios e Provedores de Dados](docs/repositorios.md)
- [Engenharia Reversa dos Horários](docs/engenharia-reversa-horarios.md)

---

## 🚀 Como Executar Localmente

### Pré-requisitos

- [FVM (Flutter Version Management)](https://fvm.app/) instalado.
- SDK Flutter fixado em `.fvmrc`: `3.47.5` (Dart `3.13.4`).

### Passo a Passo

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/alexlsilva7/my_ufape_app.git
   cd my_ufape_app
   ```

2. **Instale e vincule a versão do Flutter via FVM:**
   ```powershell
   fvm install 3.47.5
   fvm flutter pub get
   ```

3. **Configure as variáveis de ambiente:**
   ```powershell
   # Cria o arquivo .env a partir do modelo
   if (!(Test-Path .env)) { Copy-Item .env.example .env }
   ```

   *O arquivo `.env` controla a fonte dos dados (`DATA_SOURCE=local`, `supabase` ou `api`). O modo `local` é o padrão e funciona sem nenhuma chave ou internet.*

4. **Execute no destino desejado:**
   ```powershell
   # No Windows Desktop:
   fvm flutter run -d windows

   # No Navegador (Chrome):
   fvm flutter run -d chrome

   # No Android conectado:
   fvm flutter run -d android
   ```

---

## 📦 Builds de Produção e Distribuição

| Plataforma | Comando de Build | Artefato Gerado |
| :--- | :--- | :--- |
| **Windows Desktop** | `fvm flutter build windows --release --dart-define-from-file=.env` | `build/windows/x64/runner/Release/` |
| **Android (APK Universal)** | `fvm flutter build apk --release --dart-define-from-file=.env` | `build/app/outputs/flutter-apk/app-release.apk` |
| **Android (Por Arquitetura)** | `fvm flutter build apk --release --split-per-abi --dart-define-from-file=.env` | `build/app/outputs/flutter-apk/app-*-release.apk` |
| **Android (Google Play AAB)** | `fvm flutter build appbundle --release --dart-define-from-file=.env` | `build/app/outputs/bundle/release/app-release.aab` |
| **Web (Estático)** | `fvm flutter build web --release --no-web-resources-cdn --dart-define-from-file=.env` | `build/web/` |
| **iOS (Somente macOS)** | `fvm flutter build ipa --release --dart-define-from-file=.env` | `build/ios/ipa/` |

### Empacotar e Gerar Checksums SHA-256

Para gerar pacotes compactados para distribuição e criar a lista de hashes de integridade:

```powershell
New-Item -ItemType Directory -Force -Path build/releases | Out-Null
Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath build/releases/My-UFAPE-windows-x64.zip -Force
Compress-Archive -Path build/web/* -DestinationPath build/releases/My-UFAPE-web.zip -Force

# Gerar SHA256SUMS.txt
$artifacts = @(
  'build/releases/My-UFAPE-windows-x64.zip',
  'build/releases/My-UFAPE-web.zip',
  'build/app/outputs/flutter-apk/app-release.apk',
  'build/app/outputs/bundle/release/app-release.aab'
)
$lines = foreach ($item in $artifacts) {
  if (Test-Path $item) {
    $hash = (Get-FileHash -LiteralPath $item -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $item"
  }
}
Set-Content -LiteralPath build/releases/SHA256SUMS.txt -Value $lines -Encoding ascii
```

---

## 🧪 Testes e Validação

O projeto conta com suíte de testes automatizados abrangendo regras acadêmicas, navegação, estado offline, persistência e layouts responsivos:

```powershell
# Executar análise estática
fvm flutter analyze

# Executar todos os 93 testes unitários e de widget
fvm flutter test
```

---

## 👨‍💻 Autor & Licença

Desenvolvido por **Alex Silva** ([@alexlsilva7](https://github.com/alexlsilva7)).

Distribuído sob a licença **MIT**. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.
