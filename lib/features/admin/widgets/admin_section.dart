import 'package:flutter/material.dart';

class AdminSectionPage extends StatelessWidget {
  const AdminSectionPage(this.title, this.children, {super.key, this.action});
  final String title;
  final List<Widget> children;
  final Widget? action;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ?action,
        ],
      ),
      const SizedBox(height: 22),
      ...children.expand((child) => [child, const SizedBox(height: 16)]),
    ],
  );
}

class AdminPanel extends StatelessWidget {
  const AdminPanel(this.title, this.children, {super.key});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ...children.expand((child) => [child, const SizedBox(height: 12)]),
        ],
      ),
    ),
  );
}
