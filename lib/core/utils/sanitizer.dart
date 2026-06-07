/// Input sanitization helpers for free-text fields.
///
/// Per the design's error-handling section and Requirement 16.4
/// ("IF any free-text input contains unsafe content, THEN THE Keyframes_App
/// SHALL sanitize the input before persistence."), every free-text value
/// (chat messages, order requirements, profile names, listing descriptions,
/// etc.) must be cleaned before it is written to Firestore or the local cache.
///
/// The goals are to:
///   * remove markup that could be interpreted as HTML/script if the text is
///     ever rendered in a web context (defence-in-depth XSS hardening);
///   * strip invisible / control characters that can be used for spoofing or
///     that corrupt stored data;
///   * normalize whitespace so stored values are tidy and comparable;
///   * optionally clamp length so a single field can't bloat a document.
///
/// These functions are pure and dependency-free so they can be reused from any
/// layer (controllers, repositories, tests).
library;

/// Matches an entire `<script>...</script>` block (including its contents),
/// case-insensitively and across newlines. Removed wholesale so script bodies
/// never survive sanitization.
final RegExp _scriptBlock = RegExp(
  r'<script\b[^>]*>[\s\S]*?</script\s*>',
  caseSensitive: false,
);

/// Matches a `<style>...</style>` block (including its contents).
final RegExp _styleBlock = RegExp(
  r'<style\b[^>]*>[\s\S]*?</style\s*>',
  caseSensitive: false,
);

/// Matches any remaining HTML/XML tag, e.g. `<b>`, `</div>`, `<img ... />`.
final RegExp _htmlTag = RegExp(r'<\/?[a-zA-Z][^>]*>');

/// Matches a `javascript:` (or `vbscript:`) URI scheme used in injection
/// payloads such as `href="javascript:..."`.
final RegExp _dangerousScheme = RegExp(
  r'(javascript|vbscript|data)\s*:',
  caseSensitive: false,
);

/// Matches control characters (C0 and C1 ranges) except the common whitespace
/// characters tab (\t), newline (\n) and carriage return (\r), which are
/// normalized separately. Also strips the DEL character (\x7F).
final RegExp _controlChars = RegExp(
  '[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]',
);

/// Matches zero-width and bidi-control characters that can be used to hide or
/// spoof text (zero-width space/joiner, BOM, LTR/RTL overrides, etc.).
final RegExp _invisibleChars = RegExp(
  '[\u200B-\u200F\u202A-\u202E\u2060-\u2064\uFEFF]',
);

/// Collapses any run of whitespace into a single space.
final RegExp _collapseWhitespace = RegExp(r'[ \t\f\v]+');

/// Collapses 3+ consecutive newlines down to a maximum of two (one blank line).
final RegExp _collapseNewlines = RegExp(r'\n{3,}');

/// Sanitizes a free-text [input] before it is persisted.
///
/// The transformation, in order, is:
///   1. remove `<script>` and `<style>` blocks including their contents;
///   2. strip any remaining HTML/XML tags;
///   3. neutralize dangerous URI schemes (`javascript:`, `vbscript:`,
///      `data:`);
///   4. remove control and invisible/bidi characters;
///   5. normalize line endings to `\n` and collapse redundant whitespace;
///   6. trim leading/trailing whitespace;
///   7. clamp the result to [maxLength] characters when provided.
///
/// Returns a cleaned string that is safe to store. The function never returns
/// `null`; a `null` [input] yields an empty string.
String sanitizeText(String? input, {int? maxLength}) {
  if (input == null || input.isEmpty) return '';

  var output = input;

  // 1. Drop script/style blocks entirely (content included).
  output = output.replaceAll(_scriptBlock, '');
  output = output.replaceAll(_styleBlock, '');

  // 2. Remove any other markup tags, leaving their text content behind.
  output = output.replaceAll(_htmlTag, '');

  // 3. Neutralize dangerous URI schemes that may remain in plain text.
  output = output.replaceAll(_dangerousScheme, '');

  // 4. Strip control and invisible characters.
  output = output.replaceAll(_controlChars, '');
  output = output.replaceAll(_invisibleChars, '');

  // 5. Normalize line endings and collapse redundant whitespace.
  output = output.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  output = output.replaceAll(_collapseWhitespace, ' ');
  output = output.replaceAll(_collapseNewlines, '\n\n');

  // 6. Trim outer whitespace (and any spaces left hugging newlines).
  output = output
      .split('\n')
      .map((line) => line.trim())
      .join('\n')
      .trim();

  // 7. Optionally clamp the length.
  if (maxLength != null && maxLength >= 0 && output.length > maxLength) {
    output = output.substring(0, maxLength).trimRight();
  }

  return output;
}

/// Escapes HTML-significant characters in [input] so the text can be rendered
/// verbatim in an HTML/web context without being interpreted as markup.
///
/// This is the "escape" counterpart to [sanitizeText]'s "strip" approach. Use
/// it when the original characters must be preserved (e.g. displaying code or
/// user text exactly) rather than removed.
String escapeHtml(String? input) {
  if (input == null || input.isEmpty) return '';
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

/// Returns `true` if [input] appears to contain unsafe content that
/// [sanitizeText] would alter — markup, dangerous URI schemes, or
/// control/invisible characters.
///
/// Useful for validation messaging ("we cleaned up your input") or for tests.
bool containsUnsafeContent(String? input) {
  if (input == null || input.isEmpty) return false;
  return _scriptBlock.hasMatch(input) ||
      _styleBlock.hasMatch(input) ||
      _htmlTag.hasMatch(input) ||
      _dangerousScheme.hasMatch(input) ||
      _controlChars.hasMatch(input) ||
      _invisibleChars.hasMatch(input);
}
