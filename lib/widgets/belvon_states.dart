import 'package:flutter/material.dart';

class BelvonLoading extends StatelessWidget {
  final String? label;
  const BelvonLoading({super.key, this.label});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(label!),
        ],
      ],
    ),
  );
}

class BelvonEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? action;
  final String? actionLabel;

  const BelvonEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.action,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center),
          ],
          if (action != null && actionLabel != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: action, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

class BelvonErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  const BelvonErrorState({
    super.key,
    this.title = 'Что-то пошло не так',
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => BelvonEmptyState(
    icon: Icons.cloud_off_rounded,
    title: title,
    message: message,
    action: onRetry,
    actionLabel: onRetry == null ? null : 'Повторить',
  );
}
