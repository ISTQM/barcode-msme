import 'package:flutter/material.dart';

/// Corner rounding options for white-labeling.
enum BrandCornerStyle {
  /// Sharp architectural edges (4px)
  sharp(4.0, 6.0, 8.0),

  /// Modern Mobbin squircle edges (12px)
  squareRound(10.0, 14.0, 18.0),

  /// Soft rounded pill/bubble edges (24px)
  round(16.0, 22.0, 28.0);

  const BrandCornerStyle(this.small, this.medium, this.large);

  final double small;
  final double medium;
  final double large;

  BorderRadius get smallRadius => BorderRadius.circular(small);
  BorderRadius get mediumRadius => BorderRadius.circular(medium);
  BorderRadius get largeRadius => BorderRadius.circular(large);
  BorderRadius get sheetRadius =>
      BorderRadius.vertical(top: Radius.circular(large));
}

/// Central white-label configuration model.
///
/// Every brand asset, text, color, corner style, and URL is centralized here
/// so any tenant or white-label customer can be styled by swapping this object.
class BrandConfig {
  const BrandConfig({
    required this.appName,
    required this.tagline,
    required this.organization,
    required this.footerNote,
    required this.currencySymbol,
    required this.currencyCode,
    required this.websiteUrl,
    required this.supportUrl,
    required this.receiptDisclaimer,
    required this.cornerStyle,
    required this.palette,
    this.defaultPushToScan = true,
  });

  final String appName;
  final String tagline;
  final String organization;
  final String footerNote;
  final String currencySymbol;
  final String currencyCode;
  final String websiteUrl;
  final String supportUrl;
  final String receiptDisclaimer;
  final BrandCornerStyle cornerStyle;
  final BrandPalette palette;

  /// Default push-to-scan safety feature setting (prevents accidental scans).
  final bool defaultPushToScan;

  /// Default Mobbin-inspired monochrome black & white theme.
  static const BrandConfig mobbinMonochrome = BrandConfig(
    appName: 'Barcode MSME',
    tagline: 'Point of Sale & Stock Scan',
    organization: 'ISTQM FRAMEWORK',
    footerNote: 'OFFLINE FIRST · BIR COMPLIANT',
    currencySymbol: '₱',
    currencyCode: 'PHP',
    websiteUrl: 'https://istqm.com',
    supportUrl: 'https://github.com/ISTQM/barcode-msme',
    receiptDisclaimer:
        'This document is not valid for claim of input tax. '
        'For internal tracking purposes only.',
    cornerStyle: BrandCornerStyle.squareRound,
    palette: BrandPalette.monochrome,
  );

  BrandConfig copyWith({
    String? appName,
    String? tagline,
    String? organization,
    String? footerNote,
    String? currencySymbol,
    String? currencyCode,
    String? websiteUrl,
    String? supportUrl,
    String? receiptDisclaimer,
    BrandCornerStyle? cornerStyle,
    BrandPalette? palette,
    bool? defaultPushToScan,
  }) {
    return BrandConfig(
      appName: appName ?? this.appName,
      tagline: tagline ?? this.tagline,
      organization: organization ?? this.organization,
      footerNote: footerNote ?? this.footerNote,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      supportUrl: supportUrl ?? this.supportUrl,
      receiptDisclaimer: receiptDisclaimer ?? this.receiptDisclaimer,
      cornerStyle: cornerStyle ?? this.cornerStyle,
      palette: palette ?? this.palette,
      defaultPushToScan: defaultPushToScan ?? this.defaultPushToScan,
    );
  }
}

/// Color system for the white-label theme.
class BrandPalette {
  const BrandPalette({
    required this.primary,
    required this.onPrimary,
    required this.backgroundDark,
    required this.backgroundLight,
    required this.surfaceDark,
    required this.surfaceLight,
    required this.cardDark,
    required this.cardLight,
    required this.borderDark,
    required this.borderLight,
    required this.textPrimaryDark,
    required this.textPrimaryLight,
    required this.textSecondaryDark,
    required this.textSecondaryLight,
    required this.accent,
    required this.splashBackgroundDark,
    required this.splashBackgroundLight,
  });

  final Color primary;
  final Color onPrimary;
  final Color backgroundDark;
  final Color backgroundLight;
  final Color surfaceDark;
  final Color surfaceLight;
  final Color cardDark;
  final Color cardLight;
  final Color borderDark;
  final Color borderLight;
  final Color textPrimaryDark;
  final Color textPrimaryLight;
  final Color textSecondaryDark;
  final Color textSecondaryLight;
  final Color accent;
  final Color splashBackgroundDark;
  final Color splashBackgroundLight;

  /// Pure Mobbin Monochrome (High contrast, Pitch Black, Crisp White, Refined Zinc)
  static const BrandPalette monochrome = BrandPalette(
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
    backgroundDark: Color(0xFF000000),
    backgroundLight: Color(0xFFF9FAFB),
    surfaceDark: Color(0xFF0D0D0E),
    surfaceLight: Color(0xFFFFFFFF),
    cardDark: Color(0xFF161618),
    cardLight: Color(0xFFFFFFFF),
    borderDark: Color(0xFF27272A),
    borderLight: Color(0xFFE4E4E7),
    textPrimaryDark: Color(0xFFFAFAFA),
    textPrimaryLight: Color(0xFF09090B),
    textSecondaryDark: Color(0xFFA1A1AA),
    textSecondaryLight: Color(0xFF71717A),
    accent: Color(0xFF3B82F6), // Minimal electric blue or pure white accent
    splashBackgroundDark: Color(0xFF000000),
    splashBackgroundLight: Color(0xFF09090B),
  );
}

/// InheritedWidget to make BrandConfig accessible everywhere in the tree.
class BrandScope extends InheritedWidget {
  const BrandScope({
    super.key,
    required this.config,
    required super.child,
  });

  final BrandConfig config;

  static BrandConfig of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BrandScope>();
    return scope?.config ?? BrandConfig.mobbinMonochrome;
  }

  @override
  bool updateShouldNotify(BrandScope oldWidget) => config != oldWidget.config;
}
