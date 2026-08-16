import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/text_box.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/quill_styles.dart';

class CanvasTextBox extends StatefulWidget {
  const CanvasTextBox({
    super.key,
    required this.textBox,
    required this.coreInfo,
    required this.pageIndex,
    required this.readOnly,
    required this.isTextEditing,
    required this.onDelete,
    this.onChange,
  });

  final EditorTextBox textBox;
  final EditorCoreInfo coreInfo;
  final int pageIndex;
  final bool readOnly;
  final bool isTextEditing;
  final void Function(EditorTextBox textBox) onDelete;
  final VoidCallback? onChange;

  @override
  State<CanvasTextBox> createState() => _CanvasTextBoxState();
}

class _CanvasTextBoxState extends State<CanvasTextBox> {
  Offset? _resizeStartFocalPoint;
  Rect? _resizeStartRect;

  Offset? _moveStartFocalPoint;
  Rect? _moveStartRect;

  @override
  void initState() {
    super.initState();
    widget.textBox.quill.controller.document.changes.listen((_) {
      widget.onChange?.call();
    });
    widget.textBox.quill.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.textBox.quill.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (!widget.textBox.quill.focusNode.hasFocus) {
      widget.textBox.isEditing = false;
      // Auto-delete if user leaves the text box completely empty
      if (widget.textBox.isEmpty) {
        widget.onDelete(widget.textBox);
      }
    } else {
      widget.textBox.isEditing = true;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final invert = stows.editorAutoInvert.value && brightness == Brightness.dark;

    final textBox = widget.textBox;
    final isSelected = textBox.selected;
    final isEditing = textBox.isEditing;
    final showControls = !widget.readOnly && (isEditing || isSelected);

    final quillEditor = QuillEditor(
      controller: textBox.quill.controller,
      config: QuillEditorConfig(
        customStyles: SaberQuillStyles.get(
          invert: invert,
          secondary: colorScheme.secondary,
          lineHeight: widget.coreInfo.lineHeight,
        ),
        scrollable: false,
        autoFocus: false,
        expands: true,
        placeholder: showControls ? t.editor.quill.typeSomething : null,
        showCursor: isEditing && !widget.readOnly,
        keyboardAppearance: invert ? Brightness.dark : Brightness.light,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      scrollController: ScrollController(),
      focusNode: textBox.quill.focusNode,
    );

    // Extra top margin when controls are visible
    const double headerHeight = 28.0;

    return Positioned(
      left: textBox.dstRect.left,
      top: showControls ? textBox.dstRect.top - headerHeight : textBox.dstRect.top,
      width: textBox.dstRect.width,
      height: showControls ? textBox.dstRect.height + headerHeight : textBox.dstRect.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showControls)
            Container(
              height: headerHeight,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                border: Border(
                  top: BorderSide(color: colorScheme.primary, width: 1.5),
                  left: BorderSide(color: colorScheme.primary, width: 1.5),
                  right: BorderSide(color: colorScheme.primary, width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  // Move drag handle
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      _moveStartFocalPoint = details.globalPosition;
                      _moveStartRect = textBox.dstRect;
                    },
                    onPanUpdate: (details) {
                      if (_moveStartFocalPoint == null || _moveStartRect == null) return;
                      final delta = details.globalPosition - _moveStartFocalPoint!;
                      final pageSize = widget.coreInfo.pages[widget.pageIndex].size;
                      final newLeft = (_moveStartRect!.left + delta.dx).clamp(
                        0.0,
                        pageSize.width - EditorTextBox.minWidth,
                      );
                      final newTop = (_moveStartRect!.top + delta.dy).clamp(
                        0.0,
                        pageSize.height - EditorTextBox.minHeight,
                      );
                      setState(() {
                        textBox.dstRect = Rect.fromLTWH(
                          newLeft,
                          newTop,
                          textBox.dstRect.width,
                          textBox.dstRect.height,
                        );
                      });
                      widget.onChange?.call();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Delete button
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      widget.onDelete(textBox);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (widget.readOnly) return;
                textBox.isEditing = true;
                textBox.quill.focusNode.requestFocus();
                setState(() {});
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.08)
                      : (showControls
                          ? colorScheme.surface.withValues(alpha: 0.85)
                          : Colors.transparent),
                  border: Border.all(
                    color: showControls
                        ? colorScheme.primary
                        : Colors.transparent,
                    width: 1.5,
                  ),
                  borderRadius: showControls
                      ? const BorderRadius.vertical(bottom: Radius.circular(6))
                      : BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: widget.readOnly || !isEditing,
                        child: quillEditor,
                      ),
                    ),
                    if (showControls)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (details) {
                            _resizeStartFocalPoint = details.globalPosition;
                            _resizeStartRect = textBox.dstRect;
                          },
                          onPanUpdate: (details) {
                            if (_resizeStartFocalPoint == null || _resizeStartRect == null) return;
                            final delta = details.globalPosition - _resizeStartFocalPoint!;
                            final newWidth = (_resizeStartRect!.width + delta.dx).clamp(
                              EditorTextBox.minWidth,
                              2000.0,
                            );
                            final newHeight = (_resizeStartRect!.height + delta.dy).clamp(
                              EditorTextBox.minHeight,
                              2000.0,
                            );
                            setState(() {
                              textBox.dstRect = Rect.fromLTWH(
                                textBox.dstRect.left,
                                textBox.dstRect.top,
                                newWidth,
                                newHeight,
                              );
                            });
                            widget.onChange?.call();
                          },
                          child: Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.south_east,
                              size: 12,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
