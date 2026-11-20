import 'package:xml/xml.dart';

const wordNamespace =
    'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const relationshipNamespace =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

XmlElement? child(XmlElement parent, String localName) {
  for (final node in parent.childElements) {
    if (node.name.local == localName) return node;
  }
  return null;
}

Iterable<XmlElement> children(XmlElement parent, String localName) {
  return parent.childElements.where((node) => node.name.local == localName);
}

String? attribute(XmlElement element, String localName) {
  for (final attr in element.attributes) {
    if (attr.name.local == localName) return attr.value;
  }
  return null;
}

bool enabled(XmlElement? element) {
  if (element == null) return false;
  final value = attribute(element, 'val');
  return value == null || value == 'true' || value == '1' || value == 'on';
}

String escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

int halfPoints(dynamic value, int fallback) {
  if (value == null) return fallback;
  final parsed = double.tryParse(value.toString());
  return parsed == null ? fallback : (parsed * 2).round();
}

Map<String, dynamic>? stringAttributes(XmlElement element) {
  if (element.attributes.isEmpty) return null;
  return {for (final attr in element.attributes) attr.name.local: attr.value};
}
