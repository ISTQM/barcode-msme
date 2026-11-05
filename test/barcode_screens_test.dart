import 'dart:io';

import 'package:barcode_msme/core/barcode_codec.dart';
import 'package:barcode_msme/core/label_geometry.dart';
import 'package:barcode_msme/cubit/barcode_cubit.dart';
import 'package:barcode_msme/cubit/inventory_cubit.dart';
import 'package:barcode_msme/data/barcode_repository.dart';
import 'package:barcode_msme/data/inventory_item.dart';
import 'package:barcode_msme/data/inventory_repository.dart';
import 'package:barcode_msme/data/product_barcode.dart';
import 'package:barcode_msme/screens/barcode_create_screen.dart';
import 'package:barcode_msme/screens/barcode_library_screen.dart';
import 'package:barcode_msme/screens/label_export_screen.dart';
import 'package:barcode_msme/widgets/item_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeInventoryRepository implements InventoryRepository {
  final Map<String, InventoryItem> items = {};

  @override
  List<InventoryItem> all() => items.values.toList();

  @override
  InventoryItem? find(String barcode) => items[barcode];

  @override
  Future<void> put(InventoryItem item) async => items[item.barcode] = item;

  @override
  Future<void> delete(String barcode) async => items.remove(barcode);
}

class FakeBarcodeRepository implements BarcodeRepository {
  final Map<String, ProductBarcode> items = {};

  @override
  List<ProductBarcode> all() => items.values.toList();

  @override
  ProductBarcode? find(String barcode) => items[barcode];

  @override
  Future<void> put(ProductBarcode product) async =>
      items[product.barcode] = product;

  @override
  Future<void> delete(String barcode) async => items.remove(barcode);

  @override
  Future<String> savePhoto(File source, String barcode) =>
      throw UnimplementedError();

  @override
  File? photoFile(String? name) => null;
}

late FakeInventoryRepository inventory;
late FakeBarcodeRepository barcodes;

Future<void> pumpScreen(WidgetTester tester, Widget home) async {
  // Tall enough that the whole form is built without scrolling.
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => InventoryCubit(inventory)),
        BlocProvider(create: (_) => BarcodeCubit(barcodes)),
      ],
      child: MaterialApp(home: home),
    ),
  );
}

ProductBarcode product({String code = '2000000000008', String name = 'Rice'}) {
  return ProductBarcode(
    barcode: code,
    symbology: BarcodeSymbology.ean13,
    style: LabelStyle.withName,
    name: name,
    createdAt: DateTime(2026, 11, 5),
    priceCentavos: 5000,
  );
}

Finder get saveButton =>
    find.widgetWithText(FilledButton, 'Save & Continue to Print');

Finder field(String label) => find.widgetWithText(TextField, label);

