<div align="center">

  <img src="assets/images/my_ufape_logo_azul.png" alt="My UFAPE Logo" width="120" />

  # My UFAPE

  **Aplicativo multiplataforma moderno para planejamento de horários, consulta de matriz curricular e acompanhamento acadêmico dos estudantes da Universidade Federal do Agreste de Pernambuco (UFAPE).**

  [![Flutter](https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.13.4-0175C2?logo=dart&logoColor=white)](https://dart.dev)
  [![Plataformas](https://img.shields.io/badge/Plataformas-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20Web-blue)](#-builds-de-produção-e-distribuição)
  [![Testes](https://img.shields.io/badge/Testes-93%20passed-success?logo=checkmarx&logoColor=white)](#-testes-e-validação)
  [![Licença MIT](https://img.shields.io/badge/Licen%C3%A7a-MIT-green.svg)](https://opensource.org/licenses/MIT)

</div>

---

## ✨ Funcionalidades Principais

- 📅 **Planejador de Grade Horária Semestral**:
  - Filtros por turno (Manhã, Tarde e Noite).
  - Identificação visual imediata de disciplinas já cursadas (verde) e alerta de conflitos de horário (âmbar).
  - Inclusão automática da coluna de sábado quando houver disciplinas selecionadas nesse dia.
  - Agrupamento contínuo e fluido de aulas com múltiplos horários consecutivos.
  - **Exportação em PNG de alta definição (2300 px de largura)** com logotipo oficial, semestre, total de disciplinas e data.
- 🗺️ **Matriz Curricular & Grafo de Pré-Requisitos**:
  - Visualização em grade expandida no desktop ou em lista compacta em dispositivos móveis.
  - **Destaque inteligente de dependências**: ao selecionar uma disciplina, os pré-requisitos pendentes são realçados em rosa e as matérias desbloqueadas em verde-água.
  - **Navegação avançada no desktop**: suporte a `Ctrl + Scroll` para zoom direcionado ao cursor, além de gestos de pinça e controles de escala na tela.
  - **Resumo de carga horária em tempo real**: acompanhamento do progresso em disciplinas obrigatórias, optativas, atividades de extensão (ACEX) e complementares (ACC).
  - **Gerenciador flexível de optativas**: seleção de disciplinas diretamente do catálogo ou adição personalizada de matérias avulsas.
- 📖 **Catálogo de Cursos e Disciplinas**:
  - Consulta a ementas oficiais completas, objetivos e conteúdo programático.
  - Busca instantânea com filtros por período e tipo de componente curricular.
  - Detalhamento de carga horária e créditos.
- 📆 **Calendário Acadêmico Oficial da UFAPE**:
  - Visualização das páginas oficiais digitalizadas em alta resolução, com acesso rápido ao mês vigente.
- 💾 **Persistência Local & Backups**:
  - Armazenamento local via `SharedPreferences`, garantindo privacidade total sem rastreamento ou exigência de login.
  - Importação e exportação de backups globais ou individuais por curso/perfil.
- 🛡️ **Painel Administrativo & Feedback**:
  - Gerenciamento simplificado (local ou em nuvem via Supabase) com autenticação segura baseada em `app_metadata.academic_admin` e políticas de RLS (*Row Level Security*).
  - Canal integrado para envio de sugestões e relatos de problemas diretamente pelo aplicativo.

---

## 📸 Demonstração Visual

| Grade Horária Oficial | Matriz Curricular & Pré-requisitos |
| :---: | :---: |
| ![Grade Horária](docs/screenshots/horarios-desktop.png) | ![Matriz Curricular](docs/screenshots/matriz-desktop.png) |

| Imagem PNG Exportada (2300px) | Catálogo de Disciplinas |
| :---: | :---: |
| ![Exportação da Grade](docs/screenshots/horarios-exportacao.png) | ![Catálogo](docs/screenshots/catalogo-desktop.png) |

---

## 📜 Histórico & Relação com Projetos Anteriores

Para compreender a proposta deste repositório, vale destacar a evolução e as diferenças de arquitetura entre os projetos que compõem este ecossistema:

### ⚠️ Diferença Fundamental de Escopo

> [!IMPORTANT]
> **Este aplicativo tem um propósito distinto do My UFAPE original e NÃO realiza coleta automatizada de dados (*web scraping*) no portal SIGA.**
>
> Enquanto a primeira versão exigia autenticação na conta do aluno para extrair notas, faltas e turmas do portal acadêmico em tempo real, **este projeto dedica-se exclusivamente ao planejamento acadêmico e à consulta curricular**. Ele opera sobre uma **base de dados pública previamente estruturada** dos cursos da UFAPE (matrizes curriculares, ementas, ofertas semestrais de horários e calendário oficial). Por isso, não é necessário informar credenciais do SIGA.

### Comparativo dos Projetos

1. 📱 **Aplicativo Móvel Original ([alexlsilva7/my_ufape](https://github.com/alexlsilva7/my_ufape))**:
   - **Proposta:** Cliente móvel de acesso individual ao portal SIGA.
   - **Funcionamento:** Realizava *web scraping* autenticado via WebView para consultar e sincronizar notas, histórico escolar, frequência e turmas matriculadas diretamente do sistema da universidade.
   - **Tecnologias:** Flutter, Isar Community (banco NoSQL local), Routefly e Shorebird.

2. 🌐 **Plataforma Web de Grade Acadêmica ([alexlsilva7/grade_academica_app](https://github.com/alexlsilva7/grade_academica_app))**:
   - **Proposta:** Planejador de horários e visualizador interativo de matrizes curriculares da UFAPE no navegador.
   - **Funcionamento:** Aplicação web para simulação de grade sem conflitos de horário, verificação de cadeia de pré-requisitos, consulta de ementas e exportação da grade em imagem.
   - **Tecnologias:** React, TypeScript e Supabase.

3. 🚀 **Este Repositório — My UFAPE App ([alexlsilva7/my_ufape_app](https://github.com/alexlsilva7/my_ufape_app))**:
   - **Proposta:** Versão nativa e multiplataforma do planejador acadêmico.
   - **Funcionamento:** Utiliza os **dados de horários, matrizes e disciplinas já consolidados** (embarcados em arquivos JSON em `assets/data/` ou sincronizados via Supabase/API).
   - **Principais benefícios desta arquitetura:**
     - **Segurança e privacidade:** Não solicita nem armazena login ou senha institucional do estudante.
     - **100% Offline-First:** Funciona de forma imediata e independente de conexão com a internet ou da disponibilidade do portal SIGA.
     - **Multiplataforma:** Compilação nativa para Android, iOS, Windows (x64) e Web com alto desempenho gráfico.
     - **Interoperabilidade:** Os arquivos de backup (progresso e preferências) possuem compatibilidade total (1:1) com a plataforma web.

---

## 🏛️ Arquitetura do Software

O projeto aplica os princípios da **Clean Architecture**, mantendo a separação de responsabilidades em camadas e o desacoplamento via injeção de dependências:

```text
lib/
├── app/                  # Orquestração do app, rotas (academic_navigation) e injeção de dependências
├── core/                 # Modelos imutáveis, temas, cliente HTTP e regras de negócio centrais
├── domain/repositories/  # Contratos e interfaces abstratas (Course, Schedule, Feedback, Admin, Storage)
├── data/repositories/    # Implementações concretas e desacopladas dos repositórios:
│   ├── local/            # Provedor padrão: SharedPreferences + arquivos JSON locais (assets/data)
│   ├── supabase/         # Provedor em nuvem com políticas de segurança RLS
│   └── api/              # Provedor para integração com API REST legada (Express)
├── features/             # Módulos funcionais, telas e componentes visuais:
│   ├── home/             # Tela inicial responsiva
│   ├── academic/         # Planejador de horários, matriz curricular e catálogo de disciplinas
│   ├── calendar/         # Visualizador do calendário acadêmico oficial
│   ├── feedback/         # Modal de envio de sugestões e suporte
│   ├── settings/         # Gerenciamento de backups, fonte de dados e preferências
│   └── admin/            # Painel administrativo de dados acadêmicos
└── services/             # Serviços utilitários de manipulação de arquivos e renderização de imagens