import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/widgets/k_error_view.dart';
import 'package:keyframes_app/core/widgets/k_primary_button.dart';
import 'package:keyframes_app/core/widgets/k_status_chip.dart';
import 'package:keyframes_app/data/models/enums.dart';

/// Widget tests for the Keyframes shared design-system widgets.
///
/// Covers the user-visible contracts of [KPrimaryButton], [KStatusChip], and
/// [KErrorView] using `flutter_test`'s widget harness (pumpWidget + find +
/// tap). Each widget is wrapped in a [MaterialApp]/[Scaffold] so it has the
/// Directionality, Material, and media-query ancestors it expects.
///
/// Validates: Requirements 13.5, 17.4
void main() {
  /// Wraps [child] in the minimal app scaffolding the widgets require.
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('KPrimaryButton (Requirement 13.5)', () {
    testWidgets(
        'when loading=true it shows a CircularProgressIndicator, hides the '
        'label, and ignores taps', (WidgetTester tester) async {
      var pressedCount = 0;

      await tester.pumpWidget(
        host(
          KPrimaryButton(
            label: 'Continue',
            loading: true,
            onPressed: () => pressedCount++,
          ),
        ),
      );
      // Let the AnimatedSwitcher settle into the loading child.
      await tester.pump(const Duration(milliseconds: 300));

      // The spinner is shown and the label text is not.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue'), findsNothing);

      // Tapping while loading must NOT invoke onPressed (button is disabled).
      await tester.tap(find.byType(KPrimaryButton));
      await tester.pump();
      expect(pressedCount, 0);
    });

    testWidgets(
        'when loading=false it shows the label and tapping invokes onPressed',
        (WidgetTester tester) async {
      var pressedCount = 0;

      await tester.pumpWidget(
        host(
          KPrimaryButton(
            label: 'Continue',
            onPressed: () => pressedCount++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // The label is rendered and there is no spinner.
      expect(find.text('Continue'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Tapping invokes the callback exactly once.
      await tester.tap(find.byType(KPrimaryButton));
      await tester.pump();
      expect(pressedCount, 1);
    });

    testWidgets('a null onPressed disables the button (tap is a no-op)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const KPrimaryButton(
            label: 'Disabled',
            onPressed: null,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Disabled'), findsOneWidget);
      // Tapping a disabled button must not throw and is a no-op.
      await tester.tap(find.byType(KPrimaryButton));
      await tester.pump();
    });
  });

  group('KStatusChip (Requirement 13.5)', () {
    // Expected (label, color) mapping for every OrderStatus, per the design
    // system status-chip contract.
    final Map<OrderStatus, ({String label, Color color})> expected =
        <OrderStatus, ({String label, Color color})>{
      OrderStatus.pending: (label: 'Pending', color: KColors.warning),
      OrderStatus.inReview: (label: 'In Review', color: KColors.navy400),
      OrderStatus.inProgress: (label: 'In Progress', color: KColors.navy600),
      OrderStatus.completed: (label: 'Completed', color: KColors.success),
      OrderStatus.cancelled: (label: 'Cancelled', color: KColors.danger),
    };

    for (final OrderStatus status in OrderStatus.values) {
      testWidgets(
          'renders the expected label and exposes the expected color for '
          '$status', (WidgetTester tester) async {
        final ({String label, Color color}) want = expected[status]!;

        final chip = KStatusChip(status);
        await tester.pumpWidget(host(chip));
        await tester.pump();

        // The label text is rendered.
        expect(find.text(want.label), findsOneWidget);

        // The getters expose the expected label/color mapping.
        expect(chip.label, want.label);
        expect(chip.color, want.color);
      });
    }
  });

  group('KErrorView (Requirement 17.4)', () {
    testWidgets('renders the title and message text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const KErrorView(
            title: 'Network error',
            message: 'Please check your connection and retry.',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Network error'), findsOneWidget);
      expect(find.text('Please check your connection and retry.'),
          findsOneWidget);
    });

    testWidgets('tapping the retry button invokes onRetry',
        (WidgetTester tester) async {
      var retried = 0;

      await tester.pumpWidget(
        host(
          KErrorView(
            title: 'Network error',
            message: 'Please check your connection and retry.',
            retryLabel: 'Try again',
            onRetry: () => retried++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // The retry button (a KPrimaryButton) is rendered with its label.
      expect(find.byType(KPrimaryButton), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.byType(KPrimaryButton));
      await tester.pump();
      expect(retried, 1);
    });

    testWidgets('omits the retry button when onRetry is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(const KErrorView()),
      );
      await tester.pump();

      // Default title/message render, but no retry button is shown.
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byType(KPrimaryButton), findsNothing);
    });
  });
}
