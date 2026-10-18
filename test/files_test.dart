import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/services/files.dart';

void main() {
  test(
    'published profile IDs yield filenames accepted on Windows and mobile',
    () {
      expect(
        safeFileName('letras_Perfil 4/2024_progresso.json'),
        'letras_Perfil 4_2024_progresso.json',
      );
      expect(
        safeFileName(r'bcc_Perfil: A\B?_progresso.json'),
        'bcc_Perfil_ A_B__progresso.json',
      );
      expect(
        safeFileName('bcc_BCC03_progresso.json'),
        'bcc_BCC03_progresso.json',
      );
    },
  );
}
