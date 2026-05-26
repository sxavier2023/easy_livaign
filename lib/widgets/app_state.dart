import 'package:flutter/material.dart';

class AppLoadingState extends StatelessWidget {
  final String message;

  const AppLoadingState({super.key, this.message = "Loading..."});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(3, (index) {
                    return Container(
                      margin: EdgeInsets.only(top: index == 0 ? 0 : 8),
                      height: 10,
                      width: 220 - (index * 34),
                      decoration: BoxDecoration(
                        color: colors.outlineVariant.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String title;
  final Object? error;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    this.title = "Something went wrong",
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.errorContainer,
                    foregroundColor: colors.onErrorContainer,
                    child: const Icon(Icons.error_outline, size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: TextStyle(color: colors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (onRetry != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Retry"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Icon(icon, size: 34),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(color: colors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  if (action != null) ...[const SizedBox(height: 16), action!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
