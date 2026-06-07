import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/animations/animations.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/features/order/default_order_service.dart';
import 'package:keyframes_app/features/preorder/preorder_controller.dart';

/// The multi-step pre-order flow (Requirement 8).
///
/// Presents a three-step guided form for the supplied [listing] — Requirements
/// (with reference uploads), Options (tier / deadline / budget), and Contact &
/// Review — wrapped in an animated horizontal stepper with slide transitions
/// between steps (Requirements 8.1, 8.2). Back/Next navigation validates the
/// current step before advancing; the final step submits.
///
/// On a successful submit the flow routes to the order-success screen
/// (Requirement 8.8); a validation failure keeps the user on the offending
/// step with inline errors (Requirement 8.5); and a write failure shows a
/// non-blocking SnackBar while retaining the draft for retry (Requirement 8.9).
class PreOrderScreen extends ConsumerStatefulWidget {
  /// Creates the pre-order screen for [listing].
  const PreOrderScreen({required this.listing, super.key});

  /// The service being pre-ordered (passed via GoRouter `extra`).
  final ServiceListing listing;

  @override
  ConsumerState<PreOrderScreen> createState() => _PreOrderScreenState();
}

class _PreOrderScreenState extends ConsumerState<PreOrderScreen> {
  /// Tracks the previously-rendered step so the step transition slides in the
  /// correct direction (forward when advancing, backward when going back).
  int _previousStep = PreOrderStep.requirements;

  late final TextEditingController _requirementsController;
  late final TextEditingController _budgetController;

  PreOrderController get _controller =>
      ref.read(preOrderControllerProvider(widget.listing).notifier);

  @override
  void initState() {
    super.initState();
    final PreOrderState initial =
        ref.read(preOrderControllerProvider(widget.listing));
    _requirementsController =
        TextEditingController(text: initial.requirements);
    _budgetController = TextEditingController(
      text: initial.budget == null ? '' : _trimBudget(initial.budget!),
    );
  }

  @override
  void dispose() {
    _requirementsController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  String _trimBudget(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  void _onStepChanged(int next) {
    if (_previousStep != next) {
      // Update after the current frame so we never call setState during build;
      // `_previousStep` is only read to compute the slide direction.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _previousStep = next;
      });
    }
  }

  Future<void> _handlePrimaryAction(PreOrderState state) async {
    FocusScope.of(context).unfocus();
    if (state.step < PreOrderStep.review) {
      _controller.tryAdvance();
      return;
    }
    final Order? order = await _controller.submit();
    if (order != null && mounted) {
      // Replace the flow so the back gesture does not return to the form.
      context.pushReplacement(KRoutes.orderSuccess, extra: order);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ServiceListing listing = widget.listing;
    final PreOrderState state =
        ref.watch(preOrderControllerProvider(listing));

    // Compute the slide direction for this build, then schedule the
    // previous-step update for after the frame (build-safe, no setState).
    final bool forward = state.step >= _previousStep;
    _onStepChanged(state.step);

    // Surface a non-blocking notice on write failure and reset to idle so the
    // button leaves its loading state while the draft is retained (R8.9).
    ref.listen<PreOrderState>(preOrderControllerProvider(listing),
        (PreOrderState? previous, PreOrderState next) {
      if (next.submission is AsyncError &&
          previous?.submission is! AsyncError) {
        _showFailureNotice();
        _controller.resetSubmission();
      }
    });

    return Scaffold(
      backgroundColor: KColors.offWhite,
      appBar: AppBar(
        backgroundColor: KColors.navy900,
        foregroundColor: KColors.white,
        title: Text(
          'Pre-Order',
          style: KTextStyles.titleMd.copyWith(color: KColors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _ServiceSummaryHeader(listing: listing),
            _PreOrderStepper(
              currentStep: state.step,
              onStepTapped: _controller.goToStep,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: KMotion.resolve(context, KMotion.medium),
                switchInCurve: KMotion.enter,
                switchOutCurve: KMotion.exit,
                transitionBuilder:
                    (Widget child, Animation<double> animation) {
                  final Offset begin = Offset(forward ? 1.0 : -1.0, 0.0);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: animation.drive(
                        Tween<Offset>(begin: begin, end: Offset.zero),
                      ),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(state.step),
                  child: _buildStep(state),
                ),
              ),
            ),
            _PreOrderFooter(
              state: state,
              onBack: _controller.back,
              onPrimary: () => _handlePrimaryAction(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(PreOrderState state) {
    switch (state.step) {
      case PreOrderStep.requirements:
        return _RequirementsStep(
          controller: _controller,
          state: state,
          textController: _requirementsController,
        );
      case PreOrderStep.options:
        return _OptionsStep(
          controller: _controller,
          state: state,
          budgetController: _budgetController,
        );
      case PreOrderStep.review:
      default:
        return _ReviewStep(listing: widget.listing, state: state);
    }
  }

  void _showFailureNotice() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: KColors.navy800,
          behavior: SnackBarBehavior.floating,
          content: Text(
            "We couldn't submit your pre-order. Your details are saved — "
            'please try again.',
            style: KTextStyles.bodyMd.copyWith(color: KColors.white),
          ),
          action: SnackBarAction(
            label: 'Retry',
            textColor: KColors.amber400,
            onPressed: () => _handlePrimaryAction(
              ref.read(preOrderControllerProvider(widget.listing)),
            ),
          ),
        ),
      );
  }
}

// =============================================================================
// Header & stepper
// =============================================================================

class _ServiceSummaryHeader extends StatelessWidget {
  const _ServiceSummaryHeader({required this.listing});

  final ServiceListing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: KColors.navy900,
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        0,
        KSpace.lg,
        KSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'You are pre-ordering',
            style: KTextStyles.caption.copyWith(color: KColors.amber300),
          ),
          const SizedBox(height: KSpace.xs),
          Text(
            listing.title,
            style: KTextStyles.titleMd.copyWith(color: KColors.white),
          ),
        ],
      ),
    );
  }
}

