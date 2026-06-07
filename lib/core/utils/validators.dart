/// Centralized, framework-agnostic input validators for the Keyframes app.
///
/// Each validator follows the Flutter form-field convention: it returns `null`
/// when the value is valid, or a human-readable error message [String] when it
/// is invalid. This lets the same functions be used directly as
/// `FormFieldValidator`s in `flutter_form_builder` and also be called
/// imperatively from controllers/use-cases (e.g. pre-order submission).
///
/// These rules map directly to the design's "Validation Rules" and to
/// Requirements 16.1, 16.2, and 8.4:
/// - email: valid email format
/// - name: 2–60 characters
/// - phone: optional, but if present must contain 7–15 digits
/// - requirements: at least 10 characters
/// - future-deadline: if set, must be later than "now"
/// - base-price: greater than or equal to 0
/// - title: 3–80 characters
library;

/// A collection of pure, stateless validators.
///
/// All methods are static; the class is not meant to be instantiated.
abstract final class Validators {
  /// Minimum/maximum bounds, centralized so tests and UI can reference them.
  static const int nameMin = 2;
  static const int nameMax = 60;
  static const int phoneDigitsMin = 7;
  static const int phoneDigitsMax = 15;
  static const int requirementsMin = 10;
  static const int titleMin = 3;
  static const int titleMax = 80;

  /// Pragmatic email pattern: `local@domain.tld` with no whitespace and at
  /// least one dot in the domain. Intentionally permissive enough for real
  /// addresses while rejecting obviously malformed input.
  static final RegExp _emailRegExp = RegExp(
    r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)+$",
  );

  /// Matches a single digit; used to count the digits in a phone number.
  static final RegExp _digitRegExp = RegExp(r'\d');

  /// Validates that [value] is a well-formed email address.
  ///
  /// Returns `null` when valid. (Requirement 16.1)
  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return 'Email is required.';
    }
    if (!_emailRegExp.hasMatch(input)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// Validates that [value] is a name of [nameMin]–[nameMax] characters
  /// (after trimming surrounding whitespace).
  ///
  /// Returns `null` when valid. (Requirement 16.1)
  static String? name(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return 'Name is required.';
    }
    if (input.length < nameMin || input.length > nameMax) {
      return 'Name must be between $nameMin and $nameMax characters.';
    }
    return null;
  }

  /// Validates an optional phone number.
  ///
  /// An empty or `null` value is considered valid (the field is optional). When
  /// a value is present it must contain between [phoneDigitsMin] and
  /// [phoneDigitsMax] digits. Common formatting characters (`+`, spaces, `-`,
  /// `()`, and `.`) are permitted; any other character is rejected.
  ///
  /// Returns `null` when valid. (Requirement 16.1)
  static String? phone(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      // Phone is optional.
      return null;
    }
    // Only allow digits and common phone-formatting characters.
    if (!RegExp(r'^[+\d\s\-().]+$').hasMatch(input)) {
      return 'Enter a valid phone number.';
    }
    final digitCount = _digitRegExp.allMatches(input).length;
    if (digitCount < phoneDigitsMin || digitCount > phoneDigitsMax) {
      return 'Phone number must have $phoneDigitsMin to $phoneDigitsMax digits.';
    }
    return null;
  }

  /// Validates that an order's requirements text has at least
  /// [requirementsMin] characters (after trimming).
  ///
  /// Returns `null` when valid. (Requirements 8.4, design pre-order validity)
  static String? requirements(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return 'Requirements are required.';
    }
    if (input.length < requirementsMin) {
      return 'Please provide at least $requirementsMin characters describing '
          'your requirements.';
    }
    return null;
  }

  /// Validates an optional deadline.
  ///
  /// A `null` deadline is valid (the field is optional). When a deadline is
  /// provided it must be strictly later than [now] (which defaults to
  /// [DateTime.now]).
  ///
  /// Returns `null` when valid. (Requirement 8.4)
  static String? futureDeadline(DateTime? value, {DateTime? now}) {
    if (value == null) {
      // Deadline is optional.
      return null;
    }
    final reference = now ?? DateTime.now();
    if (!value.isAfter(reference)) {
      return 'Deadline must be in the future.';
    }
    return null;
  }

  /// Validates that a service base price is greater than or equal to 0.
  ///
  /// Returns `null` when valid. (Requirement 16.2)
  static String? basePrice(num? value) {
    if (value == null) {
      return 'Base price is required.';
    }
    if (value.isNaN || value < 0) {
      return 'Base price must be 0 or greater.';
    }
    return null;
  }

  /// Validates that a service [value] (title) is [titleMin]–[titleMax]
  /// characters (after trimming).
  ///
  /// Returns `null` when valid. (Requirement 16.2)
  static String? title(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return 'Title is required.';
    }
    if (input.length < titleMin || input.length > titleMax) {
      return 'Title must be between $titleMin and $titleMax characters.';
    }
    return null;
  }
}
