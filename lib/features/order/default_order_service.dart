import 'package:keyframes_app/core/utils/validators.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_draft.dart';
import 'package:keyframes_app/data/models/order_status_event.dart';
import 'package:keyframes_app/features/order/order_service.dart';

/// Callback fired when a new pre-order is created.
///
/// Injected into [DefaultOrderService] so the pure lifecycle logic stays
/// decoupled from any messaging backend. Defaults to a no-op in tests.
typedef NewOrderNotifier = Future<void> Function(Order order);

/// Callback fired when an order's status changes.
///
/// Injected into [DefaultOrderService] so the pure lifecycle logic stays
/// decoupled from any messaging backend. Defaults to a no-op in tests.
typedef StatusChangeNotifier =
    Future<void> Function(Order order, OrderStatus status);

/// Thrown by [DefaultOrderService.appendStatusEvent] when a requested status
/// transition is not permitted by the order lifecycle rules.
///
/// Carries the offending [from]/[to] pair for diagnostics. The input order is
/// never mutated when this is thrown (Requirement 10A.4).
class InvalidOrderTransitionException implements Exception {
  /// Creates an exception describing an illegal `from -> to` transition.
  const InvalidOrderTransitionException(this.from, this.to);

  /// The order's status before the rejected transition.
  final OrderStatus from;

  /// The status the caller attempted to move to.
  final OrderStatus to;

  @override
  String toString() =>
      'InvalidOrderTransitionException: ${from.name} -> ${to.name} '
      'is not a valid order status transition.';
}

/// The field of an [OrderDraft] that failed validation.
enum DraftField {
  /// The free-text requirements (must be at least 10 characters).
  requirements,

  /// The desired deadline (must be in the future when set).
  deadline,

  /// The selected package tier (must be present).
  packageTier,
}

/// A single validation failure against an [OrderDraft], pairing the offending
/// [field] with a human-readable [message].
class DraftValidationError {
  /// Creates a validation error for [field] with the given [message].
  const DraftValidationError(this.field, this.message);

  /// The draft field that failed validation.
  final DraftField field;

  /// A human-readable description of the failure.
  final String message;

  @override
  String toString() => '${field.name}: $message';
}

/// The outcome of validating an [OrderDraft].
///
/// [isValid] is `true` only when [errors] is empty. Callers can inspect
/// [errors] (or use [messageFor]) to surface field-level feedback in the UI.
class DraftValidationResult {
  /// Creates a result wrapping zero or more [errors].
  const DraftValidationResult(this.errors);

  /// A result representing a fully valid draft (no errors).
  static const DraftValidationResult valid =
      DraftValidationResult(<DraftValidationError>[]);

  /// All validation failures found; empty when the draft is valid.
  final List<DraftValidationError> errors;

  /// Whether the draft passed every validation rule.
  bool get isValid => errors.isEmpty;

  /// The error message for [field], or `null` if [field] is valid.
  String? messageFor(DraftField field) {
    for (final error in errors) {
      if (error.field == field) {
        return error.message;
      }
    }
    return null;
  }

  @override
  String toString() =>
      isValid ? 'DraftValidationResult.valid' : 'DraftValidationResult($errors)';
}

/// Thrown by [DefaultOrderService.buildInitialOrder] when the supplied
/// [OrderDraft] fails validation, carrying the full [result] for inspection.
class DraftValidationException implements Exception {
  /// Creates an exception wrapping a failing [result].
  const DraftValidationException(this.result);

  /// The validation result describing every failure.
  final DraftValidationResult result;

  @override
  String toString() => 'DraftValidationException(${result.errors})';
}

/// The concrete, pure implementation of the [OrderService] contract.
///
/// This service is the single source of truth for the order lifecycle:
///
/// * [isValidTransition] encodes the allowed graph
///   `pending -> inReview -> inProgress -> completed`, plus any non-`completed`
///   status -> `cancelled`. Self/illegal transitions are rejected.
/// * [appendStatusEvent] is a pure function: it returns a brand-new [Order]
///   with one [OrderStatusEvent] appended, keeps `status == timeline.last
///   .status`, clamps the new event's timestamp so the timeline is
///   non-decreasing, and throws an [InvalidOrderTransitionException] (without
///   mutating the input) on an illegal transition.
/// * [validateDraft] enforces the pre-order rules (requirements length,
///   future deadline, selected tier) and [buildInitialOrder] constructs the
///   initial `pending` [Order] with a single timeline event.
///
/// Notification side effects are injected as callbacks ([onNewOrder] /
/// [onStatusChange]) that default to no-ops, so the lifecycle logic remains
/// pure and trivially testable.
class DefaultOrderService implements OrderService {
  /// Creates the service with optional, injectable notification hooks.
  ///
  /// When omitted, the hooks default to no-ops, keeping the service free of
  /// side effects for unit and property-based testing.
  const DefaultOrderService({
    NewOrderNotifier? onNewOrder,
    StatusChangeNotifier? onStatusChange,
  })  : _onNewOrder = onNewOrder,
        _onStatusChange = onStatusChange;

  final NewOrderNotifier? _onNewOrder;
  final StatusChangeNotifier? _onStatusChange;

  /// The note attached to the initial `pending` status event.
  static const String initialStatusNote = 'Pre-order received';

  /// The allowed transition graph, keyed by current status. Terminal states
  /// (`completed`, `cancelled`) map to an empty set of successors.
  static const Map<OrderStatus, Set<OrderStatus>> _allowedTransitions =
      <OrderStatus, Set<OrderStatus>>{
    OrderStatus.pending: <OrderStatus>{
      OrderStatus.inReview,
      OrderStatus.cancelled,
    },
    OrderStatus.inReview: <OrderStatus>{
      OrderStatus.inProgress,
      OrderStatus.cancelled,
    },
    OrderStatus.inProgress: <OrderStatus>{
      OrderStatus.completed,
      OrderStatus.cancelled,
    },
    OrderStatus.completed: <OrderStatus>{},
    OrderStatus.cancelled: <OrderStatus>{},
  };

