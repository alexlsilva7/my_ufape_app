import 'package:flutter/material.dart';

import '../../widgets/academic_palette.dart';

class CatalogFilters extends StatelessWidget {
  const CatalogFilters({
    super.key,
    required this.profiles,
    required this.periods,
    required this.scale,
    required this.query,
    required this.typeValue,
    required this.selectedPeriod,
    required this.selectedProfile,
    required this.searchController,
    required this.onQueryChanged,
    required this.onTypeChanged,
    required this.onPeriodChanged,
    required this.onProfileChanged,
  });
  final List<String> profiles;
  final List<int> periods;
  final double scale;
  final String query;
  final String typeValue;
  final int? selectedPeriod;
  final String selectedProfile;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<int?> onPeriodChanged;
  final ValueChanged<String> onProfileChanged;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('catalog-filters'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: (Theme.of(context).brightness == Brightness.dark)
          ? const Color(0xff1e293b).withValues(alpha: .5)
          : const Color(0xfff1f5f9),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AcademicPalette.of(context).strongBorder),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final search = TextField(
          controller: searchController,
          onChanged: onQueryChanged,
          style: const TextStyle(fontSize: 14),
          decoration:
              catalogInputDecoration(
                context,
                hintText: 'Pesquisar por nome ou código...',
              ).copyWith(
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: AcademicPalette.of(context).muted,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minHeight: 44,
                  minWidth: 40,
                ),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          searchController.clear();
                          onQueryChanged('');
                        },
                      ),
              ),
        );
        final period = CatalogSelect<int>(
          label: 'Período',
          value: selectedPeriod ?? -1,
          items: {
            -1: 'Todos Períodos',
            for (final p in periods) p: p == 0 ? 'Optativas' : '$pº Período',
          },
          onChanged: (value) => onPeriodChanged(value == -1 ? null : value),
        );
        final type = CatalogSelect<String>(
          label: 'Tipo',
          value: typeValue,
          items: const {
            'all': 'Todos Tipos',
            'obrigatoria': 'Obrigatórias',
            'optativa': 'Optativas',
          },
          onChanged: onTypeChanged,
        );
        final wide = constraints.maxWidth >= 700 && scale <= 1.2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 16),
                  SizedBox(width: 170, child: period),
                  const SizedBox(width: 8),
                  SizedBox(width: 148, child: type),
                ],
              )
            else ...[
              search,
              const SizedBox(height: 12),
              if (constraints.maxWidth >= 400 && scale <= 1.2)
                Row(
                  spacing: 8,
                  children: [
                    Expanded(child: period),
                    Expanded(child: type),
                  ],
                )
              else ...[
                period,
                const SizedBox(height: 12),
                type,
              ],
            ],
            if (profiles.length > 1) ...[
              const SizedBox(height: 12),
              CatalogSelect<String>(
                label: 'Perfil / matriz',
                value: selectedProfile,
                items: {
                  'all': 'Todos os perfis',
                  for (final p in profiles) p: p,
                },
                onChanged: onProfileChanged,
              ),
            ],
          ],
        );
      },
    ),
  );
}

class CatalogSelect<T> extends StatelessWidget {
  const CatalogSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: DropdownButtonFormField<T>(
      key: ValueKey('catalog-$label:$value:${items.keys.join(',')}'),
      initialValue: items.containsKey(value) ? value : items.keys.first,
      isExpanded: true,
      decoration: catalogInputDecoration(context),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: (Theme.of(context).brightness == Brightness.dark)
            ? const Color(0xffe2e8f0)
            : const Color(0xff1e293b),
      ),
      icon: const Icon(Icons.expand_more, size: 18),
      dropdownColor: AcademicPalette.of(context).surface,
      items: [
        for (final item in items.entries)
          DropdownMenuItem(
            value: item.key,
            child: Text(item.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );
}

InputDecoration catalogInputDecoration(
  BuildContext context, {
  String? hintText,
}) {
  final palette = AcademicPalette.of(context);
  final borderColor = palette.strongBorder,
      mutedColor = palette.muted,
      surfaceColor = palette.surface;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: borderColor),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: mutedColor.withValues(alpha: .8), fontSize: 14),
    filled: true,
    fillColor: surfaceColor,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    constraints: const BoxConstraints(minHeight: 44),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 2,
      ),
    ),
  );
}
