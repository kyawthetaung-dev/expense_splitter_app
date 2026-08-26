import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../currency/currency_formatter.dart';
import '../../models/overall_summary.dart';
import '../../models/participant.dart';
import '../../models/person_balance.dart';
import '../../models/settlement_transaction.dart';

final _dateFormat = DateFormat('MMM d, yyyy · h:mm a');

/// Builds a clean, A4-optimized cross-group expense summary report: summary
/// date, group/expense counts, per-participant paid/share/balance/status,
/// and the automatically-calculated settlement table.
pw.Document buildSummaryPdf({
  required DateTime generatedAt,
  required OverallSummary summary,
  required List<Participant> participants,
  required List<PersonBalance> balances,
  required List<SettlementTransaction> settlements,
}) {
  final doc = pw.Document();
  final nameById = {for (final p in participants) p.id: p.name};
  String nameFor(String id) => nameById[id] ?? 'Unknown';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Expense Summary Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated ${_dateFormat.format(generatedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _stat('Expense Groups', '${summary.groupCount}'),
            _stat('Grand Total', formatCurrency(summary.totalExpenseAmount)),
            _stat('Total Paid', formatCurrency(summary.totalPaid)),
            _stat('Outstanding', formatCurrency(summary.totalOutstanding)),
          ],
        ),
        pw.SizedBox(height: 24),
        _sectionTitle('Participant Summary'),
        pw.SizedBox(height: 6),
        if (balances.isEmpty)
          pw.Text(
            'No participants yet.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Participant', 'Paid', 'Share', 'Balance', 'Status'],
            data: [
              for (final b in balances)
                [
                  nameFor(b.participantId),
                  formatCurrency(b.totalPaid),
                  formatCurrency(b.totalShare),
                  formatCurrency(b.balance),
                  _statusLabel(b.status),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            cellHeight: 24,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
        pw.SizedBox(height: 24),
        _sectionTitle('Settlement Details'),
        pw.SizedBox(height: 6),
        if (settlements.isEmpty)
          pw.Text(
            'Everyone is settled — no payments needed.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Payer', 'Receiver', 'Amount'],
            data: [
              for (final s in settlements)
                [
                  nameFor(s.fromParticipantId),
                  nameFor(s.toParticipantId),
                  formatCurrency(s.amount),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
            },
            cellHeight: 24,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
      ],
    ),
  );

  return doc;
}

String _statusLabel(BalanceStatus status) => switch (status) {
  BalanceStatus.receive => 'Receive',
  BalanceStatus.pay => 'Pay',
  BalanceStatus.settled => 'Settled',
};

pw.Widget _sectionTitle(String text) => pw.Text(
  text,
  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
);

pw.Widget _stat(String label, String value) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    pw.SizedBox(height: 2),
    pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
  ],
);
