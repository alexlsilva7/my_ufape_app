import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Renders a document independently of viewport size, scrolling and animations.
Future<Uint8List> renderWidgetPng(
  BuildContext context,
  Widget document, {
  required double width,
  double pixelRatio = 2,
}) async {
  final boundary = RenderRepaintBoundary();
  final positioner = RenderPositionedBox(
    alignment: Alignment.topLeft,
    child: boundary,
  );
  final view = RenderView(
    view: View.of(context),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(Size(width, 20000)),
      physicalConstraints: BoxConstraints.tight(Size(width, 20000)),
      devicePixelRatio: 1,
    ),
    child: positioner,
  );
  final pipeline = PipelineOwner()..rootNode = view;
  final focus = FocusManager();
  final owner = BuildOwner(focusManager: focus);
  view.prepareInitialFrame();
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: document,
  ).attachToRenderTree(owner);
  try {
    owner.buildScope(root);
    pipeline.flushLayout();
    pipeline.flushCompositingBits();
    pipeline.flushPaint();
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Não foi possível gerar o PNG.');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
        .attachToRenderTree(owner, root);
    owner.buildScope(root);
    owner.finalizeTree();
    pipeline.rootNode = null;
    view.child = null;
    positioner.child = null;
    boundary.dispose();
    positioner.dispose();
    view.dispose();
    focus.dispose();
    pipeline.dispose();
  }
}
