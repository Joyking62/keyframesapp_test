import 'package:flutter_test/flutter_test.dart';
import 'package:keyframes_app/core/utils/sanitizer.dart';

/// Unit tests for the free-text input sanitizer.
///
/// These verify that unsafe content (script/style blocks, HTML tags, dangerous
/// URI schemes, and control/invisible characters) is removed before text is
/// persisted, that [escapeHtml] escapes markup-significant characters, and that
/// [containsUnsafeContent] detects content the sanitizer would alter.
///
/// _Requirements: 16.4 (sanitize unsafe free-text before persistence)._
void main() {
  group('sanitizeText', () {
    test('returns an empty string for null or empty input', () {
      expect(sanitizeText(null), '');
      expect(sanitizeText(''), '');
    });

    test('removes <script> blocks including their contents', () {
      expect(
        sanitizeText('<script>alert("xss")</script>Hello'),
        'Hello',
      );
      expect(
        sanitizeText('<SCRIPT type="text/javascript">evil()</SCRIPT>Safe'),
        'Safe',
      );
    });

    test('removes <style> blocks including their contents', () {
      expect(
        sanitizeText('<style>body{display:none}</style>Visible'),
        'Visible',
      );
    });

    test('strips remaining HTML/XML tags but keeps their text content', () {
      expect(sanitizeText('<b>Bold</b>'), 'Bold');
      expect(sanitizeText('<p>Hello <em>World</em></p>'), 'Hello World');
      expect(sanitizeText('Self<br/>closing'), 'Selfclosing');
    });

    test('neutralizes dangerous URI schemes', () {
      // The "javascript:" scheme is stripped, leaving the remaining text.
      expect(sanitizeText('javascript:alert(1)'), 'alert(1)');
      expect(sanitizeText('vbscript:msgbox(1)'), 'msgbox(1)');
      expect(sanitizeText('data:text/html'), 'text/html');
    });

    test('strips control characters', () {
      expect(sanitizeText('Hello\u0000World'), 'HelloWorld');
      expect(sanitizeText('A\u0007B\u007FC'), 'ABC');
    });

    test('strips zero-width and bidi-control (invisible) characters', () {
      expect(sanitizeText('Hi\u200Bthere'), 'Hithere');
      expect(sanitizeText('Left\u202Eright'), 'Leftright');
      expect(sanitizeText('Word\uFEFFmark'), 'Wordmark');
    });

    test('collapses redundant whitespace and trims the result', () {
      expect(sanitizeText('a     b'), 'a b');
      expect(sanitizeText('   padded   '), 'padded');
      expect(sanitizeText('line1\r\nline2'), 'line1\nline2');
    });

    test('clamps the output to maxLength when provided', () {
      expect(sanitizeText('abcdefghij', maxLength: 5), 'abcde');
      // Shorter than the limit is returned unchanged.
      expect(sanitizeText('abc', maxLength: 5), 'abc');
    });

    test('leaves already-clean text unchanged', () {
      expect(sanitizeText('Hello World'), 'Hello World');
    });
  });

  group('escapeHtml', () {
    test('returns an empty string for null or empty input', () {
      expect(escapeHtml(null), '');
      expect(escapeHtml(''), '');
    });

    test('escapes the five HTML-significant characters', () {
      expect(escapeHtml('<b>'), '&lt;b&gt;');
      expect(escapeHtml('Tom & Jerry'), 'Tom &amp; Jerry');
      expect(escapeHtml('"quoted"'), '&quot;quoted&quot;');
      expect(escapeHtml("it's"), 'it&#39;s');
    });

    test('escapes ampersands before other entities to avoid double-encoding',
        () {
      expect(
        escapeHtml('<a href="x">'),
        '&lt;a href=&quot;x&quot;&gt;',
      );
    });

    test('leaves text without special characters unchanged', () {
      expect(escapeHtml('plain text'), 'plain text');
    });
  });

  group('containsUnsafeContent', () {
    test('returns false for null, empty, or clean input', () {
      expect(containsUnsafeContent(null), isFalse);
      expect(containsUnsafeContent(''), isFalse);
      expect(containsUnsafeContent('Hello World'), isFalse);
    });

    test('detects script and style blocks', () {
      expect(containsUnsafeContent('<script>x()</script>'), isTrue);
      expect(containsUnsafeContent('<style>.a{}</style>'), isTrue);
    });

    test('detects stray HTML tags', () {
      expect(containsUnsafeContent('text <b>bold</b>'), isTrue);
    });

    test('detects dangerous URI schemes', () {
      expect(containsUnsafeContent('javascript:alert(1)'), isTrue);
      expect(containsUnsafeContent('data:text/html'), isTrue);
    });

    test('detects control and invisible characters', () {
      expect(containsUnsafeContent('Hello\u0000World'), isTrue);
      expect(containsUnsafeContent('Hi\u200Bthere'), isTrue);
    });
  });
}
