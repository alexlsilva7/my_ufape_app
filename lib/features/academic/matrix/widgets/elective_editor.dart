import 'package:flutter/material.dart';

import '../../../../core/models.dart';
import '../../../../core/exceptions/persistence_exception.dart';
import '../matrix_view_model.dart';
import '../../widgets/academic_common.dart';
import '../../widgets/academic_motion.dart';

Future<void> showMatrixElectiveEditor(
  BuildContext context,
  MatrixViewModel state, [
  Subject? slot,
]) async {
  var manual = slot?.electiveSelection?.source == 'manual';
  var query = '', error = '';
  var saving = false, pendingChange = false;
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
  Future<void> persist(
    BuildContext dialogContext,
    StateSetter update,
    String? Function() edit,
  ) async {
    if (saving) return;
    update(() {
      saving = true;
      error = '';
    });
    try {
      if (!pendingChange) {
        final validation = edit();
        if (validation != null) {
          update(() => error = validation);
          return;
        }
        pendingChange = true;
        FocusScope.of(dialogContext).unfocus();
      } else {
        await state.retryPersistence();
      }
      await state.confirmPersistence();
      if (dialogContext.mounted) Navigator.pop(dialogContext);
    } on PersistenceException catch (failure) {
      if (dialogContext.mounted) update(() => error = failure.message);
    } finally {
      if (dialogContext.mounted) update(() => saving = false);
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
        content: ExcludeFocus(
          excluding: pendingChange,
          child: SizedBox(
            width: 480,
            child: AbsorbPointer(
              absorbing: pendingChange,
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
                                  onChanged: (value) =>
                                      update(() => query = value),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 190,
                                  child: AcademicTransition(
                                    identity: normalized(query),
                                    duration: academicMotionDuration(
                                      context,
                                      160,
                                    ),
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
                                                        choice?.id ==
                                                        subject.id,
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
                                                    hours.text =
                                                        subject.hours > 0
                                                        ? hoursLabel(
                                                            subject.hours,
                                                          )
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
          ),
        ),
        actions: [
          if (!pendingChange &&
              slot != null &&
              (slot.electiveSelection != null || slot.additionalElective))
            TextButton(
              onPressed: saving
                  ? null
                  : () => persist(context, update, () {
                      state.removeElective(slot);
                      return null;
                    }),
              child: Text(
                slot.additionalElective ? 'Remover' : 'Limpar escolha',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () => persist(context, update, () {
                    final parsed = double.tryParse(
                      hours.text.replaceAll(',', '.'),
                    );
                    if ((!manual && choice == null) ||
                        name.text.trim().isEmpty) {
                      return 'Informe ou selecione uma disciplina.';
                    }
                    if (parsed == null || !parsed.isFinite || parsed <= 0) {
                      return 'Informe uma carga horária maior que zero.';
                    }
                    return slot == null
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
                  }),
            child: Text(
              saving
                  ? 'Salvando…'
                  : pendingChange
                  ? 'Tentar salvar novamente'
                  : 'Salvar optativa',
            ),
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
