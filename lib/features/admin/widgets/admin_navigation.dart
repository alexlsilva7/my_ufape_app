import 'package:flutter/material.dart';

const adminSections = {
  'dashboard': ('Visão geral', Icons.dashboard_outlined),
  'settings': ('Configurações', Icons.settings_outlined),
  'catalog': ('Disciplinas', Icons.menu_book_outlined),
  'structure': ('Estrutura e perfis', Icons.account_tree_outlined),
  'schedule': ('Oferta semestral', Icons.calendar_month_outlined),
  'import': ('Importar e extrair', Icons.upload_file_outlined),
  'feedback': ('Feedbacks', Icons.inbox_outlined),
  'migration': ('Migração de dados', Icons.storage_outlined),
};

class AdminNavigation extends StatelessWidget {
  const AdminNavigation({
    super.key,
    required this.horizontal,
    required this.supportsMigration,
    required this.selectedSection,
    required this.onNavigate,
  });
  final bool horizontal;
  final bool supportsMigration;
  final String selectedSection;
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) {
    final children = adminSections.entries
        .where((entry) => entry.key != 'migration' || supportsMigration)
        .map(
          (entry) => horizontal
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    selected: selectedSection == entry.key,
                    label: Text(entry.value.$1),
                    onSelected: (_) => onNavigate(entry.key),
                  ),
                )
              : ListTile(
                  selected: selectedSection == entry.key,
                  leading: Icon(entry.value.$2),
                  title: Text(entry.value.$1),
                  onTap: () => onNavigate(entry.key),
                ),
        )
        .toList();
    return horizontal
        ? ListView(scrollDirection: Axis.horizontal, children: children)
        : ListView(children: children);
  }
}
