# Barcode MSME (barcode_msme)

Offline barcode inventory for small shops. Open the app and scan. No login, no network.

## Flow

1. **Scan**: the camera is live on launch, with a **Stock / Receipt** switch at the top.
   - **Stock**: a detected barcode opens a bottom sheet for the product name, stock quantity and optional unit price. Save writes straight to the local database.
   - **Receipt**: a detected barcode that is in inventory is added to the receipt with no sheet, and the camera keeps scanning. A panel shows the last item with its running `×N`, a one-tap remove-one, the total, and a **Review** button.
2. **Inventory**: every item with barcode, quantity and timestamp. Tap to edit, swipe left to delete (with undo), search by name or barcode.
3. **Receipt**: review what was scanned (or add items by hand), set quantity and unit price per line, choose **Acknowledgement Receipt** or **Order Slip** and a 58 mm or 80 mm roll, then tap **Print / Share**. The PDF is built on the device and the native share sheet opens straight away (Viber, email, or a Bluetooth thermal printer app). Building a receipt does not change stock counts.
4. **Barcodes**: make a barcode for a product that has none, then print the labels.
   - **Photo and info**: take or pick a product photo, then fill in the name, optional unit price and optional size or variant.
   - **Format**: EAN-13 (the standard on Philippine retail packs), EAN-8 (small packs) or Code 128 (your own SKU codes).
   - **Number**: auto-generated, or typed. EAN numbers need only the first 12 (or 7) digits, the check digit is added. Auto numbers start with `2`, the range GS1 reserves for a shop's own products, so they never clash with a manufacturer's prefix such as `480` for the Philippines. A number already used in inventory or among your barcodes is refused.
   - **Label style**: Barcode, With name, or Name & price.
   - **Inventory**: switched on by default, it adds the product with 0 in stock. When you later scan it during stock-in, the sheet opens as *Ready for stock-in* with the name and price filled in.
   - **Print**: choose label size (small 38 × 25 mm, medium 50 × 30, large 70 × 40, or custom), paper (A4, short bond 8.5 × 11 in, long bond 8.5 × 13 in), copies (up to 500) and cut guides, then export a **PDF** or **DOCX** through the share sheet. The sheet shows how many labels fit per page. A warning appears when the bars are too small to scan reliably.
   - **Image**: export the barcode alone as a PNG (1200 px wide) to redesign elsewhere.
5. **BIR Export**: one button builds `BIR_Inventory_<yyyyMMdd_HHmm>.xlsx` with the columns `Barcode/SKU`, `Product Description`, `Quantity`, `Date Scanned`, then opens the native share sheet (Viber, email, ...).

## Duplicate scans

- **Held in view**: a barcode that stays in front of the camera counts once. It counts again only after it has been out of view for 0.7 s (`ScanGate`), which is what moving to the next unit of the same product looks like.
- **Stock mode, barcode already stored**: the sheet is titled *Already in inventory*, shows the current stock and last scan time, and offers **Replace count** (type the new total) or **Add to count** (type how many to add; the button reads `Update to N`).
- **Receipt mode, same product again**: quantity goes up by one and the panel shows the new `×N`. **Remove one** undoes a mistaken scan.
- **Receipt mode, barcode not in inventory**: nothing is added. The panel warns and offers **Add item**, which opens the sheet and then puts the item on the receipt.

## Beep and vibrate

Every counted scan beeps and vibrates, with three distinct cues so you can tell the result without looking:

| Cue | Sound | Vibration |
| --- | --- | --- |
| Scanned (new barcode, or an item added to the receipt) | one short beep | one short pulse |
| Already stored (stock mode) | rising two-note chirp | double pulse |
| Not in inventory (receipt mode) | low double buzz | long double pulse |

Tones are bundled WAV files in `assets/sounds`, played without taking audio focus so music keeps playing. Audio and vibration failures are swallowed and never block scanning.

## Receipt layout

Top to bottom: the title in bold capitals (`ACKNOWLEDGEMENT RECEIPT` or `ORDER SLIP`), date, time, itemized lines (`qty x unit price`, amount), total, a `Received By` signature line, and last the fixed disclaimer:

> This document is not valid for claim of input tax. For internal tracking purposes only.

The wording lives in `ReceiptType.title` ([lib/data/receipt.dart](lib/data/receipt.dart)) and `ReceiptPdf.disclaimer` ([lib/services/receipt_pdf.dart](lib/services/receipt_pdf.dart)). Fonts are bundled in `assets/fonts` so nothing is fetched at print time.

## Stack

| Concern | Choice |
| --- | --- |
| State | `flutter_bloc` (`InventoryCubit`, `ReceiptCubit`, `BarcodeCubit`) |
| Storage | `hive_ce`, one box keyed by barcode for inventory and one for the barcodes made in the app, in memory with on-disk writes. Product photos are files in the app folder |
| Scanner | `mobile_scanner` with the bundled ML Kit model on Android, so no model download is needed offline |
| Export | `excel` (encoded in a background isolate), `path_provider`, `share_plus` |
| Receipt | `pdf` (pure Dart, built in a background isolate), bundled Roboto, `share_plus` |
| Barcode labels | `barcode` (symbol geometry), drawn as vectors in the `pdf` output and with `dart:ui` for the preview and PNG, `archive` (the DOCX is written by hand as a zip of XML), `image_picker` for photos |
| Feedback | `audioplayers` (low latency, bundled tones), `vibration` |

## Layout

```
lib/
  core/      theme, Money (centavo helpers), ScanGate, barcode numbers and
             label geometry (pure Dart), sheet layout, LabelPainter
  data/      InventoryItem, Receipt, ProductBarcode models, Hive repositories
  cubit/     InventoryCubit, ReceiptCubit, BarcodeCubit and their states
  services/  ExportService (xlsx + share), ReceiptPdf, ReceiptService, ScanFeedback,
             LabelPdf, LabelDocx, LabelExportService, PhotoService
  screens/   HomeShell, Counter, Inventory, Barcodes, Receipt, Export
  widgets/   ItemSheet, ItemTile, ItemPicker, ReceiptScanPanel, Viewfinder,
             BarcodeTile, label preview and form parts
```

## Run

```bash
flutter pub get
flutter run
flutter test
```

Android needs minSdk 23 or higher (the Flutter default is fine). iOS needs a deployment target supported by `mobile_scanner`; the camera usage string is already in `Info.plist`.

## Git flow

- `main`: stable releases only.
- `dev`: integration. Feature work happens on `nekolaiv/<desc>` branches merged with `--no-ff`.
- Commits are `<tag>: <message>`. Every merged milestone on `dev` is tagged `vMAJOR.MINOR.PATCH`.
