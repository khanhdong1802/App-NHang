import 'dart:async';
import 'dart:html' as html;
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
  final input = html.FileUploadInputElement()
    ..accept = accept.join(',')
    ..multiple = false;

  final c = Completer<PickedImageBytes?>();

  void safeComplete(PickedImageBytes? v) {
    if (!c.isCompleted) c.complete(v);
  }

  input.onChange.listen((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) return safeComplete(null);

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);

    reader.onError.listen((_) => safeComplete(null));
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        safeComplete(PickedImageBytes(
          bytes: Uint8List.view(result),
          name: file.name,
          mime: file.type,
        ));
      } else {
        safeComplete(null);
      }
    });
  });

  // user cancel => không có onChange, nên set timeout nhẹ
  Timer(const Duration(minutes: 3), () => safeComplete(null));

  input.click();
  return c.future;
}
