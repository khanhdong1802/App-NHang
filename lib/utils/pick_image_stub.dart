import 'dart:typed_data';

class PickedImageBytes {
  final Uint8List bytes;
  final String name;
  final String mime;

  PickedImageBytes({
    required this.bytes,
    required this.name,
    required this.mime,
  });
}

Future<PickedImageBytes?> pickImageBytesWeb({
  List<String> accept = const ["image/*"],
}) async {
  // Không chạy trên web
  return null;
}
