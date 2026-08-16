import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:saber/data/editor/page.dart';

class EditorTextBox extends ChangeNotifier {
  EditorTextBox({
    required this.id,
    required this.pageIndex,
    required this.dstRect,
    required this.quill,
    this.color,
  });

  final int id;
  int pageIndex;
  Rect dstRect;
  final QuillStruct quill;
  Color? color;

  bool _selected = false;
  bool get selected => _selected;
  set selected(bool value) {
    if (_selected == value) return;
    _selected = value;
    notifyListeners();
  }

  bool _isEditing = false;
  bool get isEditing => _isEditing;
  set isEditing(bool value) {
    if (_isEditing == value) return;
    _isEditing = value;
    notifyListeners();
  }

  static double defaultWidth = 200.0;
  static double defaultHeight = 60.0;
  static double minWidth = 80.0;
  static double minHeight = 36.0;

  bool get isEmpty => quill.controller.document.isEmpty();

  Map<String, dynamic> toJson() => {
    'id': id,
    'i': pageIndex,
    'x': dstRect.left,
    'y': dstRect.top,
    'w': dstRect.width,
    'h': dstRect.height,
    if (!quill.controller.document.isEmpty())
      'q': quill.controller.document.toDelta().toJson(),
    if (color != null) 'c': color!.toARGB32(),
  };

  factory EditorTextBox.fromJson(Map<String, dynamic> json) {
    final deltaJson = json['q'] as List?;
    final doc = deltaJson != null
        ? Document.fromJson(deltaJson)
        : Document();

    final controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    final focusNode = FocusNode(debugLabel: 'TextBox Quill Focus Node');

    final left = (json['x'] as num?)?.toDouble() ?? 0.0;
    final top = (json['y'] as num?)?.toDouble() ?? 0.0;
    final width = (json['w'] as num?)?.toDouble() ?? defaultWidth;
    final height = (json['h'] as num?)?.toDouble() ?? defaultHeight;

    final colorInt = json['c'] as int?;

    return EditorTextBox(
      id: json['id'] as int? ?? Random().nextInt(0x7fffffff),
      pageIndex: json['i'] as int? ?? 0,
      dstRect: Rect.fromLTWH(left, top, width, height),
      quill: QuillStruct(controller: controller, focusNode: focusNode),
      color: colorInt != null ? Color(colorInt) : null,
    );
  }

  EditorTextBox copy({int? newId, int? newPageIndex, Offset? offset}) {
    final newRect = offset != null ? dstRect.shift(offset) : dstRect;
    final newDoc = Document.fromDelta(quill.controller.document.toDelta());
    final newController = QuillController(
      document: newDoc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    final newFocusNode = FocusNode(debugLabel: 'TextBox Copy Focus Node');

    return EditorTextBox(
      id: newId ?? Random().nextInt(0x7fffffff),
      pageIndex: newPageIndex ?? pageIndex,
      dstRect: newRect,
      quill: QuillStruct(controller: newController, focusNode: newFocusNode),
      color: color,
    );
  }

  EditorTextBox cloneForScreenshot() {
    return EditorTextBox(
      id: id,
      pageIndex: pageIndex,
      dstRect: dstRect,
      quill: quill.cloneForScreenshot(),
      color: color,
    );
  }

  @override
  void dispose() {
    quill.dispose();
    super.dispose();
  }
}