  // ---------------------------------------------------------------------------
  // Task 6.1 - transition validation & pure timeline append
  // ---------------------------------------------------------------------------

  @override
  bool isValidTransition(OrderStatus from, OrderStatus to) {
    // A no-op self-transition is never valid, and terminal states have no
    // successors. `from == to` is implicitly rejected because no status lists
    // itself as a successor. (Requirements 10A.4)
    return _allowedTransitions[from]?.contains(to) ?? false;
  }

  @override
  Order appendStatusEvent(
    Order order,
    OrderStatus status, {
    String? note,
    DateTime? at,
  }) {
    // Reject illegal transitions WITHOUT mutating the input. (Req 10A.4)
    if (!isValidTransition(order.status, status)) {
      throw InvalidOrderTransitionException(order.status, status);
    }

    // Establish the timestamp floor so the timeline is non-decreasing.
    // (Requirement 10A.3)
    final DateTime floor =
        order.timeline.isNotEmpty ? order.timeline.last.at : order.createdAt;
    final DateTime requested = at ?? DateTime.now();
    final DateTime eventAt = requested.isBefore(floor) ? floor : requested;

    final OrderStatusEvent event = OrderStatusEvent(
      status: status,
      note: note,
      at: eventAt,
    );

    // copyWith returns a new Order; `order` is left untouched. The current
    // status is kept equal to the last timeline entry. (Requirements 10A.1,
    // 10A.2)
    return order.copyWith(
      status: status,
      timeline: <OrderStatusEvent>[...order.timeline, event],
    );
  }

  // ---------------------------------------------------------------------------
  // Task 6.2 - pre-order draft validation & initial order construction
  // ---------------------------------------------------------------------------

  /// Validates an [OrderDraft] against the pre-order rules.
  ///
  /// Enforces (Requirements 8.4, 8.6 / Correctness Property 4):
  /// * `requirements.length >= 10` (delegated to [Validators.requirements]);
  /// * `deadline == null || deadline > now` (delegated to
  ///   [Validators.futureDeadline]);
  /// * a selected [PackageTier].
  ///
  /// [now] defaults to [DateTime.now] and is injectable for deterministic
  /// tests. Returns a [DraftValidationResult]; never throws.
  DraftValidationResult validateDraft(OrderDraft draft, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final List<DraftValidationError> errors = <DraftValidationError>[];

    final String? requirementsError = Validators.requirements(draft.requirements);
    if (requirementsError != null) {
      errors.add(DraftValidationError(DraftField.requirements, requirementsError));
    }

    final String? deadlineError =
        Validators.futureDeadline(draft.deadline, now: reference);
    if (deadlineError != null) {
      errors.add(DraftValidationError(DraftField.deadline, deadlineError));
    }

    // `OrderDraft.packageTier` is statically non-nullable, so the "a tier is
    // selected" rule is structurally guaranteed by the type system. The check
    // is retained for completeness so the invariant is explicit and survives
    // any future change that makes the field nullable.
    // ignore: unnecessary_null_comparison
    if (draft.packageTier == null) {
      errors.add(
        const DraftValidationError(
          DraftField.packageTier,
          'Please select a package tier.',
        ),
      );
    }

    return errors.isEmpty
        ? DraftValidationResult.valid
        : DraftValidationResult(errors);
  }

  /// Builds the initial [Order] for a validated [draft].
  ///
  /// The created order has status [OrderStatus.pending] and a timeline holding
  /// exactly one `pending` [OrderStatusEvent] timestamped at [createdAt].
  /// (Requirement 8.6)
  ///
  /// Throws a [DraftValidationException] if [draft] fails [validateDraft], so
  /// no invalid order is ever constructed (Requirement 8.5 / Property 4).
  ///
  /// [id] and [clientId] are supplied by the caller. [createdAt] defaults to
  /// [now] (or [DateTime.now]); both are injectable for deterministic tests.
  Order buildInitialOrder({
    required String id,
    required String clientId,
    required OrderDraft draft,
    DateTime? createdAt,
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final DraftValidationResult result = validateDraft(draft, now: reference);
    if (!result.isValid) {
      throw DraftValidationException(result);
    }

    final DateTime created = createdAt ?? reference;

    return Order(
      id: id,
      clientId: clientId,
      serviceId: draft.serviceId,
      serviceTitle: draft.serviceTitle,
      packageTier: draft.packageTier,
      requirements: draft.requirements,
      attachments: draft.attachments,
      budget: draft.budget,
      deadline: draft.deadline,
      status: OrderStatus.pending,
      timeline: <OrderStatusEvent>[
        OrderStatusEvent(
          status: OrderStatus.pending,
          note: initialStatusNote,
          at: created,
        ),
      ],
      createdAt: created,
    );
  }

  // ---------------------------------------------------------------------------
  // Notification hooks (injectable; default to no-ops)
  // ---------------------------------------------------------------------------

  @override
  Future<void> notifyAdminsOfNewOrder(Order order) async {
    final NewOrderNotifier? hook = _onNewOrder;
    if (hook != null) {
      await hook(order);
    }
  }

  @override
  Future<void> notifyClientOfStatusChange(Order order, OrderStatus status) async {
    final StatusChangeNotifier? hook = _onStatusChange;
    if (hook != null) {
      await hook(order, status);
    }
  }
}
