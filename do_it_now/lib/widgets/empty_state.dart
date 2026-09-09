import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF00E5FF)),
          const SizedBox(height: 12),
          const Text(
            'No tasks yet',
            style: TextStyle(
              color: Color(0xFFF0F6F8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            'Create one to get started.',
            style: TextStyle(color: Color(0xFF5C7580)),
          ),
        ],
      ),
    ),
  );
}
