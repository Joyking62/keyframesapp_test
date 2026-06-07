import 'package:flutter_test/flutter_test.dart';
import 'package:keyframes_app/core/utils/validators.dart';

/// Unit tests for [Validators].
///
/// Validators follow the Flutter form-field convention: a `null` return means
/// the value is valid, while a non-null [String] is the error message shown to
/// the user.
///
/// _Requirements: 16.1 (email/name/phone), 16.2 (base price/title), 8.4
/// (requirements length & future deadline)._
void main() {
  group('Validators.email', () {
    test('returns null for well-formed addresses', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email('first.last@sub.domain.org'), isNull);
      expect(Validators.email('name+tag@domain.co'), isNull);
      expect(Validators.email('a_b%c-d@mail-server.io'), isNull);
    });

    test('trims surrounding whitespace before validating', () {
      expect(Validators.email('  user@example.com  '), isNull);
    });

    test('rejects null or empty input as required', () {
      expect(Validators.email(null), 'Email is required.');
      expect(Validators.email(''), 'Email is required.');
      expect(Validators.email('   '), 'Email is required.');
    });

    test('rejects malformed addresses', () {
      const message = 'Enter a valid email address.';
      expect(Validators.email('plainaddress'), message);
      expect(Validators.email('missing-domain-dot@domain'), message);
      expect(Validators.email('@nodomain.com'), message);
      expect(Validators.email('user@.com'), message);
      expect(Validators.email('user name@example.com'), message);
    });
  });

  group('Validators.name', () {
    test('accepts names within the 2-60 character bounds', () {
      expect(Validators.name('Jo'), isNull); // lower bound (2)
      expect(Validators.name('Ada Lovelace'), isNull);
      expect(Validators.name('a' * Validators.nameMax), isNull); // upper bound
    });

    test('trims before measuring length', () {
      expect(Validators.name('  Al  '), isNull); // "Al" -> 2 chars
    });

    test('rejects null or empty input as required', () {
      expect(Validators.name(null), 'Name is required.');
      expect(Validators.name(''), 'Name is required.');
      expect(Validators.name('   '), 'Name is required.');
    });

    test('rejects names outside the bounds', () {
      final message =
          'Name must be between ${Validators.nameMin} and ${Validators.nameMax} characters.';
      expect(Validators.name('A'), message); // below min (1)
      expect(Validators.name('a' * (Validators.nameMax + 1)), message); // 61
    });
  });

  group('Validators.phone', () {
    test('treats null/empty as valid because the field is optional', () {
      expect(Validators.phone(null), isNull);
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('   '), isNull);
    });

    test('accepts numbers with 7-15 digits and common formatting', () {
      expect(Validators.phone('1234567'), isNull); // 7 digits (lower bound)
      expect(Validators.phone('+1 (234) 567-8901'), isNull); // 11 digits
      expect(Validators.phone('123456789012345'), isNull); // 15 digits (upper)
    });

    test('rejects digit counts below 7 or above 15', () {
      final message =
          'Phone number must have ${Validators.phoneDigitsMin} to ${Validators.phoneDigitsMax} digits.';
      expect(Validators.phone('123456'), message); // 6 digits
      expect(Validators.phone('1234567890123456'), message); // 16 digits
    });

    test('rejects disallowed characters', () {
      expect(Validators.phone('12a4567'), 'Enter a valid phone number.');
      expect(Validators.phone('555#1234'), 'Enter a valid phone number.');
    });
  });

  group('Validators.requirements', () {
    test('accepts text of at least the minimum length', () {
      expect(Validators.requirements('Need a brand new logo'), isNull);
      expect(
        Validators.requirements('x' * Validators.requirementsMin),
        isNull,
      ); // exactly 10
    });

    test('rejects null or empty input as required', () {
      expect(Validators.requirements(null), 'Requirements are required.');
      expect(Validators.requirements(''), 'Requirements are required.');
      expect(Validators.requirements('    '), 'Requirements are required.');
    });

    test('rejects text shorter than the minimum length', () {
      final result = Validators.requirements('short'); // 5 chars
      expect(result, isNotNull);
      expect(result, contains('${Validators.requirementsMin}'));
    });

    test('trims before measuring length', () {
      // "abc" is only 3 chars after trimming -> too short.
      expect(Validators.requirements('   abc   '), isNotNull);
    });
  });

  group('Validators.futureDeadline', () {
    final now = DateTime(2025, 1, 1, 12, 0, 0);

    test('treats null deadline as valid because it is optional', () {
      expect(Validators.futureDeadline(null, now: now), isNull);
    });

    test('accepts a deadline strictly after the reference time', () {
      expect(
        Validators.futureDeadline(now.add(const Duration(days: 1)), now: now),
        isNull,
      );
    });

    test('rejects a deadline in the past', () {
      expect(
        Validators.futureDeadline(now.subtract(const Duration(days: 1)),
            now: now),
        'Deadline must be in the future.',
      );
    });

    test('rejects a deadline equal to the reference time', () {
      expect(
        Validators.futureDeadline(now, now: now),
        'Deadline must be in the future.',
      );
    });
  });

  group('Validators.basePrice', () {
    test('accepts zero and positive values', () {
      expect(Validators.basePrice(0), isNull);
      expect(Validators.basePrice(0.0), isNull);
      expect(Validators.basePrice(99.99), isNull);
      expect(Validators.basePrice(1000), isNull);
    });

    test('rejects null as required', () {
      expect(Validators.basePrice(null), 'Base price is required.');
    });

    test('rejects negative and NaN values', () {
      const message = 'Base price must be 0 or greater.';
      expect(Validators.basePrice(-1), message);
      expect(Validators.basePrice(-0.01), message);
      expect(Validators.basePrice(double.nan), message);
    });
  });

  group('Validators.title', () {
    test('accepts titles within the 3-80 character bounds', () {
      expect(Validators.title('Web'), isNull); // lower bound (3)
      expect(Validators.title('Logo Design Package'), isNull);
      expect(Validators.title('a' * Validators.titleMax), isNull); // upper
    });

    test('rejects null or empty input as required', () {
      expect(Validators.title(null), 'Title is required.');
      expect(Validators.title(''), 'Title is required.');
      expect(Validators.title('   '), 'Title is required.');
    });

    test('rejects titles outside the bounds', () {
      final message =
          'Title must be between ${Validators.titleMin} and ${Validators.titleMax} characters.';
      expect(Validators.title('ab'), message); // below min (2)
      expect(Validators.title('a' * (Validators.titleMax + 1)), message); // 81
    });
  });
}
