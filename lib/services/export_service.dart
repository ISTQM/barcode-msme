import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../data/inventory_item.dart';

/// Builds the BIR inventory workbook entirely on the device.
class ExportService {
  static const String sheetName = 'BIR Inventory';

  static const List<String> headers = [
    'Barcode/SKU',
    'Product Description',
    'Quantity',
    'Date Scanned',
  ];

  static const List<double> _columnWidths = [24, 44, 12, 20];

  static final DateFormat _cellDate = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _fileStamp = DateFormat('yyyyMMdd_HHmm');

  /// Writes the workbook to the temp folder and returns the file.
  Future<File> createFile(List<InventoryItem> items) async {
    final bytes = buildWorkbook(items);
    final directory = await getTemporaryDirectory();
    final name = 'BIR_Inventory_${_fileStamp.format(DateTime.now())}.xlsx';
    return File('${directory.path}${Platform.pathSeparator}$name')
        .writeAsBytes(bytes, flush: true);
  }

  static List<int> buildWorkbook(List<InventoryItem> items) {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, sheetName);
    final sheet = excel[sheetName];

    sheet.appendRow([for (final header in headers) TextCellValue(header)]);

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('FF0E7C66'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    for (var column = 0; column < headers.length; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
          .cellStyle = headerStyle;
      sheet.setColumnWidth(column, _columnWidths[column]);
    }

    final sorted = [...items]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    for (final item in sorted) {
      sheet.appendRow([
        // Text, so leading zeros in a barcode survive.
        TextCellValue(item.barcode),
        TextCellValue(item.name),
        IntCellValue(item.quantity),
        TextCellValue(_cellDate.format(item.scannedAt)),
      ]);
    }

    return excel.encode()!;
  }
}
