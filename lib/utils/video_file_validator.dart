import 'dart:io';

class VideoFileValidator {
  const VideoFileValidator();

  Future<bool> isValid(File file) async {
    try {
      return await file.exists() && await file.length() > 0;
    } on FileSystemException {
      return false;
    }
  }
}
