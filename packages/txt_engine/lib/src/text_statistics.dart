class TextStatistics {
  const TextStatistics(
    this.characters,
    this.words,
    this.lines,
    this.paragraphs,
  );
  final int characters;
  final int words;
  final int lines;
  final int paragraphs;

  factory TextStatistics.from(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final words = RegExp(
      r'[\p{L}\p{N}]+(?:[\u2019'
      "'"
      '-][\p{L}\p{N}]+)*',
      unicode: true,
    ).allMatches(normalized).length;
    return TextStatistics(
      text.length,
      words,
      normalized.isEmpty ? 0 : '\n'.allMatches(normalized).length + 1,
      normalized
            .split(RegExp(r'(?:\n\s*){2,}'))
            .where((String part) => part.trim().isNotEmpty)
          .length,
    );
  }
}
