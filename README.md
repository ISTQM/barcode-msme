# Stock Scan (qr_msme)

Offline barcode inventory for small shops. Open the app and scan. No login, no network.

## Flow

1. **Scan**: the camera is live on launch. A detected barcode opens a bottom sheet for the product name and stock quantity. Save writes straight to the local database. Scanning a known barcode pre-fills the sheet so it becomes an update.
2. **Inventory**: every item with barcode, quantity and timestamp. Tap to edit, swipe left to delete (with undo), search by name or barcode.
3. **BIR Export**: one button builds `BIR_Inventory_<yyyyMMdd_HHmm>.xlsx` with the columns `Barcode/SKU`, `Product Description`, `Quantity`, `Date Scanned`, then opens the native share sheet (Viber, email, ...).

## Stack

| Concern | Choice |
| --- | --- |
| State | `flutter_bloc` (one `InventoryCubit`) |
| Storage | `hive_ce`, a single box keyed by barcode, in memory with on-disk writes |
| Scanner | `mobile_scanner` with the bundled ML Kit model on Android, so no model download is needed offline |
| Export | `excel` (encoded in a background isolate), `path_provider`, `share_plus` |

## Layout

```
lib/
  core/      theme
  data/      InventoryItem, Hive repository
  cubit/     InventoryCubit, InventoryState
  services/  ExportService (xlsx + share)
  screens/   HomeShell, ScannerScreen, InventoryScreen, ExportScreen
  widgets/   ItemSheet, ItemTile, Viewfinder
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
