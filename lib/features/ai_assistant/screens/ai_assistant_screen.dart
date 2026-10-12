import 'package:flutter/material.dart';

/// Screen for AI Assistant spending advisor (Gemini).
class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ lý AI Tài chính'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.auto_awesome_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Trợ lý Gemini AI',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Phân tích xu hướng chi tiêu và đề xuất mục tiêu tài chính',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
