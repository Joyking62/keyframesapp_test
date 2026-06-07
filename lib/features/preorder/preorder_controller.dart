import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/core/utils/validators.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_draft.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/features/order/default_order_service.dart';

/// Sentinel used by [PreOrderState.copyWith] so that nullable fields
/// (`packageTier`, `deadline`, `budget`, `validation`) can be explicitly reset
/// to `null` while still distinguishing "leave unchanged" from "set to null".
const Object _unset = Object();

/// The zero-based index of each step in the pre-order flow.
///
/// Step 1 (requirements), Step 2 (options), Step 3 (contact & review) map to
/// indices 0, 1, 2 respectively (Requirement 8.1).
class PreOrderStep {
  const PreOrderStep._();

  /// Requirements + reference uploads.
  static const int requirements = 0;

  /// Package tier + deadline + budget.
  static const int options = 1;

  /// Contact details, review of selections, and submission.
  static const int review = 2;

  /// Total number of steps in the flow.
  static const int count = 3;
}

/// Immutable state for the multi-step pre-order flow (Requirement 8).
///
/// Holds the draft fields the user is filling in ([requirements],
/// [packageTier], [deadline], [budget], [attachments]), the current [step],
/// the most recent [validation] result (so the UI can surface inline,
/// field-level errors via [DraftValidationResult.messageFor]), and the
/// [submission] [AsyncValue] which drives the loading button + success/failure
/// handling.
///
/// The idle submission state is `AsyncData<Order?>(null)`; a successful submit
/// stores the created [Order] in `AsyncData`, and a write failure stores the
/// error in `AsyncError` while every draft field is retained so the user can
/// retry without re-entering anything (Requirement 8.9).
class PreOrderState {
  /// Creates a pre-order state.
  const PreOrderState({
    required this.requirements,
    required this.packageTier,
    required this.deadline,
    required this.budget,
    required this.attachments,
    required this.step,
    required this.validation,
    required this.submission,
  });

  /// The initial, empty state at the start of the flow.
  const PreOrderState.initial()
      : requirements = '',
        packageTier = null,
        deadline = null,
        budget = null,
        attachments = const <String>[],
        step = PreOrderStep.requirements,
        validation = null,
        submission = const AsyncData<Order?>(null);

  /// Free-text requirements description (validated to be >= 10 chars).
  final String requirements;

  /// The chosen [PackageTier], or `null` until the user selects one.
  final PackageTier? packageTier;

  /// Optional desired deadline (must be in the future when set).
  final DateTime? deadline;

  /// Optional budget figure.
  final double? budget;

  /// Local paths/references of picked reference attachments.
  final List<String> attachments;

  /// The current zero-based step index (see [PreOrderStep]).
  final int step;

  /// The most recent validation result, or `null` if not yet validated.
  final DraftValidationResult? validation;

  /// The submission lifecycle: idle (`AsyncData(null)`), loading, success
  /// (`AsyncData(order)`), or failure (`AsyncError`).
  final AsyncValue<Order?> submission;

  /// Whether a submission is currently in flight.
  bool get isSubmitting => submission.isLoading;

  /// The error message for [field] from the latest [validation], or `null`.
  String? errorFor(DraftField field) => validation?.messageFor(field);

  /// Returns a copy of this state with the provided overrides.
  ///
  /// Nullable fields use the [_unset] sentinel so callers can explicitly clear
  /// them (e.g. `copyWith(deadline: null)` resets the deadline) without the
  /// usual `??` collapsing a deliberate `null` back to the old value.
  PreOrderState copyWith({
    String? requirements,
    Object? packageTier = _unset,
    Object? deadline = _unset,
    Object? budget = _unset,
    List<String>? attachments,
    int? step,
    Object? validation = _unset,
    AsyncValue<Order?>? submission,
  }) {
    return PreOrderState(
      requirements: requirements ?? this.requirements,
      packageTier: identical(packageTier, _unset)
          ? this.packageTier
          : packageTier as PackageTier?,
      deadline:
          identical(deadline, _unset) ? this.deadline : deadline as DateTime?,
      budget: identical(budget, _unset) ? this.budget : budget as double?,
      attachments: attachments ?? this.attachments,
      step: step ?? this.step,
      validation: identical(validation, _unset)
          ? this.validation
          : validation as DraftValidationResult?,
      submission: submission ?? this.submission,
    );
  }
}

