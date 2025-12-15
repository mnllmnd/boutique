import 'package:flutter/material.dart';

/// Widget réutilisable pour afficher un indicateur de chargement
/// Empêche les écrans blancs en affichant toujours quelque chose
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final bool isLoading;

  const LoadingIndicator({
    Key? key,
    this.message,
    this.isLoading = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Wrapper pour afficher du contenu ou un loader
/// Parfait pour les async operations
class LoadingWrapper extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? loadingMessage;

  const LoadingWrapper({
    Key? key,
    required this.isLoading,
    required this.child,
    this.loadingMessage = 'Chargement...',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: LoadingIndicator(message: loadingMessage),
          ),
      ],
    );
  }
}

/// Indicateur de chargement léger pour les opérations rapides
class QuickLoader extends StatelessWidget {
  final bool isVisible;

  const QuickLoader({Key? key, this.isVisible = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
