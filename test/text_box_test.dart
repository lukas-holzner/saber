import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/editor/text_box.dart';
import 'package:saber/data/tools/select.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorTextBox and Page integration tests', () {
    test('EditorTextBox json serialization and deserialization', () {
      final doc = Document();
      doc.insert(0, 'Hello Arbitrary Text Box!');
      final controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      final focusNode = FocusNode();

      final textBox = EditorTextBox(
        id: 12345,
        pageIndex: 0,
        dstRect: const Rect.fromLTWH(100, 200, 300, 80),
        quill: QuillStruct(controller: controller, focusNode: focusNode),
        color: Colors.blue,
      );

      final json = textBox.toJson();
      expect(json['id'], 12345);
      expect(json['i'], 0);
      expect(json['x'], 100);
      expect(json['y'], 200);
      expect(json['w'], 300);
      expect(json['h'], 80);
      expect(json['q'], isNotNull);

      final loadedTextBox = EditorTextBox.fromJson(json);
      expect(loadedTextBox.id, 12345);
      expect(loadedTextBox.pageIndex, 0);
      expect(loadedTextBox.dstRect, const Rect.fromLTWH(100, 200, 300, 80));
      expect(
        loadedTextBox.quill.controller.document.toPlainText().trim(),
        'Hello Arbitrary Text Box!',
      );

      textBox.dispose();
      loadedTextBox.dispose();
    });

    test('EditorPage correctly serializes and deserializes textBoxes', () {
      final doc = Document();
      doc.insert(0, 'Annotation at bottom right');
      final controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      final focusNode = FocusNode();

      final textBox = EditorTextBox(
        id: 42,
        pageIndex: 0,
        dstRect: const Rect.fromLTWH(500, 600, 250, 60),
        quill: QuillStruct(controller: controller, focusNode: focusNode),
      );

      final page = EditorPage(
        textBoxes: [textBox],
      );

      expect(page.isEmpty, isFalse);
      expect(page.textBoxes.length, 1);

      final assets = OrderedAssetCache();
      final json = page.toJson(assets);
      expect(json.containsKey('tb'), isTrue);

      final loadedPage = EditorPage.fromJson(
        json,
        inlineAssets: null,
        readOnly: false,
        fileVersion: 2,
        sbnPath: '/test/note.sbn2',
        assetCache: AssetCache(),
      );

      expect(loadedPage.textBoxes.length, 1);
      expect(loadedPage.textBoxes.first.dstRect, const Rect.fromLTWH(500, 600, 250, 60));
      expect(
        loadedPage.textBoxes.first.quill.controller.document.toPlainText().trim(),
        'Annotation at bottom right',
      );

      page.dispose();
      loadedPage.dispose();
    });

    test('Select tool selects textBoxes and handles duplication/movement', () {
      final doc = Document();
      doc.insert(0, 'Selectable text');
      final controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      final focusNode = FocusNode();

      final textBox = EditorTextBox(
        id: 1,
        pageIndex: 0,
        dstRect: const Rect.fromLTWH(100, 100, 200, 50),
        quill: QuillStruct(controller: controller, focusNode: focusNode),
      );

      final select = Select.currentSelect;
      select.onDragStart(const Offset(50, 50), 0);
      select.onDragUpdate(const Offset(350, 50));
      select.onDragUpdate(const Offset(350, 200));
      select.onDragUpdate(const Offset(50, 200));
      select.onDragEnd([], [], [textBox]);

      expect(select.doneSelecting, isTrue);
      expect(select.selectResult.textBoxes.length, 1);
      expect(select.selectResult.textBoxes.first.id, 1);

      final duplicate = textBox.copy(offset: const Offset(20, 20));
      expect(duplicate.dstRect, const Rect.fromLTWH(120, 120, 200, 50));
      expect(
        duplicate.quill.controller.document.toPlainText().trim(),
        'Selectable text',
      );

      select.unselect();
      textBox.dispose();
      duplicate.dispose();
    });

    test('EditorPage.cloneForRasterization preserves textBoxes for export', () {
      final doc = Document();
      doc.insert(0, 'Exported Text');
      final controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      final focusNode = FocusNode();

      final textBox = EditorTextBox(
        id: 7,
        pageIndex: 0,
        dstRect: const Rect.fromLTWH(150, 250, 180, 45),
        quill: QuillStruct(controller: controller, focusNode: focusNode),
      );

      final page = EditorPage(textBoxes: [textBox]);
      final clonedPage = page.cloneForRasterization();

      expect(clonedPage.textBoxes.length, 1);
      expect(clonedPage.textBoxes.first.dstRect, const Rect.fromLTWH(150, 250, 180, 45));
      expect(
        clonedPage.textBoxes.first.quill.controller.document.toPlainText().trim(),
        'Exported Text',
      );

      page.dispose();
      clonedPage.disposeClonedData();
    });
  });
}