/// Controller for the multi-step pre-order flow (Requirements 8.1–8.9).
///
/// Owns the [PreOrderState] for a single [ServiceListing] and exposes the
/// mutations the UI needs:
///
/// * field setters — [setRequirements], [setPackage], [setDeadline],
///   [setBudget], [addAttachment]/[removeAttachment];
/// * step navigation — [tryAdvance] (validates the current step before moving
///   forward) and [back];
/// * [submit] — performs full validation through [DefaultOrderService]
///   ([Requirement 8.4]); on failure it surfaces inline errors and keeps the
///   user on the relevant step *without* creating an order ([Requirement
///   8.5]); on success it persists the order via [OrderRepository.createOrder]
///   (which stamps the current client and notifies admins) and exposes the
///   created [Order]; on a write failure it records the error and retains the
///   draft so the user can retry ([Requirement 8.9]).
///
/// The order's `clientId`, the `pending` status, the single initial timeline
/// event, and admin notification are all handled by the repository/order
/// service, so this controller stays focused on presentation state.
class PreOrderController extends StateNotifier<PreOrderState> {
  /// Creates a controller for [listing], reading collaborators from [ref].
  PreOrderController({required this.ref, required this.listing})
      : super(const PreOrderState.initial());

  /// Provider ref used to read the order service and repository on demand.
  final Ref ref;

  /// The service being pre-ordered; supplies `serviceId`/`serviceTitle`.
  final ServiceListing listing;

  // ---------------------------------------------------------------------------
  // Field setters
  // ---------------------------------------------------------------------------

  /// Sets the free-text [requirements] description.
  void setRequirements(String value) {
    state = state.copyWith(requirements: value);
  }

  /// Selects the [PackageTier].
  void setPackage(PackageTier tier) {
    state = state.copyWith(packageTier: tier);
  }

  /// Sets (or clears, when [value] is `null`) the desired deadline.
  void setDeadline(DateTime? value) {
    state = state.copyWith(deadline: value);
  }

  /// Sets (or clears, when [value] is `null`) the budget figure.
  void setBudget(double? value) {
    state = state.copyWith(budget: value);
  }

  /// Appends a picked reference attachment [path] (ignores duplicates).
  void addAttachment(String path) {
    if (state.attachments.contains(path)) {
      return;
    }
    state = state.copyWith(
      attachments: <String>[...state.attachments, path],
    );
  }

