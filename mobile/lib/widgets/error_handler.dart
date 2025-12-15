import 'package:flutter/material.dart';

/// Gère et affiche les erreurs de manière user-friendly
/// Évite les écrans blancs en montrant toujours un message d'erreur
class ErrorHandler {
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Réessayer',
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  static Future<void> showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onRetry,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRetry();
              },
              child: const Text('Réessayer'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Capturer les erreurs non capturées et les afficher
  static void captureUnhandledError(dynamic error, StackTrace stackTrace) {
    print('❌ Unhandled Error: $error\n$stackTrace');
  }
}

/// Widget pour afficher un écran d'erreur complet
class ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? details;

  const ErrorScreen({
    Key? key,
    required this.message,
    this.onRetry,
    this.details,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0F1113),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (details != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    details!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                if (onRetry != null)
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Réessayer'),
                  )
                else
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
