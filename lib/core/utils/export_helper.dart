import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class ExportHelper {
  /// Exports a list of transactions to a CSV file and opens the native share sheet.
  static Future<void> exportTransactionsCsv(List<dynamic> transactions) async {
    final rows = <List<dynamic>>[
      ['Date', 'Type', 'Quantity', 'Price', 'Total'],
    ];

    for (final t in transactions) {
      final qty = (t['quantity'] as num?)?.toDouble() ?? 0;
      final price = (t['price'] as num?)?.toDouble() ?? 0;
      rows.add([
        t['created_at']?.toString().split('T').first ?? '',
        t['buy_sell'] ?? '',
        qty,
        price,
        (qty * price).toStringAsFixed(2),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/transactions.csv');
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(file.path)], text: 'My transaction history');
  }

  /// Exports a buy/sell transaction statement as a full contract-note-style PDF.
  static Future<void> exportTransactionsPdf(List<dynamic> transactions, {String? userName, String? userEmail}) async {
    final doc = pw.Document();

    const brokeragePct = 0.0005;
    const exchangeChargePct = 0.0000345;
    const clearingChargePct = 0.0;
    const cgstPct = 0.09;
    const sgstPct = 0.09;
    const sttPct = 0.001;
    const sebiTurnoverPct = 0.000001;
    const stampDutyPct = 0.00015;

    double totalGross = 0;
    double totalBrokerage = 0;
    double totalExchangeCharge = 0;
    double totalClearing = 0;
    double totalCgst = 0;
    double totalSgst = 0;
    double totalStt = 0;
    double totalSebiFee = 0;
    double totalStampDuty = 0;
    double totalNet = 0;

    final rows = <List<String>>[];
    final contractNo = 'CNT-${DateTime.now().year}/${DateTime.now().millisecondsSinceEpoch % 100000000}';
    final tradeDate = DateTime.now().toString().split(' ').first;

    for (var i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      final qty = (t['quantity'] as num?)?.toDouble() ?? 0;
      final price = (t['price'] as num?)?.toDouble() ?? 0;
      final isBuy = (t['buy_sell']?.toString().toUpperCase() ?? '') == 'BUY';
      final grossValue = qty * price;

      final brokerage = grossValue * brokeragePct;
      final exchangeCharge = grossValue * exchangeChargePct;
      final clearing = grossValue * clearingChargePct;
      final cgst = (brokerage + exchangeCharge) * cgstPct;
      final sgst = (brokerage + exchangeCharge) * sgstPct;
      final stt = isBuy ? 0.0 : grossValue * sttPct;
      final sebiFee = grossValue * sebiTurnoverPct;
      final stampDuty = isBuy ? grossValue * stampDutyPct : 0.0;
      final charges = brokerage + exchangeCharge + clearing + cgst + sgst + stt + sebiFee + stampDuty;
      final netTotal = isBuy ? grossValue + charges : grossValue - charges;

      totalGross += grossValue;
      totalBrokerage += brokerage;
      totalExchangeCharge += exchangeCharge;
      totalClearing += clearing;
      totalCgst += cgst;
      totalSgst += sgst;
      totalStt += stt;
      totalSebiFee += sebiFee;
      totalStampDuty += stampDuty;
      totalNet += isBuy ? -netTotal : netTotal;

      rows.add([
        (i + 1).toString(),
        t['created_at']?.toString().split('T').first ?? '',
        t['symbol']?.toString() ?? '-',
        isBuy ? 'B' : 'S',
        qty.toStringAsFixed(0),
        price.toStringAsFixed(2),
        grossValue.toStringAsFixed(2),
        brokerage.toStringAsFixed(2),
        netTotal.toStringAsFixed(2),
      ]);
    }

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 6),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('CONTRACT NOTE CUM TAX INVOICE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('ORIGINAL FOR RECIPIENT', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('STOCKPRO', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 2),
                pw.Text('JAYASHRI CAPITAL PRIVATE LIMITED', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('B.N A3, Siddheshwari Nagari, C.T Road, Rajgurunagar, Khed City, Pune-410505, Maharashtra', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Website: www.stockpro.app', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'NAME OF COMPLIANCE OFFICER: JAYASHRI NITIN MANE   EMAIL ID: jayashrimane17@icloud.com',
            style: const pw.TextStyle(fontSize: 7.5),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 6),

          // Contract info table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {0: const pw.FlexColumnWidth(1.3), 1: const pw.FlexColumnWidth(1)},
            children: [
              pw.TableRow(children: [_cell('CONTRACT NOTE NO.', bold: true), _cell(contractNo)]),
              pw.TableRow(children: [_cell('TRADE DATE', bold: true), _cell(tradeDate)]),
              pw.TableRow(children: [_cell('NAME OF CLIENT', bold: true), _cell(userName ?? '-')]),
              pw.TableRow(children: [_cell('CLIENT EMAIL', bold: true), _cell(userEmail ?? '-')]),
            ],
          ),
          pw.SizedBox(height: 10),

          pw.Text(
            'I/We have this day done by your order and on your account the following transactions:',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 6),

          // Transaction table
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 7.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.5),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.3),
              3: pw.FlexColumnWidth(0.6),
              4: pw.FlexColumnWidth(0.8),
              5: pw.FlexColumnWidth(1),
              6: pw.FlexColumnWidth(1.1),
              7: pw.FlexColumnWidth(1),
              8: pw.FlexColumnWidth(1.1),
            },
            data: <List<String>>[
              ['No.', 'Date', 'Security', 'B/S', 'Qty', 'Rate', 'Gross Value', 'Brokerage', 'Net Total'],
              ...rows,
            ],
          ),
          pw.SizedBox(height: 10),

          // Charges summary - Zerodha style line items
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [_cell('PARTICULARS', bold: true), _cell('AMOUNT (Rs)', bold: true)],
              ),
              pw.TableRow(children: [_cell('Gross Transaction Value'), _cell(totalGross.toStringAsFixed(2))]),
              pw.TableRow(children: [_cell('Brokerage'), _cell('(${totalBrokerage.toStringAsFixed(2)})')]),
              pw.TableRow(children: [_cell('Exchange Transaction Charges'), _cell('(${totalExchangeCharge.toStringAsFixed(2)})')]),
              pw.TableRow(children: [_cell('Clearing Charges'), _cell('(${totalClearing.toStringAsFixed(2)})')]),
              pw.TableRow(children: [_cell('CGST (@9% of Brokerage & Charges)'), _cell('(${totalCgst.toStringAsFixed(2)})')]),
              pw.TableRow(children: [_cell('SGST (@9% of Brokerage & Charges)'), _cell('(${totalSgst.toStringAsFixed(2)})')]),
              pw.TableRow(children: [_cell('Securities Transaction Tax (STT)'), _cell('(${totalStt.toStringAsFixed(2)})')]),
              pw.TableRow(children: [_cell('SEBI Turnover Fees'), _cell('(${totalSebiFee.toStringAsFixed(2)})')]),
              pw.TableRow(children: [_cell('Stamp Duty'), _cell('(${totalStampDuty.toStringAsFixed(2)})')]),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Net Amount Receivable / (Payable)', bold: true),
                  _cell(totalNet.toStringAsFixed(2), bold: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          pw.Text(
            'Note: Brokerage and statutory charges shown above are illustrative estimates for a simulated trading account and do not reflect real brokerage rates.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 12),

          // Signatory block
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date: $tradeDate', style: const pw.TextStyle(fontSize: 8)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Yours faithfully,', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 4),
                  pw.Text('For JAYASHRI CAPITAL PRIVATE LIMITED', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('(Authorised Signatory)', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(1.2)},
            children: [
              pw.TableRow(children: [_cell('PAN of Company'), _cell('AAHCJ3135F')]),
              pw.TableRow(children: [_cell('GSTIN of Company'), _cell('27AAHCJ3135F1ZQ')]),
              pw.TableRow(children: [_cell('CIN'), _cell('U64990PN2026PTC253077')]),
              pw.TableRow(children: [_cell('Description of Service'), _cell('Brokerage and related securities services')]),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),

          pw.Text(
            'Transactions mentioned in this contract note cum bill shall be governed and subject to the Rules, Bye-laws, '
                'Regulations and Circulars of the respective Exchanges on which trades have been executed and Securities and '
                'Exchange Board of India issued from time to time. It shall also be subject to the relevant Acts, Rules, '
                'Regulations, Directives, Notifications, Guidelines (including GST Laws) & Circulars issued by SEBI / '
                'Government of India / State Governments and Union Territory Governments issued from time to time. The '
                'Exchanges provide Complaint Resolution, Arbitration and Appellate arbitration facilities at the Regional '
                'Arbitration Centres (RAC). The client may approach its nearest Centre, details of which are available on '
                'respective Exchange\'s website.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Proprietary trading disclosure: This platform is a simulated/virtual trading environment. No real money, '
                'securities, or brokerage services are involved. All trades are executed against simulated market data for '
                'educational and demonstration purposes only.',
            style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Note: The shares of the listed stock exchange/depository shall only be dealt by fit and proper persons as per '
                'applicable SEBI Regulations. The same is not considered in the taxable value of supply for charging GST. '
                'Tax is payable on reverse charge basis: No. This is a simulated trading statement for educational purposes '
                'only, generated by StockPro. Not a real brokerage document.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date: $tradeDate', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Place: PUNE', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/share_statement.pdf');
    await file.writeAsBytes(await doc.save());

    await Share.shareXFiles([XFile(file.path)], text: 'My purchase/sale of shares statement');
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  /// Exports a tax P&L report to a PDF file and opens the native share sheet.
  static Future<void> exportTaxReportPdf(Map<String, dynamic> report) async {
    final doc = pw.Document();
    final gains = (report['gains'] as List<dynamic>?) ?? [];
    final totalStcg = (report['total_stcg'] as num?)?.toDouble() ?? 0;
    final totalLtcg = (report['total_ltcg'] as num?)?.toDouble() ?? 0;
    final estStcgTax = (report['estimated_stcg_tax'] as num?)?.toDouble() ?? 0;
    final estLtcgTax = (report['estimated_ltcg_tax'] as num?)?.toDouble() ?? 0;
    final totalTax = (report['total_estimated_tax'] as num?)?.toDouble() ?? 0;

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 6),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Tax P&L Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 6),
          pw.Text('Generated: ${DateTime.now().toString().split('.').first}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Short-Term Capital Gains (STCG): Rs ${totalStcg.toStringAsFixed(2)}'),
                pw.Text('Estimated STCG Tax (20%): Rs ${estStcgTax.toStringAsFixed(2)}'),
                pw.SizedBox(height: 4),
                pw.Text('Long-Term Capital Gains (LTCG): Rs ${totalLtcg.toStringAsFixed(2)}'),
                pw.Text('Estimated LTCG Tax (12.5%): Rs ${estLtcgTax.toStringAsFixed(2)}'),
                pw.SizedBox(height: 6),
                pw.Text('Total Estimated Tax: Rs ${totalTax.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text('Transaction Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            data: <List<String>>[
              ['Symbol', 'Qty', 'Buy Price', 'Sell Price', 'Type', 'Gain'],
              ...gains.map((g) => [
                g['symbol']?.toString() ?? '',
                g['quantity']?.toString() ?? '',
                g['buy_price']?.toString() ?? '',
                g['sell_price']?.toString() ?? '',
                g['type']?.toString() ?? '',
                g['gain']?.toString() ?? '',
              ]),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'This is an estimate for informational purposes only, based on FIFO matching. Please consult a tax professional for filing.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/tax_report.pdf');
    await file.writeAsBytes(await doc.save());

    await Share.shareXFiles([XFile(file.path)], text: 'My tax P&L report');
  }
}