class _PreOrderStepper extends StatelessWidget {
  const _PreOrderStepper({
    required this.currentStep,
    required this.onStepTapped,
  });

  final int currentStep;
  final ValueChanged<int> onStepTapped;

  static const List<String> _labels = <String>[
    'Requirements',
    'Options',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KColors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: KSpace.lg,
        vertical: KSpace.lg,
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < PreOrderStep.count; i++) ...<Widget>[
            _StepNode(
              index: i,
              label: _labels[i],
              currentStep: currentStep,
              onTap: i <= currentStep ? () => onStepTapped(i) : null,
            ),
            if (i < PreOrderStep.count - 1)
              Expanded(child: _StepConnector(filled: i < currentStep)),
          ],
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.label,
    required this.currentStep,
    required this.onTap,
  });

  final int index;
  final String label;
  final int currentStep;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isActive = index == currentStep;
    final bool isComplete = index < currentStep;
    final Color circleColor = isActive || isComplete
        ? KColors.amber500
        : KColors.slate200;
    final Color textColor =
        isActive ? KColors.navy900 : KColors.slate500;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: KMotion.resolve(context, KMotion.fast),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isComplete
                ? const Icon(Icons.check, size: 18, color: KColors.white)
                : Text(
                    '${index + 1}',
                    style: KTextStyles.label.copyWith(
                      color: isActive ? KColors.navy900 : KColors.slate500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: KSpace.xs),
          Text(
            label,
            style: KTextStyles.caption.copyWith(
              color: textColor,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.xl),
      child: AnimatedContainer(
        duration: KMotion.resolve(context, KMotion.medium),
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: KSpace.sm),
        color: filled ? KColors.amber500 : KColors.slate200,
      ),
    );
  }
}

// =============================================================================
// Step 1 — Requirements + reference uploads
// =============================================================================

class _RequirementsStep extends StatelessWidget {
  const _RequirementsStep({
    required this.controller,
    required this.state,
    required this.textController,
  });

  final PreOrderController controller;
  final PreOrderState state;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    final String? error = state.errorFor(DraftField.requirements);
    return _StepScroll(
      children: <Widget>[
        Text('Tell us what you need', style: KTextStyles.headingMd),
        const SizedBox(height: KSpace.xs),
        Text(
          'Describe your project in detail so we can scope it accurately.',
          style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
        ),
        const SizedBox(height: KSpace.lg),
        TextField(
          controller: textController,
          onChanged: controller.setRequirements,
          maxLines: 6,
          minLines: 5,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: 'e.g. I need a 60-second promo video for my brand...',
            filled: true,
            fillColor: KColors.white,
            errorText: error,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KSpace.rLg),
              borderSide: const BorderSide(color: KColors.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KSpace.rLg),
              borderSide: const BorderSide(color: KColors.slate200),
            ),
          ),
        ),
        const SizedBox(height: KSpace.xl),
        Text('Reference uploads', style: KTextStyles.titleMd),
        const SizedBox(height: KSpace.xs),
        Text(
          'Add images or examples that capture the look you are after.',
          style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
        ),
        const SizedBox(height: KSpace.md),
        _AttachmentGrid(controller: controller, paths: state.attachments),
      ],
    );
  }
}

class _AttachmentGrid extends StatelessWidget {
  const _AttachmentGrid({required this.controller, required this.paths});

  final PreOrderController controller;
  final List<String> paths;

