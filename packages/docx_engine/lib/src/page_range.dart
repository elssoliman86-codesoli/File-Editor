List<int> parsePageRanges(String input, int pageCount) {
  final pages = <int>[];
  for (final token in input.split(',')) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) continue;
    final match = RegExp(r'^(\d+)(?:\s*-\s*(\d+))?$').firstMatch(trimmed);
    if (match == null) throw FormatException('Invalid page range: $trimmed');
    final start = int.parse(match.group(1)!);
    final end = int.parse(match.group(2) ?? match.group(1)!);
    if (start < 1 || end < start || end > pageCount) {
      throw RangeError('Page range $trimmed is outside 1-$pageCount.');
    }
    for (var page = start; page <= end; page++) {
      if (!pages.contains(page)) pages.add(page);
    }
  }
  if (pages.isEmpty) throw const FormatException('Select at least one page.');
  return pages;
}
