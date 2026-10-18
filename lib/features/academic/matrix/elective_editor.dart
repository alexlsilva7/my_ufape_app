import 'package:flutter/material.dart';

import '../../../core/app_state.dart';
import '../academic_common.dart';
import '../academic_motion.dart';

Future<void> showMatrixElectiveEditor(
  BuildContext context,
  AppState state, [
  Subject? slot,
]) async {
  var manual = slot?.electiveSelection?.source == 'manual';
  var query = '', error = '';
  Subject? choice;
  final search = TextEditingController();
  final name = TextEditingController(text: slot?.electiveSelection?.name ?? '');
  final hours = TextEditingController(
    text: slot?.electiveSelection == null ? '' : hoursLabel(slot!.displayHours),
  );
  final candidates = state.catalogSubjects
      .where(
        (s) =>
            s.isElective &&
            !s.isGenericElective &&
            (s.profile == null ||
                s.profile == state.activeProfile?.id ||
                normalized(s.profile!) == 'optativa'),
      )
      .toList();
  manual = manual || candidates.isEmpty;
  for (final subject in candidates) {
    if (slot?.electiveSelection?.code != null &&
        slot!.electiveSelection!.code == subject.code) {
      choice = subject;
    }
  }
  final route = DialogRoute<void>(
    context: context,
    animationStyle: academicDialogMotion(context),
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(
          slot == null ? 'Adicionar optativa' : 'Definir disciplina optativa',
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  slot == null
                      ? 'A optativa será incluída no último período.'
                      : '${slot.name} • ${slot.period}º período',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Catálogo'),
                      icon: Icon(Icons.menu_book_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Manual'),
                      icon: Icon(Icons.edit_outlined),
                    ),
                  ],
                  selected: {manual},
                  onSelectionChanged: (value) => update(() {
                    manual = value.first;
                    error = '';
                  }),
                ),
                const SizedBox(height: 16),
                AcademicFormSection(
                  identity: manual,
                  child: !manual
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              autofocus: true,
                              controller: search,
                              decoration: const InputDecoration(
                                labelText: 'Pesquisar optativa',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (value) => update(() => query = value),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 190,
                              child: AcademicTransition(
                                identity: normalized(query),
                                duration: academicMotionDuration(context, 160),
                                slide: true,
                                child: candidates.isEmpty
                                    ? const AcademicEmpty(
                                        'Nenhuma optativa no catálogo. Informe manualmente.',
                                      )
                                    : ListView(
                                        children: [
                                          for (final subject
                                              in candidates.where(
                                                (s) => normalized(
                                                  '${s.name} ${s.code ?? ''}',
                                                ).contains(normalized(query)),
                                              ))
                                            ListTile(
                                              selected:
                                                  choice?.id == subject.id,
                                              leading: AcademicTransition(
                                                identity:
                                                    choice?.id == subject.id,
                                                duration:
                                                    academicMotionDuration(
                                                      context,
                                                      160,
                                                    ),
                                                child: Icon(
                                                  choice?.id == subject.id
                                                      ? Icons
                                                            .radio_button_checked
                                                      : Icons
                                                            .radio_button_unchecked,
                                                  size: 20,
                                                ),
                                              ),
                                              title: Text(
                                                subject.name,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                              subtitle: Text(
                                                '${subject.code ?? ''} • ${hoursLabel(subject.hours)}h',
                                              ),
                                              onTap: () => update(() {
                                                choice = subject;
                                                name.text = subject.name;
                                                hours.text = subject.hours > 0
                                                    ? hoursLabel(subject.hours)
                                                    : '';
                                                error = '';
                                              }),
                                            ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        )
                      : TextField(
                          autofocus: true,
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Nome da optativa',
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hours,
                  readOnly: !manual && choice != null && choice!.hours > 0,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Carga horária',
                    suffixText: 'horas',
                    helperText:
                        'Contabilizada quando o cartão estiver concluído.',
                  ),
                ),
                AcademicFormSection(
                  identity: error,
                  child: error.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (slot != null &&
              (slot.electiveSelection != null || slot.additionalElective))
            TextButton(
              onPressed: () {
                state.removeElective(slot);
                Navigator.pop(context);
              },
              child: Text(
                slot.additionalElective ? 'Remover' : 'Limpar escolha',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(hours.text.replaceAll(',', '.'));
              if ((!manual && choice == null) || name.text.trim().isEmpty) {
                update(() => error = 'Informe ou selecione uma disciplina.');
                return;
              }
              if (parsed == null || !parsed.isFinite || parsed <= 0) {
                update(
                  () => error = 'Informe uma carga horária maior que zero.',
                );
                return;
              }
              final saveError = slot == null
                  ? state.addElective(
                      name: name.text,
                      hours: parsed,
                      code: manual ? null : choice?.code,
                      desc: manual ? null : choice?.desc,
                    )
                  : state.setElective(
                      slot,
                      name: name.text,
                      hours: parsed,
                      code: manual ? null : choice?.code,
                      desc: manual ? null : choice?.desc,
                      subjectId: manual ? null : choice?.id,
                    );
              if (saveError != null) {
                update(() => error = saveError);
                return;
              }
              Navigator.pop(context);
            },
            child: const Text('Salvar optativa'),
          ),
        ],
      ),
    ),
  );
  await Navigator.of(context).push(route);
  await route.completed;
  search.dispose();
  name.dispose();
  hours.dispose();
}
