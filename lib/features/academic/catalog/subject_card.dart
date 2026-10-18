import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../academic_common.dart';
import '../academic_palette.dart';

class CatalogSubjectCard extends StatelessWidget {
  const CatalogSubjectCard({
    super.key,
    required this.subject,
    required this.onDetails,
  });
  final Subject subject;
  final VoidCallback onDetails;
  @override
  Widget build(BuildContext context) => _card(context);
  Widget _badge(BuildContext context, String label, {bool code = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: code
              ? (AcademicPalette.of(context).dark
                    ? const Color(0xff312e81)
                    : const Color(0xffeef2ff))
              : (AcademicPalette.of(context).dark
                    ? const Color(0xff1e293b)
                    : const Color(0xfff1f5f9)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: code ? 11 : 12,
            fontWeight: code ? FontWeight.w500 : FontWeight.w600,
            color: code
                ? (AcademicPalette.of(context).dark
                      ? const Color(0xffc7d2fe)
                      : const Color(0xff4f46e5))
                : AcademicPalette.of(context).muted,
          ),
        ),
      );

  Widget _metadata(
    BuildContext context,
    IconData icon,
    String label,
    String description,
  ) => Semantics(
    label: description,
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Icon(icon, size: 16, color: AcademicPalette.of(context).muted),
        Text(
          label,
          style: TextStyle(
            color: AcademicPalette.of(context).muted,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );

  Widget _card(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final credits = numberOf(subject.raw['credits'] ?? subject.raw['creditos']);
    final period = isCatalogElective(subject) && (subject.period ?? 0) <= 0
        ? 'Optativa'
        : '${subject.period ?? '—'}º Período';
    final details = onDetails;
    return Card(
      key: ValueKey('catalog-card-${subject.id}'),
      margin: EdgeInsets.zero,
      color: AcademicPalette.of(context).surface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: const Color(0xff0f172a).withValues(alpha: .18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AcademicPalette.of(context).strongBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: details,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (scale <= 1.5)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _badge(
                            context,
                            subject.code ?? 'S/ CÓDIGO',
                            code: true,
                          ),
                          if (subject.profile?.isNotEmpty == true)
                            _badge(context, subject.profile!),
                        ],
                      ),
                    ),
                    _badge(context, period),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _badge(context, subject.code ?? 'S/ CÓDIGO', code: true),
                    _badge(context, period),
                    if (subject.profile?.isNotEmpty == true)
                      _badge(context, subject.profile!),
                  ],
                ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  subject.name,
                  maxLines: scale > 1.5 ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: AcademicPalette.of(context).dark
                        ? const Color(0xfff1f5f9)
                        : const Color(0xff1e293b),
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: AcademicPalette.of(context).dark
                    ? const Color(0xff1e293b)
                    : const Color(0xfff1f5f9),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _metadata(
                          context,
                          Icons.schedule,
                          '${hoursLabel(subject.hours)}h',
                          'Carga horária: ${hoursLabel(subject.hours)} horas',
                        ),
                        if (credits.isFinite && credits > 0)
                          _metadata(
                            context,
                            Icons.menu_book_outlined,
                            '${hoursLabel(credits)} cr',
                            '${hoursLabel(credits)} créditos',
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ver detalhes e ementa',
                    onPressed: details,
                    icon: Icon(
                      Icons.info_outline,
                      size: 21,
                      color: AcademicPalette.of(context).dark
                          ? const Color(0xff94a3b8)
                          : const Color(0xff8da2bd),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
