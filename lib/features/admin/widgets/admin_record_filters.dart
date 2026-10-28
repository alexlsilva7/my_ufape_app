import 'package:flutter/material.dart';

import '../../../data/parsers/admin_data.dart';

class AdminRecordFilters extends StatelessWidget {
  const AdminRecordFilters({
    super.key,
    required this.searchController,
    required this.selectedProfile,
    required this.selectedPeriod,
    required this.curriculum,
    required this.onSearchChanged,
    required this.onProfileChanged,
    required this.onPeriodChanged,
  });
  final TextEditingController searchController;
  final String selectedProfile;
  final String selectedPeriod;
  final Json curriculum;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onProfileChanged;
  final ValueChanged<String> onPeriodChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 14,
    runSpacing: 12,
    children: [
      SizedBox(
        width: 270,
        child: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: 'Pesquisar nome ou código',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => onSearchChanged(),
        ),
      ),
      SizedBox(
        width: 210,
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: selectedProfile,
          decoration: const InputDecoration(labelText: 'Perfil'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Todos')),
            for (final profile in records(curriculum['profiles']))
              DropdownMenuItem(
                value: '${profile['id']}',
                child: Text('${profile['name'] ?? profile['id']}'),
              ),
          ],
          onChanged: (value) => onProfileChanged(value ?? ''),
        ),
      ),
      SizedBox(
        width: 150,
        child: TextFormField(
          key: ValueKey('period-$selectedPeriod'),
          initialValue: selectedPeriod,
          decoration: const InputDecoration(labelText: 'Período'),
          onChanged: onPeriodChanged,
        ),
      ),
    ],
  );
}
