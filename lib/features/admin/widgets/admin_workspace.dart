import 'package:flutter/material.dart';

import '../../../data/parsers/admin_data.dart';
import 'admin_navigation.dart';

class AdminWorkspace extends StatelessWidget {
  const AdminWorkspace({
    super.key,
    required this.busy,
    required this.dirty,
    required this.creating,
    required this.extracting,
    required this.isLocal,
    required this.courseId,
    required this.courses,
    required this.message,
    required this.supportsMigration,
    required this.selectedSection,
    required this.onNavigate,
    required this.onChooseCourse,
    required this.onSignOut,
    required this.onDismissMessage,
    required this.content,
  });
  final bool busy;
  final bool dirty;
  final bool creating;
  final bool extracting;
  final bool isLocal;
  final String courseId;
  final List<Json> courses;
  final String message;
  final bool supportsMigration;
  final String selectedSection;
  final ValueChanged<String> onNavigate;
  final ValueChanged<String?> onChooseCourse;
  final VoidCallback onSignOut;
  final VoidCallback onDismissMessage;
  final Widget content;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (busy) const LinearProgressIndicator(),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings_outlined),
            const Text(
              'Admin My UFAPE',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (dirty)
              const Chip(
                label: Text('Rascunho não salvo'),
                avatar: Icon(Icons.edit_outlined, size: 16),
              ),
            SizedBox(
              width: 270,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: creating
                    ? '__new__'
                    : courseId.isEmpty
                    ? null
                    : courseId,
                decoration: const InputDecoration(labelText: 'Curso'),
                items: [
                  for (final course in courses)
                    DropdownMenuItem(
                      value: '${course['id']}',
                      child: Text(
                        '${course['shortName']} · ${course['name']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const DropdownMenuItem(
                    value: '__new__',
                    child: Text('+ Novo curso'),
                  ),
                ],
                onChanged: busy || extracting ? null : onChooseCourse,
              ),
            ),
            if (!isLocal)
              TextButton.icon(
                onPressed: busy || extracting ? null : onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
          ],
        ),
      ),
      if (message.isNotEmpty)
        Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: SelectableText(message),
            trailing: IconButton(
              onPressed: onDismissMessage,
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 950;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wide)
                  SizedBox(
                    width: 220,
                    child: AdminNavigation(
                      horizontal: false,
                      supportsMigration: supportsMigration,
                      selectedSection: selectedSection,
                      onNavigate: onNavigate,
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (!wide)
                        SizedBox(
                          height: 58,
                          child: AdminNavigation(
                            horizontal: true,
                            supportsMigration: supportsMigration,
                            selectedSection: selectedSection,
                            onNavigate: onNavigate,
                          ),
                        ),
                      Expanded(child: content),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}
