import 'arabic_normalizer.dart';

class SearchOptions {
  const SearchOptions({
    this.caseSensitive = false,
    this.wholeWord = false,
    this.regex = false,
    this.normalizeArabic = true,
  });

  final bool caseSensitive;
  final bool wholeWord;
  final bool regex;
  final bool normalizeArabic;
}

class TextMatch {
  const TextMatch(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;
}

class TextSearchEngine {
  const TextSearchEngine();

  List<TextMatch> findAll(
    String source,
    String query, {
    SearchOptions options = const SearchOptions(),
  }) {
    if (query.isEmpty) return const [];
    if (options.regex) {
      return RegExp(
        query,
        caseSensitive: options.caseSensitive,
      ).allMatches(source).where((m) => m.end > m.start).map((m) {
        return TextMatch(m.start, m.end, m.group(0)!);
      }).toList(growable: false);
    }
    final normalizer = const ArabicNormalizer();
    final normalizedSource = options.normalizeArabic
        ? normalizer.normalizeWithOffsets(source)
        : null;
    var haystack = normalizedSource?.text ?? source;
    var needle = options.normalizeArabic ? normalizer.normalize(query) : query;
    if (!options.caseSensitive) {
      haystack = haystack.toLowerCase();
      needle = needle.toLowerCase();
    }
    final matches = <TextMatch>[];
    var from = 0;
    while (from <= haystack.length - needle.length) {
      final index = haystack.indexOf(needle, from);
      if (index < 0) break;
      final end = index + needle.length;
      if (!options.wholeWord || _isWholeWord(haystack, index, end)) {
        final start = normalizedSource?.sourceStart(index) ?? index;
        final sourceEnd = normalizedSource?.sourceEnd(end) ?? end;
        matches.add(TextMatch(start, sourceEnd, source.substring(start, sourceEnd)));
      }
      from = end;
    }
    return List.unmodifiable(matches);
  }

  String replaceAll(
    String source,
    String query,
    String replacement, {
    SearchOptions options = const SearchOptions(),
  }) {
    if (options.regex) {
      return source.replaceAllMapped(
        RegExp(query, caseSensitive: options.caseSensitive),
        (match) => _expandReplacement(replacement, match),
      );
    }
    final matches = findAll(source, query, options: options);
    final output = StringBuffer();
    var cursor = 0;
    for (final match in matches) {
      output
        ..write(source.substring(cursor, match.start))
        ..write(replacement);
      cursor = match.end;
    }
    output.write(source.substring(cursor));
    return output.toString();
  }

  String _expandReplacement(String template, Match match) {
    return template.replaceAllMapped(RegExp(r'\$(\d+)'), (ref) {
      final group = int.parse(ref.group(1)!);
      return group <= match.groupCount ? match.group(group) ?? '' : ref.group(0)!;
    });
  }

  bool _isWholeWord(String text, int start, int end) {
    bool word(int codePoint) => RegExp(r'[\p{L}\p{N}_]', unicode: true)
        .hasMatch(String.fromCharCode(codePoint));
    final before = start > 0 && word(text.substring(0, start).runes.last);
    final after = end < text.length && word(text.substring(end).runes.first);
    return !before && !after;
  }
}
