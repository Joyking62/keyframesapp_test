import 'package:flutter/material.dart';

import '../theme/k_colors.dart';
import '../theme/k_space.dart';
import '../theme/k_text_styles.dart';
import 'k_primary_button.dart';

/// Friendly, centered error state with a message and a retry affordance.
///
/// Surfaces a uniform error UI when a repository/result operation fails and
/// invokes [onRetry] when the user taps the retry button, fulfilling the
/// error-recovery requirement (Requirement 17.4). Any in-progress user input
/// is preserved by callers; this widget only renders the recovery surface.
class KErrorView extends StatelessWidget {
  /// Creates an error view.
  const KErrorView({
    this.onRetry,
    this.title = 'Something went wrong',
    this.message = 'We couldn\'t load this right now. Please try again.',
    this.retryLabel = 'Retry',
    this.icon = Icons.cloud_off_rounded,
    super.key,
  });

  /// Invoked when the retry button is pressed. When null, no button is shown.
  final VoidCallback? onRetry;

  /// Headline shown above the [message].
  final String title;

  /// Supporting description of the error.
  final String message;

  /// Label for the retry button.
  final String retryLabel;

  /// Leading status icon.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: KColors.slate500),
            const SizedBox(height: KSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: KTextStyles.titleMd,
            ),
            const SizedBox(height: KSpace.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: KSpace.xl),
              KPrimaryButton(
                label: retryLabel,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
