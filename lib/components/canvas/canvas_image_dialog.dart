import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
import 'package:saber/components/theming/adaptive_switch.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';

class CanvasImageDialog extends StatefulWidget {
  const new({
    super.key,
    required this.filePath,
    required this.image,
    required this.redrawImage,
    required this.isBackground,
    required this.toggleAsBackground,
    this.singleRow = false,
  });

  final String filePath;
  final EditorImage image;
  final VoidCallback redrawImage;

  final bool isBackground;
  final VoidCallback? toggleAsBackground;

  final bool singleRow;

  @override
  State<CanvasImageDialog> createState() => _CanvasImageDialogState();
}

class _CanvasImageDialogState extends State<CanvasImageDialog> {
  void setInvertible([bool? value]) => setState(() {
    widget.image.invertible = value ?? !widget.image.invertible;
    widget.image.onMiscChange?.call();
    widget.redrawImage();
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      MergeSemantics(
        child: _CanvasImageDialogItem(
          onTap: stows.editorAutoInvert.value ? setInvertible : null,
          title: t.editor.imageOptions.invertible,
          child: AdaptiveSwitch(
            value: widget.image.invertible,
            onChanged: stows.editorAutoInvert.value ? setInvertible : null,
            thumbIcon: WidgetStateProperty.all(
              widget.image.invertible
                  ? const Icon(Icons.invert_colors)
                  : const Icon(Icons.invert_colors_off),
            ),
          ),
        ),
      ),
      _CanvasImageDialogItem(
        onTap: () async {
          final filePathSanitized = widget.filePath.replaceAll(
            RegExp(r'[^a-zA-Z\d]'),
            '_',
          );
          final imageFileName =
              'image$filePathSanitized${widget.image.id}${widget.image.extension}';
          final Uint8List bytes;
          switch (widget.image) {
            case final PdfEditorImage image:
              bytes =
                  image.pdfBytes ??
                  await image.pdfFile?.readAsBytes() ??
                  (throw ArgumentError.value(
                    image,
                    'image',
                    'PDF image has no bytes or file',
                  ));
            case final SvgEditorImage image:
              bytes = switch (image.svgLoader) {
                (final SvgStringLoader loader) => utf8.encode(
                  loader.provideSvg(null),
                ),
                (final SvgFileLoader loader) => await loader.file.readAsBytes(),
                (_) => throw ArgumentError.value(
                  image.svgLoader,
                  'svgLoader',
                  'Unknown SVG loader type',
                ),
              };
            case final PngEditorImage image:
              if (image.imageProvider is MemoryImage) {
                bytes = (image.imageProvider as MemoryImage).bytes;
              } else if (image.imageProvider is FileImage) {
                bytes = await (image.imageProvider as FileImage).file
                    .readAsBytes();
              } else {
                throw ArgumentError.value(
                  image.imageProvider,
                  'imageProvider',
                  'Unknown image provider type',
                );
              }
          }
          if (!context.mounted) return;
          FileManager.exportFile(
            imageFileName,
            bytes,
            isImage: true,
            context: context,
          );
          Navigator.of(context).pop();
        },
        title: t.editor.imageOptions.download,
        child: const AdaptiveIcon(
          icon: Icons.download,
          cupertinoIcon: CupertinoIcons.arrow_down_circle_fill,
        ),
      ),
      _CanvasImageDialogItem(
        onTap: () {
          widget.toggleAsBackground?.call();
          Navigator.of(context).pop();
        },
        title: widget.isBackground
            ? t.editor.imageOptions.removeAsBackground
            : t.editor.imageOptions.setAsBackground,
        child: const AdaptiveIcon(
          icon: Icons.wallpaper,
          cupertinoIcon: CupertinoIcons.photo_fill_on_rectangle_fill,
        ),
      ),
      _CanvasImageDialogItem(
        onTap: () {
          if (widget.isBackground) {
            widget.toggleAsBackground?.call();
          }
          widget.image.onDeleteImage?.call(widget.image);
          widget.redrawImage();
          Navigator.of(context).pop();
        },
        title: t.editor.imageOptions.delete,
        child: const AdaptiveIcon(
          icon: Icons.delete_outline,
          cupertinoIcon: CupertinoIcons.trash,
        ),
      ),
    ];

    if (widget.singleRow) {
      return SizedBox(
        height: 84,
        child: Row(
          children: [
            for (final child in children)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: child,
                ),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 270,
      height: 180,
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.4,
        children: children,
      ),
    );
  }
}

class _CanvasImageDialogItem extends StatelessWidget {
  const _CanvasImageDialogItem({
    // ignore: unused_element_parameter
    super.key,
    required this.onTap,
    required this.title,
    required this.child,
  });

  final VoidCallback? onTap;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Material(
      color: colorScheme.primary.withValues(alpha: 0.07),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: Center(child: child)),
              const SizedBox(height: 2),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
