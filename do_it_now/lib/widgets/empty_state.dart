import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.filtered = false});

  final bool filtered;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
    child: Column(
      children: [
        const ExcludeSemantics(
          child: Icon(Icons.inbox_outlined, size: 40, color: AppColors.cyan),
        ),
        const SizedBox(height: 12),
        Text(
          filtered ? 'No tasks match these filters' : 'No tasks yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          filtered
              ? 'Adjust Category or Priority to see more tasks.'
              : 'Use New task to create your first task.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.secondaryText),
        ),
      ],
    ),
  );
}
