import 'dart:io';

class PdfFileValidator {
  const PdfFileValidator();

  static const List<int> _signature = [0x25, 0x50, 0x44, 0x46, 0x2D];

  Future<bool> isValid(File file) async {
    try {
      if (!await file.exists() || await file.length() == 0) return false;

      final handle = await file.open();
      try {
        final bytes = await handle.read(1024);
        for (
          var index = 0;
          index <= bytes.length - _signature.length;
          index++
        ) {
          var matches = true;
          for (var offset = 0; offset < _signature.length; offset++) {
            if (bytes[index + offset] != _signature[offset]) {
              matches = false;
              break;
            }
          }
          if (matches) return true;
        }
        return false;
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      return false;
    }
  }
}
