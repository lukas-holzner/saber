import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  group('PDF and Image saving tests', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupMockPathProvider();

    FlavorConfig.setup();

    setUpAll(() async {
      await FileManager.init();
      EditorImage.shouldLoadOutImmediately = true;
    });

    tearDownAll(() {
      EditorImage.shouldLoadOutImmediately = false;
    });

    test('Saving note with PDF background and added image preserves all assets', () async {
      const filePath = '/test_pdf_with_image';
      const fullSbnPath = '$filePath${Editor.extension}';

      final mockPdfBytes = Uint8List.fromList([
        0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, // %PDF-1.4
        0x01, 0x02, 0x03, 0x04, 0x05,
      ]);

      final mockImageBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG magic
        0xAA, 0xBB, 0xCC, 0xDD,
      ]);

      // 1. Create a note with a PDF background
      final coreInfo = EditorCoreInfo(filePath: filePath);
      final pdfImage = PdfEditorImage(
        id: coreInfo.nextImageId++,
        assetCache: coreInfo.assetCache,
        pdfBytes: mockPdfBytes,
        pdfFile: null,
        pdfPage: 0,
        pageIndex: 0,
        pageSize: EditorPage.defaultSize,
        onMoveImage: null,
        onDeleteImage: null,
        onMiscChange: null,
        naturalSize: const Size(100, 100),
      );

      final page = EditorPage(
        size: EditorPage.defaultSize,
        backgroundImage: pdfImage,
      );
      coreInfo.pages.add(page);

      // Save initial note with PDF
      final (bson1, assets1) = coreInfo.saveToBinary(currentPageIndex: 0);
      final assetBytesList1 = await Future.wait([
        for (int i = 0; i < assets1.length; ++i) assets1.getBytes(i),
      ]);

      await Future.wait([
        FileManager.writeFile(fullSbnPath, bson1, awaitWrite: true),
        for (int i = 0; i < assets1.length; ++i)
          FileManager.writeFile(
            '$fullSbnPath.$i',
            assetBytesList1[i],
            awaitWrite: true,
          ),
        FileManager.removeUnusedAssets(fullSbnPath, numAssets: assets1.length),
      ]);
      coreInfo.updateAssetFiles(fullSbnPath);

      // Verify asset 0 is the PDF
      final writtenPdf = await FileManager.readFile('$fullSbnPath.0');
      expect(writtenPdf, isNotNull);
      expect(writtenPdf, mockPdfBytes);

      // 2. Add a PNG image to page 0
      final pngImage = PngEditorImage(
        id: coreInfo.nextImageId++,
        assetCache: coreInfo.assetCache,
        extension: '.png',
        imageProvider: MemoryImage(mockImageBytes),
        pageIndex: 0,
        pageSize: EditorPage.defaultSize,
        onMoveImage: null,
        onDeleteImage: null,
        onMiscChange: null,
      );
      page.images.add(pngImage);

      // Save note with both PDF background and PNG image
      final (bson2, assets2) = coreInfo.saveToBinary(currentPageIndex: 0);
      expect(assets2.length, 2);

      // Two-phase save
      final assetBytesList2 = await Future.wait([
        for (int i = 0; i < assets2.length; ++i) assets2.getBytes(i),
      ]);

      await Future.wait([
        FileManager.writeFile(fullSbnPath, bson2, awaitWrite: true),
        for (int i = 0; i < assets2.length; ++i)
          FileManager.writeFile(
            '$fullSbnPath.$i',
            assetBytesList2[i],
            awaitWrite: true,
          ),
        FileManager.removeUnusedAssets(fullSbnPath, numAssets: assets2.length),
      ]);
      coreInfo.updateAssetFiles(fullSbnPath);

      // 3. Verify both assets exist and match expected bytes
      final asset0Bytes = await FileManager.readFile('$fullSbnPath.0');
      final asset1Bytes = await FileManager.readFile('$fullSbnPath.1');

      expect(asset0Bytes, isNotNull);
      expect(asset1Bytes, isNotNull);

      // PDF is asset 0 (due to backgroundImage serialized before images)
      expect(asset0Bytes, mockPdfBytes);
      // PNG is asset 1
      expect(asset1Bytes, mockImageBytes);

      // 4. Reload from disk and verify
      final loadedCoreInfo = await EditorCoreInfo.loadFromFileContents(
        bsonBytes: bson2,
        path: filePath,
        onlyFirstPage: false,
      );

      expect(loadedCoreInfo.pages.length, 2);
      expect(loadedCoreInfo.pages.last.isEmpty, isTrue);
      final loadedPage = loadedCoreInfo.pages.first;
      expect(loadedPage.backgroundImage, isNotNull);
      expect(loadedPage.backgroundImage, isA<PdfEditorImage>());
      expect(loadedPage.images.length, 1);
      expect(loadedPage.images.first, isA<PngEditorImage>());

      // Clean up test files
      await FileManager.deleteFile(fullSbnPath, alsoUpload: false);
    });
  });
}