  /// Removes a previously-added attachment [path].
  void removeAttachment(String path) {
    state = state.copyWith(
      attachments:
          state.attachments.where((String p) => p != path).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Step navigation
  // ---------------------------------------------------------------------------

  /// Validates the current step and, if it passes, advances to the next step.
  ///
  /// Returns `true` when the flow advanced; `false` when validation failed (in
  /// which case the inline errors are stored on the state and the step is
  /// unchanged). The final step does not advance — callers invoke [submit]
  /// there instead.
  bool tryAdvance() {
    final int current = state.step;
    final DraftValidationResult result = _validateStep(current);
    if (!result.isValid) {
      state = state.copyWith(validation: result);
      return false;
    }
    if (current >= PreOrderStep.review) {
      state = state.copyWith(validation: DraftValidationResult.valid);
      return false;
    }
    state = state.copyWith(
      step: current + 1,
      validation: DraftValidationResult.valid,
    );
    return true;
  }

  /// Moves back to the previous step, clearing any visible validation errors.
  void back() {
    if (state.step <= PreOrderStep.requirements) {
      return;
    }
    state = state.copyWith(
      step: state.step - 1,
      validation: DraftValidationResult.valid,
    );
  }

  /// Jumps directly to [step] (used by the stepper header for completed steps).
  void goToStep(int step) {
    if (step < PreOrderStep.requirements || step > PreOrderStep.review) {
      return;
    }
    state = state.copyWith(step: step);
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  /// Validates only the fields belonging to [step].
  ///
  /// Step navigation validates incrementally so a user is never blocked by an
  /// error that belongs to a later step. The same rules are enforced
  /// holistically by [DefaultOrderService.validateDraft] on [submit].
  DraftValidationResult _validateStep(int step) {
    final List<DraftValidationError> errors = <DraftValidationError>[];
    if (step == PreOrderStep.requirements) {
      final String? requirementsError =
          Validators.requirements(state.requirements);
      if (requirementsError != null) {
        errors.add(
          DraftValidationError(DraftField.requirements, requirementsError),
        );
      }
    } else if (step == PreOrderStep.options) {
      if (state.packageTier == null) {
        errors.add(
          const DraftValidationError(
            DraftField.packageTier,
            'Please select a package tier.',
          ),
        );
      }
      final String? deadlineError =
          Validators.futureDeadline(state.deadline, now: DateTime.now());
      if (deadlineError != null) {
        errors.add(DraftValidationError(DraftField.deadline, deadlineError));
      }
    }
    return errors.isEmpty
        ? DraftValidationResult.valid
        : DraftValidationResult(errors);
  }

  /// Builds an [OrderDraft] from the current state.
  ///
  /// Requires a selected [PackageTier]; callers ([submit]) guarantee this by
  /// checking `packageTier != null` first.
  OrderDraft buildDraft() {
    return OrderDraft(
      serviceId: listing.id,
      serviceTitle: listing.title,
      packageTier: state.packageTier!,
      requirements: state.requirements.trim(),
      attachments: List<String>.unmodifiable(state.attachments),
      budget: state.budget,
      deadline: state.deadline,
    );
  }

  // ---------------------------------------------------------------------------
  // Submission
  // ---------------------------------------------------------------------------

  /// Validates and submits the pre-order.
  ///
  /// On validation failure, surfaces inline errors and navigates the user back
  /// to the earliest step containing an error, returning `null` *without*
  /// creating an order (Requirement 8.5). On success, returns the created
  /// [Order]; on a write failure, records the error in [PreOrderState.submission]
  /// and retains the draft for retry (Requirement 8.9).
  Future<Order?> submit() async {
    // A tier is required to even construct a draft. Surface the error and send
    // the user back to the options step.
    if (state.packageTier == null) {
      state = state.copyWith(
        validation: const DraftValidationResult(<DraftValidationError>[
          DraftValidationError(
            DraftField.packageTier,
            'Please select a package tier.',
          ),
        ]),
        step: PreOrderStep.options,
      );
      return null;
    }

    final OrderDraft draft = buildDraft();
    final DefaultOrderService service = ref.read(orderServiceProvider);
    final DraftValidationResult result = service.validateDraft(draft);

    if (!result.isValid) {
      state = state.copyWith(
        validation: result,
        step: _firstStepForErrors(result),
      );
      return null;
    }

    state = state.copyWith(
      validation: DraftValidationResult.valid,
      submission: const AsyncLoading<Order?>(),
    );

    try {
      final Order order =
          await ref.read(orderRepositoryProvider).createOrder(draft);
      if (!mounted) {
        return order;
      }
      state = state.copyWith(submission: AsyncData<Order?>(order));
      return order;
    } catch (error, stackTrace) {
      // Non-blocking failure: retain the draft and expose the error so the UI
      // can show a SnackBar/banner and offer a retry (Requirement 8.9).
      if (mounted) {
        state = state.copyWith(
          submission: AsyncError<Order?>(error, stackTrace),
        );
      }
      return null;
    }
  }

  /// Clears a failed/successful submission back to idle so the button leaves
  /// its loading/error state (used after a SnackBar has been shown).
  void resetSubmission() {
    state = state.copyWith(submission: const AsyncData<Order?>(null));
  }

  /// The earliest step index that owns one of the errors in [result], so a
  /// failed full-submit returns the user to the right place.
  int _firstStepForErrors(DraftValidationResult result) {
    if (result.messageFor(DraftField.requirements) != null) {
      return PreOrderStep.requirements;
    }
    if (result.messageFor(DraftField.packageTier) != null ||
        result.messageFor(DraftField.deadline) != null) {
      return PreOrderStep.options;
    }
    return state.step;
  }
}

/// Provides a [PreOrderController] scoped to a specific [ServiceListing].
///
/// `autoDispose` so the draft is discarded when the flow is left, and a
/// `family` keyed by the [ServiceListing] (freezed value equality) so each
/// service gets its own independent draft.
final preOrderControllerProvider = StateNotifierProvider.autoDispose
    .family<PreOrderController, PreOrderState, ServiceListing>(
  (ref, listing) => PreOrderController(ref: ref, listing: listing),
);
