# Reconstrução do My UFAPE em Flutter

O alvo é o repositório aberto `grade_academica_app`, incluindo suas alterações locais atuais. A skill REA foi aplicada para selecionar o método: como há fonte completa, a análise usa arquivos e testes diretamente, sem descompilar binários nem atribuir observações estáticas a execução.

## Fontes e rastreabilidade

| Área | Evidência no projeto original | Implementação Dart |
| --- | --- | --- |
| Rotas, tema e seleção | `src/App.tsx`, `src/hooks/useSchedule.ts`, `src/utils/appLocation.ts` | `lib/main.dart`, `core/app_state.dart` |
| Início e visibilidade | `HomeView.tsx`, `types.ts` | `features/home/`, `core/models.dart` |
| Grade e conflitos | `Sidebar.tsx`, `ScheduleGrid.tsx`, `utils/scheduleBlocks.ts` | `features/academic/schedule_screen.dart` |
| Matriz, requisitos e progresso | `MatrizView.tsx`, `utils/matrixProgress.ts`, `disciplineCompletion.ts`, `matrixElectives.ts` | `features/academic/matrix_screen.dart`, `core/app_state.dart` |
| Catálogo e conteúdos | `DisciplinesView.tsx`, `DisciplineDetailsModal.tsx`, `detailsHelper.ts` | `features/academic/catalog_screen.dart`, `academic_common.dart` |
| Calendário | `academicCalendarPdf.ts`, `CalendarImageViewer.tsx`, `public/documents/` | `features/calendar/`, `assets/calendar/` |
| Backup | `utils/backupHelper.ts` | `core/app_state.dart`, `services/files.dart` |
| Feedback | `utils/feedback.ts`, `server/feedbackRoutes.ts` | `features/feedback/`, caixa administrativa |
| Administração | `AdminView.tsx`, `components/admin/`, `app.ts`, `extractionRoutes.ts` | `features/admin/` |

Os caminhos de componentes e utilitários na tabela são relativos a `src/` quando abreviados.

## Decisões de reconstrução

- As telas são widgets Flutter nativos; a versão React não é embutida em WebView.
- O servidor Express existente permanece responsável por Supabase, autorização, publicação, extração por IA e retenção de trabalhos. Esses serviços não devem executar com segredos no cliente.
- O cliente preserva o esquema acadêmico original nas edições administrativas, incluindo evidências, perfis e relações.
- A interface adapta o planejamento para lista e grade em abas no celular e painéis no desktop. A matriz oferece grafo navegável e lista.
- A API é consultada primeiro. O último retorno válido é armazenado por curso/semestre; a cópia distribuída é uma referência de `.backup/src/data`, identificada na interface quando offline.
- O catálogo oficial e os nós visuais da matriz são coleções distintas. Conteúdos detalhados enriquecem a consulta por código, equivalência ou nome.
- Conclusões com código são compartilhadas por curso; IDs sem código mantêm o escopo do perfil. Notas, horas e escolhas de optativas são específicas do perfil.
- Os nomes das chaves de backup seguem o site. A importação aceita apenas a lista permitida e migra conclusões antigas usando o próprio arquivo recebido.
- Login administrativo usa a API pública do Supabase Auth, com rotação de refresh token em memória e confirmação de permissão em `/api/admin/session`. Senha, tokens e chaves secretas não entram no backup.

## Cobertura

Implementados: início, seleção de curso/semestre/perfil, temas, planejamento e conflitos, grade semanal e encontros sem horário na consulta, imagem PNG, catálogo e detalhes, matriz e grafo de pré-requisitos, conclusão, notas, horas ACEX/ACC, optativas manuais e do catálogo, progresso e backups, calendário com PDF/zoom, feedback e administração.

A administração inclui cursos, visibilidade, semestres, perfis, disciplinas, encontros, relações, revisão/importação/exportação JSON, extração e retomada com checkpoints, configuração de pipeline, caixa de feedback e migrações. Dados extraídos exigem revisão e ação explícita de salvar; o cliente não publica automaticamente.

Observação sobre validação: o site consulta ofertas sem encontros, mas sua validação de extração impede publicá-las com sessões vazias. O Flutter mantém essa distinção. Código e carga horária ausentes continuam valores desconhecidos quando aceitos pelo esquema; não são inventados.

## Limites dos dados e da verificação

O conjunto local de Administração contém somente 16 disciplinas e não informa carga horária total oficial. A matriz apresenta esse valor desconhecido sem presumir uma meta. No perfil MVET02, o código ZOOT3003 aparece em dois IDs distintos; ambos os registros são preservados para não descartar dados silenciosamente.

Testes simulados verificam requisições, autenticação, validação e estados sem escrever no Supabase. A consulta real da API e a inspeção do build Web validam o caminho público. Operações administrativas que modificam dados e extrações pagas não são executadas contra produção durante a validação.

Os projetos Android, Windows, iOS e Web estão incluídos. iOS requer macOS/Xcode para compilação e assinatura. A presença do projeto de uma plataforma não comprova execução em um dispositivo dessa plataforma.