  Future<void> _pick() async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile> picked = await picker.pickMultiImage();
      for (final XFile file in picked) {
        controller.addAttachment(file.path);
      }
    } catch (_) {
      // Picking can fail or be cancelled on some platforms; ignore silently so
      // the flow remains usable (uploads are optional).
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: KSpace.md,
      runSpacing: KSpace.md,
      children: <Widget>[
        for (final String path in paths)
          _AttachmentThumb(
            path: path,
            onRemove: () => controller.removeAttachment(path),
          ),
        _AddAttachmentTile(onTap: _pick),
      ],
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(KSpace.rMd),
            child: _buildPreview(),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: KColors.navy900,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: KColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    // On a real device the picked path points to a local image file. Guard the
    // file read so a missing/unsupported path falls back to a placeholder.
    try {
      final File file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    } catch (_) {
      // Fall through to the placeholder.
    }
    return Container(
      color: KColors.slate200,
      alignment: Alignment.center,
      child: const Icon(
        Icons.insert_drive_file_outlined,
        color: KColors.slate500,
      ),
    );
  }
}

class _AddAttachmentTile extends StatelessWidget {
  const _AddAttachmentTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: KColors.white,
          borderRadius: BorderRadius.circular(KSpace.rMd),
          border: Border.all(color: KColors.slate200),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.add_a_photo_outlined, color: KColors.navy600),
            SizedBox(height: KSpace.xs),
            Text('Add', style: TextStyle(color: KColors.slate500, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Step 2 — Options (tier / deadline / budget)
// =============================================================================

class _OptionsStep extends StatelessWidget {
  const _OptionsStep({
    required this.controller,
    required this.state,
    required this.budgetController,
  });

  final PreOrderController controller;
  final PreOrderState state;
  final TextEditingController budgetController;

  @override
  Widget build(BuildContext context) {
    final String? tierError = state.errorFor(DraftField.packageTier);
    final String? deadlineError = state.errorFor(DraftField.deadline);

    return _StepScroll(
      children: <Widget>[
        Text('Choose your package', style: KTextStyles.headingMd),
        if (tierError != null) ...<Widget>[
          const SizedBox(height: KSpace.xs),
          Text(
            tierError,
            style: KTextStyles.caption.copyWith(color: KColors.danger),
          ),
        ],
        const SizedBox(height: KSpace.md),
        for (final PackageTier tier in PackageTier.values)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.md),
            child: _PackageCard(
              tier: tier,
              selected: state.packageTier == tier,
              onTap: () => controller.setPackage(tier),
            ),
          ),
        const SizedBox(height: KSpace.lg),
        Text('Deadline', style: KTextStyles.titleMd),
        const SizedBox(height: KSpace.sm),
        _DeadlinePicker(
          deadline: state.deadline,
          error: deadlineError,
          onPick: (DateTime? value) => controller.setDeadline(value),
        ),
        const SizedBox(height: KSpace.lg),
        Text('Budget (optional)', style: KTextStyles.titleMd),
        const SizedBox(height: KSpace.sm),
        TextField(
          controller: budgetController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (String value) {
            final double? parsed = double.tryParse(value.trim());
            controller.setBudget(value.trim().isEmpty ? null : parsed);
          },
          decoration: InputDecoration(
            prefixText: '\$ ',
            hintText: 'Your approximate budget',
            filled: true,
            fillColor: KColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KSpace.rLg),
              borderSide: const BorderSide(color: KColors.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KSpace.rLg),
              borderSide: const BorderSide(color: KColors.slate200),
            ),
          ),
        ),
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  final PackageTier tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: KMotion.resolve(context, KMotion.fast),
        padding: const EdgeInsets.all(KSpace.lg),
        decoration: BoxDecoration(
          color: selected ? KColors.amber300 : KColors.white,
          borderRadius: BorderRadius.circular(KSpace.rLg),
          border: Border.all(
            color: selected ? KColors.amber500 : KColors.slate200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? KColors.amber500 : KColors.slate500,
            ),
            const SizedBox(width: KSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_tierTitle(tier), style: KTextStyles.titleMd),
                  const SizedBox(height: KSpace.xs),
                  Text(
                    _tierSubtitle(tier),
                    style:
                        KTextStyles.bodyMd.copyWith(color: KColors.slate500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlinePicker extends StatelessWidget {
  const _DeadlinePicker({
    required this.deadline,
    required this.error,
    required this.onPick,
  });

  final DateTime? deadline;
  final String? error;
  final ValueChanged<DateTime?> onPick;

  Future<void> _pick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    final DateTime initial = deadline != null && deadline!.isAfter(first)
        ? deadline!
        : first;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      onPick(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(KSpace.rLg),
          child: Container(
            padding: const EdgeInsets.all(KSpace.lg),
            decoration: BoxDecoration(
              color: KColors.white,
              borderRadius: BorderRadius.circular(KSpace.rLg),
              border: Border.all(
                color: error != null ? KColors.danger : KColors.slate200,
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.event_rounded, color: KColors.navy600),
                const SizedBox(width: KSpace.md),
                Expanded(
                  child: Text(
                    deadline == null
                        ? 'Select a target date'
                        : _formatDate(deadline!),
                    style: KTextStyles.bodyLg.copyWith(
                      color: deadline == null
                          ? KColors.slate500
                          : KColors.slate700,
                    ),
                  ),
                ),
                if (deadline != null)
                  GestureDetector(
                    onTap: () => onPick(null),
                    child: const Icon(Icons.close, color: KColors.slate500),
                  ),
              ],
            ),
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: KSpace.xs),
          Text(
            error!,
            style: KTextStyles.caption.copyWith(color: KColors.danger),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Step 3 — Contact & review
// =============================================================================

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.listing, required this.state});

  final ServiceListing listing;
  final PreOrderState state;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(
      children: <Widget>[
        Text('Review your pre-order', style: KTextStyles.headingMd),
        const SizedBox(height: KSpace.xs),
        Text(
          'Confirm the details below. Our team will reach out via chat to '
          'finalise everything.',
          style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
        ),
        const SizedBox(height: KSpace.lg),
        _ReviewCard(
          children: <Widget>[
            _ReviewRow(label: 'Service', value: listing.title),
            _ReviewRow(
              label: 'Package',
              value: state.packageTier == null
                  ? 'Not selected'
                  : _tierTitle(state.packageTier!),
            ),
            _ReviewRow(
              label: 'Deadline',
              value: state.deadline == null
                  ? 'Flexible'
                  : _formatDate(state.deadline!),
            ),
            _ReviewRow(
              label: 'Budget',
              value: state.budget == null
                  ? 'Not specified'
                  : '\$${_budgetLabel(state.budget!)}',
            ),
            _ReviewRow(
              label: 'References',
              value: state.attachments.isEmpty
                  ? 'None'
                  : '${state.attachments.length} attached',
            ),
          ],
        ),
        const SizedBox(height: KSpace.lg),
        Text('Requirements', style: KTextStyles.titleMd),
        const SizedBox(height: KSpace.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(KSpace.lg),
          decoration: BoxDecoration(
            color: KColors.white,
            borderRadius: BorderRadius.circular(KSpace.rLg),
            border: Border.all(color: KColors.slate200),
          ),
          child: Text(
            state.requirements.trim().isEmpty
                ? 'No requirements provided yet.'
                : state.requirements.trim(),
            style: KTextStyles.bodyMd,
          ),
        ),
      ],
    );
  }

  String _budgetLabel(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpace.lg),
      decoration: BoxDecoration(
        color: KColors.white,
        borderRadius: BorderRadius.circular(KSpace.rLg),
        border: Border.all(color: KColors.slate200),
      ),
      child: Column(children: children),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: KTextStyles.label.copyWith(color: KColors.slate500),
            ),
          ),
          const SizedBox(width: KSpace.md),
          Expanded(
            child: Text(
              value,
              style: KTextStyles.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Footer & shared helpers
// =============================================================================

class _PreOrderFooter extends StatelessWidget {
  const _PreOrderFooter({
    required this.state,
    required this.onBack,
    required this.onPrimary,
  });

  final PreOrderState state;
  final VoidCallback onBack;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final bool isFirst = state.step == PreOrderStep.requirements;
    final bool isLast = state.step == PreOrderStep.review;
    return Container(
      decoration: const BoxDecoration(
        color: KColors.white,
        boxShadow: KSpace.modalShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(KSpace.lg),
          child: Row(
            children: <Widget>[
              if (!isFirst)
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.isSubmitting ? null : onBack,
                    style: OutlinedButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(KSpace.minTouchTarget),
                      foregroundColor: KColors.navy800,
                      side: const BorderSide(color: KColors.slate200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KSpace.rPill),
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              if (!isFirst) const SizedBox(width: KSpace.md),
              Expanded(
                child: KPrimaryButton(
                  label: isLast ? 'Submit pre-order' : 'Next',
                  icon: isLast ? Icons.check_rounded : Icons.arrow_forward,
                  loading: state.isSubmitting,
                  expanded: true,
                  onPressed: onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A consistently-padded, scrollable container for a step's content.
class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

String _tierTitle(PackageTier tier) {
  switch (tier) {
    case PackageTier.basic:
      return 'Basic';
    case PackageTier.standard:
      return 'Standard';
    case PackageTier.premium:
      return 'Premium';
  }
}

String _tierSubtitle(PackageTier tier) {
  switch (tier) {
    case PackageTier.basic:
      return 'Essential scope for smaller projects.';
    case PackageTier.standard:
      return 'Our most popular, balanced package.';
    case PackageTier.premium:
      return 'Full scope with priority turnaround.';
  }
}

String _formatDate(DateTime date) {
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
