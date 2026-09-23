import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class TextRecognitionService {
  TextRecognitionService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> captureLatinText() async {
    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(image.path));
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
