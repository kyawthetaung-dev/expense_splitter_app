import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../currency/currency_formatter.dart';
import '../../models/expense.dart';
import '../../models/expense_payer.dart';
import '../../models/expense_share.dart';
import '../../models/group.dart';
import '../../models/split_type.dart';

final _dateFormat = DateFormat('MMM d, yyyy · h:mm a');

/// Builds a clean, A4-optimized single-expense report — group info, expense
/// info, the paid-by breakdown, the participant-shares breakdown, and the
/// total — for [Printing.layoutPdf] to hand to the platform's print/PDF UI.
pw.Document buildExpensePdf({
  required Group group,
  required Expense expense,
  required List<ExpensePayer> payers,
  required List<ExpenseShare> shares,
  required Map<String, String> participantNameById,
}) {
  final doc = pw.Document();
  String nameFor(String participantId) =>
      participantNameById[participantId] ?? 'Unknown';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Expense Invoice',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(group.name, style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),
        ],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          expense.title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${_dateFormat.format(expense.createdAt)}  ·  Split: '
          '${_splitLabel(expense.splitType)}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Total Amount',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.Text(
          formatCurrency(expense.totalAmount),
          style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 24),
        _sectionTitle('Paid By'),
        pw.SizedBox(height: 6),
        _twoColumnTable(
          headers: const ['Participant', 'Amount'],
          rows: [
            for (final p in payers)
              [nameFor(p.participantId), formatCurrency(p.paidAmount)],
          ],
          emptyLabel: 'No payers recorded',
        ),
        pw.SizedBox(height: 20),
        _sectionTitle('Participant Shares'),
        pw.SizedBox(height: 6),
        _twoColumnTable(
          headers: const ['Participant', 'Share'],
          rows: [
            for (final s in shares)
              [nameFor(s.participantId), formatCurrency(s.shareAmount)],
          ],
          emptyLabel: 'No participants recorded',
        ),
      ],
    ),
  );

  return doc;
}

String _splitLabel(SplitType type) => switch (type) {
  SplitType.equal => 'Equal',
  SplitType.custom => 'Custom amounts',
  SplitType.percentage => 'Percentage',
};

pw.Widget _sectionTitle(String text) => pw.Text(
  text,
  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
);

pw.Widget _twoColumnTable({
  required List<String> headers,
  required List<List<String>> rows,
  required String emptyLabel,
}) {
  if (rows.isEmpty) {
    return pw.Text(
      emptyLabel,
      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
    );
  }
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
    cellStyle: const pw.TextStyle(fontSize: 10),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
    cellHeight: 24,
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
  );
}
