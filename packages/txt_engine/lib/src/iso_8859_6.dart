/// ISO-8859-6 Arabic/Latin single-byte codec.
///
/// Undefined byte positions are rejected. Characters outside the standard
/// (for example Eastern Arabic digits and em dash) are not silently replaced.
class Iso88596Codec {
  const Iso88596Codec();

  String decode(List<int> bytes) {
    return String.fromCharCodes(bytes.map((byte) {
      if (byte <= 0x9F || byte == 0xA0 || byte == 0xAD) return byte;
      if (byte == 0xA4) return 0x00A4;
      if (byte == 0xAC) return 0x060C;
      if (byte == 0xBB) return 0x061B;
      if (byte == 0xBF) return 0x061F;
      if (byte >= 0xC1 && byte <= 0xDA) return byte - 0xC1 + 0x0621;
      if (byte >= 0xE0 && byte <= 0xF2) return byte - 0xE0 + 0x0640;
      throw FormatException('Undefined ISO-8859-6 byte: $byte');
    }));
  }

  List<int> encode(String text) {
    return text.runes.map((rune) {
      if (rune <= 0x9F || rune == 0xA0 || rune == 0xAD) return rune;
      if (rune == 0xA4) return 0xA4;
      if (rune == 0x060C) return 0xAC;
      if (rune == 0x061B) return 0xBB;
      if (rune == 0x061F) return 0xBF;
      if (rune >= 0x0621 && rune <= 0x063A) return rune - 0x0621 + 0xC1;
      if (rune >= 0x0640 && rune <= 0x0652) return rune - 0x0640 + 0xE0;
      throw FormatException(
        'Character U+${rune.toRadixString(16).toUpperCase()} is not representable in ISO-8859-6.',
      );
    }).toList(growable: false);
  }
}