void main() {
  setUp(() {
    inventory = FakeInventoryRepository();
    barcodes = FakeBarcodeRepository();
  });

  group('Barcodes tab', () {
    testWidgets('shows an empty state that opens the create screen',
        (tester) async {
      await pumpScreen(tester, const BarcodeLibraryScreen());
      expect(find.text('No barcodes yet'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'New Barcode'));
      await tester.pumpAndSettle();
      expect(find.byType(BarcodeCreateScreen), findsOneWidget);
    });

    testWidgets('lists barcodes and says whether each is in inventory',
        (tester) async {
      barcodes.items['2000000000008'] = product();
      barcodes.items['2000000000015'] =
          product(code: '2000000000015', name: 'Sugar');
      inventory.items['2000000000008'] = InventoryItem(
        barcode: '2000000000008',
        name: 'Rice',
        quantity: 0,
        scannedAt: DateTime(2026, 11, 5),
      );
      await pumpScreen(tester, const BarcodeLibraryScreen());

      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('Sugar'), findsOneWidget);
      expect(find.text('In inventory'), findsOneWidget);
      expect(find.textContaining('Not in inventory'), findsOneWidget);
    });

    testWidgets('deleting asks first and leaves inventory alone',
        (tester) async {
      barcodes.items['2000000000008'] = product();
      inventory.items['2000000000008'] = InventoryItem(
        barcode: '2000000000008',
        name: 'Rice',
        quantity: 3,
        scannedAt: DateTime(2026, 11, 5),
      );
      await pumpScreen(tester, const BarcodeLibraryScreen());

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Rice?'), findsOneWidget);
      expect(barcodes.items, isNotEmpty);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(barcodes.items, isEmpty);
      expect(inventory.items['2000000000008']!.quantity, 3);
    });
  });

  group('Create screen', () {
    testWidgets('needs a product name before it can save', (tester) async {
      await pumpScreen(tester, const BarcodeCreateScreen());
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

      await tester.enterText(field('Product name'), 'Lucky Me');
      await tester.pump();
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    });

    testWidgets('auto number is a valid EAN-13 in the in-store range',
        (tester) async {
      await pumpScreen(tester, const BarcodeCreateScreen());
      final number = find.byWidgetPredicate(
        (widget) =>
            widget is Text && RegExp(r'^2\d{12}$').hasMatch(widget.data ?? ''),
      );
      expect(number, findsOneWidget);
    });

    testWidgets('saving stores the barcode, registers 0 stock and opens print',
        (tester) async {
      await pumpScreen(tester, const BarcodeCreateScreen());
      await tester.enterText(field('Product name'), 'Lucky Me');
      await tester.enterText(field('Unit price (optional)'), '15.50');
      await tester.enterText(field('Size or variant (optional)'), '60 g');
      await tester.pump();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(barcodes.items, hasLength(1));
      final saved = barcodes.items.values.single;
      expect(saved.name, 'Lucky Me');
      expect(saved.details, '60 g');
      expect(saved.priceCentavos, 1550);
      expect(saved.symbology, BarcodeSymbology.ean13);

      final stocked = inventory.items[saved.barcode]!;
      expect(stocked.quantity, 0);
      expect(stocked.name, 'Lucky Me');
      expect(stocked.priceCentavos, 1550);

      expect(find.byType(LabelExportScreen), findsOneWidget);
      expect(find.textContaining('added to inventory'), findsOneWidget);
    });

    testWidgets('inventory can be skipped', (tester) async {
      await pumpScreen(tester, const BarcodeCreateScreen());
      await tester.enterText(field('Product name'), 'Lucky Me');
      await tester.tap(find.byType(Switch));
      await tester.pump();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(barcodes.items, hasLength(1));
      expect(inventory.items, isEmpty);
    });

    testWidgets('a typed number is checked and gets its check digit',
        (tester) async {
      await pumpScreen(tester, const BarcodeCreateScreen());
      await tester.enterText(field('Product name'), 'Lucky Me');
      await tester.tap(find.text('Type my own'));
      await tester.pump();
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

      await tester.enterText(field('Barcode number'), '4006381333930');
      await tester.pump();
      expect(find.textContaining('should be 1'), findsOneWidget);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

      await tester.enterText(field('Barcode number'), '400638133393');
      await tester.pump();
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(barcodes.items.keys.single, '4006381333931');
    });

    testWidgets('a number already used in inventory is refused',
        (tester) async {
      inventory.items['4006381333931'] = InventoryItem(
        barcode: '4006381333931',
        name: 'Existing Item',
        quantity: 2,
        scannedAt: DateTime(2026, 11, 5),
      );
      await pumpScreen(tester, const BarcodeCreateScreen());
      await tester.enterText(field('Product name'), 'Lucky Me');
      await tester.tap(find.text('Type my own'));
      await tester.pump();
      await tester.enterText(field('Barcode number'), '4006381333931');
      await tester.pump();

      expect(find.text('Already used by Existing Item.'), findsOneWidget);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    });

    testWidgets('changing format changes the number', (tester) async {
      await pumpScreen(tester, const BarcodeCreateScreen());
      await tester.tap(find.text('EAN-8'));
      await tester.pump();
      final number = find.byWidgetPredicate(
        (widget) =>
            widget is Text && RegExp(r'^2\d{7}$').hasMatch(widget.data ?? ''),
      );
      expect(number, findsOneWidget);

      await tester.tap(find.text('Code 128'));
      await tester.pump();
      final sku = find.byWidgetPredicate(
        (widget) =>
            widget is Text && RegExp(r'^SKU\d{7}$').hasMatch(widget.data ?? ''),
      );
      expect(sku, findsOneWidget);
    });
  });

  group('Print screen', () {
    Future<void> open(WidgetTester tester) async {
      barcodes.items['2000000000008'] = product();
      await pumpScreen(
        tester,
        const LabelExportScreen(barcode: '2000000000008'),
      );
    }

    testWidgets('summarises labels per page and pages', (tester) async {
      await open(tester);
      // 24 medium labels fill one A4 sheet.
      expect(find.text('24 per page · 1 page'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
      expect(find.text('24 per page · 2 pages'), findsOneWidget);
    });

    testWidgets('copies are limited to 500', (tester) async {
      await open(tester);
      await tester.enterText(field('Number of labels'), '999');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
      expect(find.text('500'), findsOneWidget);
    });

    testWidgets('a label too big for the page blocks the export',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Custom'));
      await tester.pump();
      await tester.enterText(field('Width (mm)'), '150');
      await tester.enterText(field('Height (mm)'), '100');
      await tester.pump();
      // Fits A4 (194 x 281 printable) but not once the gap is counted twice.
      expect(find.textContaining('per page'), findsOneWidget);

      await tester.enterText(field('Width (mm)'), '300');
      await tester.pump();
      expect(find.textContaining('Width 20–150 mm'), findsOneWidget);
      final export = find.widgetWithText(FilledButton, 'Print / Export PDF');
      expect(tester.widget<FilledButton>(export).onPressed, isNull);
    });

    testWidgets('the file type button follows the choice', (tester) async {
      await open(tester);
      expect(find.text('Print / Export PDF'), findsOneWidget);
      await tester.tap(find.text('DOCX'));
      await tester.pump();
      expect(find.text('Print / Export DOCX'), findsOneWidget);
    });

    testWidgets('warns when the bars would be too small to scan',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Custom'));
      await tester.pump();
      await tester.enterText(field('Width (mm)'), '22');
      await tester.enterText(field('Height (mm)'), '14');
      await tester.pump();
      expect(find.textContaining('may not scan reliably'), findsOneWidget);
    });

    testWidgets('offers to add a missing item to inventory', (tester) async {
      await open(tester);
      expect(find.text('Not in inventory yet.'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(inventory.items['2000000000008']!.quantity, 0);
      expect(find.text('Not in inventory yet.'), findsNothing);
    });
  });

  group('Stock-in sheet', () {
    Future<void> openSheet(WidgetTester tester, InventoryItem item) async {
      inventory.items[item.barcode] = item;
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = InventoryCubit(inventory);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showItemSheet(
                  context,
                  cubit: cubit,
                  barcode: item.barcode,
                  scanned: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a registered product with no stock opens ready to add stock',
        (tester) async {
      await openSheet(
        tester,
        InventoryItem(
          barcode: '2000000000008',
          name: 'Rice',
          quantity: 0,
          scannedAt: DateTime(2026, 11, 5, 9),
          priceCentavos: 5000,
        ),
      );
      expect(find.text('Ready for stock-in'), findsOneWidget);
      expect(find.text('Quantity to add'), findsOneWidget);
      expect(find.textContaining('no stock yet'), findsOneWidget);

      await tester.enterText(field('Quantity to add'), '12');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Update to 12'));
      await tester.pumpAndSettle();

      final saved = inventory.items['2000000000008']!;
      expect(saved.quantity, 12);
      expect(saved.name, 'Rice');
      expect(saved.priceCentavos, 5000);
    });

    testWidgets('a product that has stock still behaves as before',
        (tester) async {
      await openSheet(
        tester,
        InventoryItem(
          barcode: '2000000000015',
          name: 'Sugar',
          quantity: 7,
          scannedAt: DateTime(2026, 11, 5, 9),
        ),
      );
      expect(find.text('Already in inventory'), findsOneWidget);
      expect(find.text('Stock quantity'), findsOneWidget);
      expect(find.text('Ready for stock-in'), findsNothing);
      expect(
        tester.widget<TextField>(field('Stock quantity')).controller!.text,
        '7',
      );
    });
  });
}
