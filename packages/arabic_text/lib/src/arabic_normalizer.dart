class ArabicNormalizer {
  const ArabicNormalizer({
    this.ignoreDiacritics = true,
    this.unifyAlef = true,
    this.unifyYeh = true,
    this.unifyTeh = false,
    this.unifyNumerals = true,
    this.removeTatweel = true,
  });

  final bool ignoreDiacritics;
  final bool unifyAlef;
  final bool unifyYeh;
  final bool unifyTeh;
  final bool unifyNumerals;
  final bool removeTatweel;

  String normalize(String input) {
    final output = StringBuffer();
    for (final code in input.runes) {
      if (ignoreDiacritics &&
          ((code >= 0x064B && code <= 0x065F) ||
              code == 0x0670 ||
              (code >= 0x06D6 && code <= 0x06ED))) {
        continue;
      }
      if (removeTatweel && code == 0x0640) continue;
      var normalized = code;
      if (unifyAlef &&
          const {0x0622, 0x0623, 0x0625, 0x0627, 0x0671}.contains(code)) {
        normalized = 0x0627;
      }
      if (unifyYeh && const {0x0649, 0x064A, 0x06CC}.contains(code)) {
        normalized = 0x064A;
      }
      if (unifyTeh && const {0x0629, 0x0647}.contains(code)) {
        normalized = 0x0647;
      }
      if (unifyNumerals) {
        if (code >= 0x0660 && code <= 0x0669) {
          normalized = 0x30 + code - 0x0660;
        } else if (code >= 0x06F0 && code <= 0x06F9) {
          normalized = 0x30 + code - 0x06F0;
        }
      }
      output.writeCharCode(normalized);
    }
    return output.toString();
  }

  NormalizedText normalizeWithOffsets(String input) {
    final text = StringBuffer();
    final offsets = <int>[];
    var sourceIndex = 0;
    for (final code in input.runes) {
      final sourceStart = sourceIndex;
      sourceIndex += code > 0xFFFF ? 2 : 1;
      final normalized = normalize(String.fromCharCode(code));
      if (normalized.isEmpty) continue;
      text.write(normalized);
      for (var i = 0; i < normalized.length; i++) {
        offsets.add(sourceStart);
      }
    }
    return NormalizedText(text.toString(), offsets, sourceIndex);
  }
}

class NormalizedText {
  const NormalizedText(this.text, this.sourceOffsets, this.sourceLength);
  final String text;
  final List<int> sourceOffsets;
  final int sourceLength;

  int sourceStart(int normalizedIndex) => sourceOffsets[normalizedIndex];
  int sourceEnd(int normalizedEnd) => normalizedEnd >= sourceOffsets.length
      ? sourceLength
      : sourceOffsets[normalizedEnd];
}

String convertNumerals(String input, {required bool eastern}) {
  return String.fromCharCodes(
    input.runes.map((code) {
      if (eastern && code >= 0x30 && code <= 0x39) {
        return 0x0660 + code - 0x30;
      }
      if (!eastern && code >= 0x0660 && code <= 0x0669) {
        return 0x30 + code - 0x0660;
      }
      if (!eastern && code >= 0x06F0 && code <= 0x06F9) {
        return 0x30 + code - 0x06F0;
      }
      return code;
    }),
  );
}
