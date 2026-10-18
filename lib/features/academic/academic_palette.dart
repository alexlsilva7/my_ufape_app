import 'package:flutter/material.dart';

/// Colors shared by the academic screens; state-specific accents stay explicit.
@immutable
class AcademicPalette {
  const AcademicPalette(this.brightness);

  factory AcademicPalette.of(BuildContext context) =>
      AcademicPalette(Theme.of(context).brightness);

  final Brightness brightness;
  bool get dark => brightness == Brightness.dark;
  Color get surface => dark ? const Color(0xff0f172a) : Colors.white;
  Color get canvas => dark ? const Color(0xff020617) : const Color(0xfff8fafc);
  Color get border => dark ? const Color(0xff1e293b) : const Color(0xffe2e8f0);
  Color get strongBorder =>
      dark ? const Color(0xff334155) : const Color(0xffe2e8f0);
  Color get ink => dark ? const Color(0xffe2e8f0) : const Color(0xff334155);
  Color get muted => dark ? const Color(0xff94a3b8) : const Color(0xff64748b);
  Color get indigo => dark ? const Color(0xffa5b4fc) : const Color(0xff4f46e5);

  Color matrixStatusColor(String status) => switch (status) {
    'concluido' => dark ? const Color(0xff6ee7b7) : const Color(0xff047857),
    'cursando' => dark ? const Color(0xfffcd34d) : const Color(0xff92400e),
    _ => dark ? const Color(0xffcbd5e1) : const Color(0xff475569),
  };
}
