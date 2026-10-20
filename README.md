# Stock Scan (qr_msme)

Offline barcode inventory for small shops. Open the app and scan. No login, no network.

## Flow

1. **Scan**: the camera is live on launch. A detected barcode opens a bottom sheet for the product name and stock quantity. Save writes straight to the local database. Scanning a known barcode pre-fills the sheet so it becomes an update.
2. **Inventory**: every item with barcode, quantity and timestamp. Tap to edit, swipe left to delete (with undo), search by name or barcode.
3. **Receipt**: pick items from inventory, set quantity and unit price per line, choose **Acknowledgement Receipt** or **Order Slip** and a 58 mm or 80 mm roll, then tap **Print / Share**. The PDF is built on the device and the native share sheet opens straight away (Viber, email, or a Bluetooth thermal printer app). Building a receipt does not change stock counts.
4. **BIR Export**: one button builds `BIR_Inventory_<yyyyMMdd_HHmm>.xlsx` with the columns `Barcode/SKU`, `Product Description`, `Quantity`, `Date Scanned`, then opens the native share sheet (Viber, email, ...).

## Receipt layout

Top to bottom: the title in bold capitals (`ACKNOWLEDGEMENT RECEIPT` or `ORDER SLIP`), date, time, itemized lines (`qty x unit price`, amount), total, a `Received By` signature line, and last the fixed disclaimer:

> This document is not valid for claim of input tax. For internal tracking purposes only.

The wording lives in `ReceiptType.title` ([lib/data/receipt.dart](lib/data/receipt.dart)) and `ReceiptPdf.disclaimer` ([lib/services/receipt_pdf.dart](lib/services/receipt_pdf.dart)). Fonts are bundled in `assets/fonts` so nothing is fetched at print time.

## Stack

| Concern | Choice |
| --- | --- |
| State | `flutter_bloc` (one `InventoryCubit`) |
| Storage | `hive_ce`, a single box keyed by barcode, in memory with on-disk writes |
| Scanner | `mobile_scanner` with the bundled ML Kit model on Android, so no model download is needed offline |
| Export | `excel` (encoded in a background isolate), `path_provider`, `share_plus` |
| Receipt | `pdf` (pure Dart, built in a background isolate), bundled Roboto, `share_plus` |

## Layout

```
lib/
  core/      theme, Money (centavo helpers)
  data/      InventoryItem, Receipt models, Hive repository
  cubit/     InventoryCubit, ReceiptCubit and their states
  services/  ExportService (xlsx + share), ReceiptPdf, ReceiptService
  screens/   HomeShell, Scanner, Inventory, Receipt, Export
  widgets/   ItemSheet, ItemTile, ItemPicker, Viewfinder
```

## Run

```bash
flutter pub get
flutter run
```

Android needs minSdk 23 or higher (the Flutter default is fine). iOS needs a deployment target supported by `mobile_scanner`; the camera usage string is already in `Info.plist`.

## Git flow

- `main`: stable releases only.
- `dev`: integration. Feature work happens on `nekolaiv/<desc>` branches merged with `--no-ff`.
- Commits are `<tag>: <message>`. Every merged milestone on `dev` is tagged `vMAJOR.MINOR.PATCH`.
