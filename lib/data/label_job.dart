import '../core/label_geometry.dart';
import '../core/sheet_layout.dart';

/// File type for a run of labels.
enum SheetFormat {
  pdf('PDF', 'pdf', 'application/pdf'),
  docx(
    'DOCX',
    'docx',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  );

  const SheetFormat(this.label, this.extension, this.mime);

  final String label;
  final String extension;
  final String mime;
}

/// Everything needed to lay out a sheet of labels. Plain data, so it can be
/// handed to a background isolate.
class LabelJob {
  const LabelJob({
    required this.content,
    required this.style,
    required this.size,
    required this.paper,
    required this.copies,
    required this.cutGuides,
  });

  static const int maxCopies = 500;

  final LabelContent content;
  final LabelStyle style;
  final LabelSize size;
  final PaperSize paper;
  final int copies;
  final bool cutGuides;

  LabelGeometry get geometry => LabelGeometry.build(
        content,
        style,
        widthMm: size.widthMm,
        heightMm: size.heightMm,
      );

  SheetLayout get layout =>
      SheetLayout.compute(paper: paper, label: size, copies: copies);
}
