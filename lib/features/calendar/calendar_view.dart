import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/files.dart';
import 'calendar_view_model.dart';
import 'widgets/calendar_document_viewer.dart';

export 'calendar_view_model.dart'
    show academicCalendarPage, calendarPageAspectRatio;

class CalendarView extends StatefulWidget {
  const CalendarView({super.key, required this.viewModel});
  final CalendarViewModel viewModel;
  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  int get page => widget.viewModel.page;
  late Timer monthTimer;
  String month = '';
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_pageChanged);
    month = _month();
    monthTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final next = _month();
      if (month != next) {
        month = next;
        widget.viewModel.showCurrentMonth();
      }
    });
  }

  void _pageChanged() {
    if (mounted) setState(() {});
  }

  String _month() => DateTime.now()
      .toUtc()
      .subtract(const Duration(hours: 3))
      .toIso8601String()
      .substring(0, 7);

  Future<void> _downloadPdf() async {
    try {
      final data = await rootBundle.load(
        'assets/calendar/calendario-academico-ufape-2026.pdf',
      );
      await saveBytes(
        'calendario-academico-ufape-2026.pdf',
        data.buffer.asUint8List(),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao salvar PDF: $error')));
      }
    }
  }

  @override
  void dispose() {
    monthTimer.cancel();
    widget.viewModel.removeListener(_pageChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CalendarDocumentViewer(
    page: page,
    onPageChanged: widget.viewModel.setPage,
    onCurrentMonth: widget.viewModel.showCurrentMonth,
    onDownload: _downloadPdf,
  );
}
