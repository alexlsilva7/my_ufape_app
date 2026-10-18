# Horários: referência React e reconstrução Flutter

Conferência em 18/10/2026 (São Paulo). Escopo: reproduzir a página de horários enviada pelo usuário no aplicativo Flutter.

## Evidências e limites

- **Imagem fornecida:** grade BCC 2026.2, cinco disciplinas, sidebar em Optativas, Projeto de Jogos Digitais na quarta 14:00–18:00 e disciplinas noturnas em dois blocos.
- **Observação no navegador:** o endereço anterior `bcc-ufape.vercel.app` redirecionou para `my-ufape.vercel.app`. Navegação por Ciência da Computação → Horário Letivo abriu `/schedule?course=bcc&semester=2026.2`. Foram observados cabeçalho, períodos, pesquisa, grade, turnos, ação Salvar Imagem e ajuda inicial. A seleção temporária de Projeto de Jogos Digitais exibiu um cartão contínuo e o rótulo “4 aulas”; a seleção foi removida ao final. Nenhum dado publicado foi alterado.
- **Fonte React disponível:** `src/App.tsx`, `src/components/Navbar.tsx`, `src/components/Sidebar.tsx`, `src/components/ScheduleGrid.tsx`, `src/utils/scheduleBlocks.ts`. A leitura estática foi usada para detalhes de composição e regras; não se presume que todos os caminhos analisados foram executados no navegador.
- **Dados públicos:** resposta de `/api/courses/bcc?semester=2026.2&include=schedule`, guardada em `test/fixtures/schedule_bcc_2026_2.json`. Os testes usam essa fixture sem acesso à rede. Os snapshots gerais do aplicativo continuam separados dessa referência de teste.
- A tentativa de iniciar o React local encontrou limitações no escaneamento de dependências pelo Vite. A comparação visual em execução usou o site publicado; não foi necessário decompilar o site, pois o código React completo está disponível.

## Correspondência

| Elemento observado | Flutter |
| --- | --- |
| Marca, curso, semestre, tema e menu | Cabeçalho específico de horários em `AppShell` |
| Sidebar clara com períodos e pesquisa | Lista lateral de 320 px em telas grandes, com rolagem própria |
| Cartões neutros, índigo, verde e âmbar | Pendente, selecionado, concluído e conflito; botões de conclusão, detalhes e seleção |
| Sua Grade e filtros de turno | Automático, Manhã, Tarde, Noite e Todos em botões |
| Grade de segunda a sábado | Células brancas, cabeçalho claro, horário e turno à esquerda |
| Aula longa em um único cartão | Card contínuo ocupando os blocos correspondentes; rótulo de duração |
| Cartões índigo uniformes | Código, título em maiúsculas, professor e horário |
| Salvar Imagem | Exportação PNG mantida, com captura em escala 2 |
| Uso em tela pequena | Abas Disciplinas e Minha grade, grade com rolagem horizontal |

A referência React aproxima horários irregulares aos blocos canônicos. O Flutter preserva os limites reais de início/fim já suportados; essa foi uma decisão de implementação para não deslocar aulas. O bloqueio de conflitos, os horários adjacentes permitidos e as conclusões compartilhadas foram preservados.

## Verificação

`test/schedule_design_test.dart` reproduz as cinco disciplinas da imagem com a fixture pública: desktop 1920×1320, celular 375×844, paisagem 844×390, tema escuro 1440×1100 e texto 3× com animações desativadas. Verifica o cartão 14:00–18:00 e a alternância Noite/Automático. Os testes existentes cobrem seleção, rejeição de conflito e conclusão.

A prévia Flutter compilada foi aberta em `http://127.0.0.1:8788/#/schedule?course=bcc&semester=2026.2` usando proxy para a API pública. A pesquisa por Projeto de Jogos Digitais, a inclusão na grade, o cartão de quatro blocos e a alternância Noite/Automático foram conferidos também nessa execução real. A disciplina de teste e a pesquisa foram removidas ao final. Captura em `docs/screenshots/horarios-web-preview.png`.

Capturas de widgets em `docs/screenshots/horarios-*.png`; captura do site em `docs/screenshots/horarios-react-reference.png`. Para repetir as capturas: `fvm flutter test test/schedule_design_test.dart --dart-define=SCHEDULE_SCREENSHOTS=true`.
