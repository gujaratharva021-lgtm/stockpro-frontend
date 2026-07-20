import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  static const _baseUrl = 'https://adjimrxt3y.ap-south-1.awsapprunner.com/api/v1';
  String? _generating;

  static final _brand = PdfColor.fromInt(0xFFF5A623);

  Future<Dio> _authedDio() async {
    final dio = Dio();
    final token = await ApiService.getToken();
    dio.options.headers['Authorization'] = 'Bearer $token';
    return dio;
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return '-';
    }
  }

  String _formatDateTime(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${months[d.month - 1]} ${d.year} ${hh}:${mm}';
    } catch (_) {
      return '-';
    }
  }

  Future<void> _saveAndShare(pw.Document doc, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await doc.save());
    await Share.shareXFiles([XFile(file.path)], text: filename);
  }

  // ---------- Shared page chrome: letterhead + footer ----------

  pw.Widget _buildHeader(String reportTitle, String reportSubtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1.2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 30, height: 30,
                    decoration: pw.BoxDecoration(color: _brand, borderRadius: pw.BorderRadius.circular(6)),
                    alignment: pw.Alignment.center,
                    child: pw.Text('S', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text('OneInvest', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Text('www.OneInvest.app', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(reportTitle, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text(reportSubtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  pw.Widget _buildAccountInfoBlock(Map<String, dynamic>? user) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16, bottom: 16),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ACCOUNT HOLDER', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text(user?['name'] ?? '-', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(user?['email'] ?? '-', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ACCOUNT ID', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text((user?['id']?.toString() ?? '-').length >= 8 ? user!['id'].toString().substring(0, 8).toUpperCase() : '-', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('STATEMENT DATE', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text(_formatDate(DateTime.now().toIso8601String()), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('This is a system-generated statement from OneInvest.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  pw.Widget _summaryTile(String label, String value, {PdfColor? valueColor}) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: valueColor ?? PdfColors.black)),
          ],
        ),
      ),
    );
  }

  pw.TableRow _tableHeaderRow(List<String> headers) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfColors.grey800),
      children: headers
          .map((h) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      ))
          .toList(),
    );
  }

  pw.TableRow _tableDataRow(List<String> cells, bool alt, {int? colorCol, bool? isPositive}) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: alt ? PdfColors.grey100 : PdfColors.white),
      children: List.generate(cells.length, (i) {
        pw.TextStyle style = const pw.TextStyle(fontSize: 9);
        if (colorCol != null && i == colorCol && isPositive != null) {
          style = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: isPositive ? PdfColors.green700 : PdfColors.red700);
        }
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: pw.Text(cells[i], style: style),
        );
      }),
    );
  }

  // ---------- Holdings Statement ----------

  Future<void> _downloadHoldings() async {
    setState(() => _generating = 'holdings');
    try {
      final dio = await _authedDio();
      final userRes = await ApiService.getMe();
      final res = await dio.get('$_baseUrl/portfolio/holdings');
      final holdings = res.data['holdings'] as List<dynamic>? ?? [];

      double totalInvested = 0;
      for (final h in holdings) {
        final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
        final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
        totalInvested += qty * avg;
      }

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 30),
          header: (ctx) => ctx.pageNumber == 1
              ? _buildHeader('Holdings Statement', 'Summary of all your current stock holdings')
              : pw.SizedBox(),
          footer: _footer,
          build: (ctx) => [
            _buildAccountInfoBlock(userRes['user']),
            pw.Row(
              children: [
                _summaryTile('TOTAL HOLDINGS', '${holdings.length}'),
                _summaryTile('TOTAL INVESTED', '\u20b9${totalInvested.toStringAsFixed(2)}'),
              ],
            ),
            pw.SizedBox(height: 22),
            pw.Text('Holding Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(2.2),
                1: pw.FlexColumnWidth(1.4),
                2: pw.FlexColumnWidth(1.8),
                3: pw.FlexColumnWidth(2),
              },
              border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              children: [
                _tableHeaderRow(['Symbol', 'Quantity', 'Avg Price (\u20b9)', 'Invested Value (\u20b9)']),
                ...List.generate(holdings.length, (i) {
                  final h = holdings[i];
                  final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
                  final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
                  return _tableDataRow([
                    h['symbol']?.toString() ?? '-',
                    qty.toStringAsFixed(0),
                    avg.toStringAsFixed(2),
                    (qty * avg).toStringAsFixed(2),
                  ], i.isOdd);
                }),
              ],
            ),
            if (holdings.isEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('No holdings found', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
            ],
            pw.SizedBox(height: 30),
            pw.Text(
              'Note: This statement reflects average buy price and quantity currently held. Market value and unrealized P&L are not included as they fluctuate with live prices.',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
            ),
          ],
        ),
      );
      await _saveAndShare(doc, 'OneInvest_Holdings_Statement.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not generate holdings statement')));
      }
    } finally {
      if (mounted) setState(() => _generating = null);
    }
  }

  // ---------- Trade Statement ----------

  Future<void> _downloadTradebook() async {
    setState(() => _generating = 'tradebook');
    try {
      final dio = await _authedDio();
      final userRes = await ApiService.getMe();
      final res = await dio.get('$_baseUrl/portfolio/transactions');
      final txns = res.data['transactions'] as List<dynamic>? ?? [];

      int buyCount = 0, sellCount = 0;
      double buyValue = 0, sellValue = 0;
      for (final t in txns) {
        final qty = (t['quantity'] as num?)?.toDouble() ?? 0;
        final price = (t['price'] as num?)?.toDouble() ?? 0;
        if (t['buy_sell'] == 'BUY') {
          buyCount++;
          buyValue += qty * price;
        } else {
          sellCount++;
          sellValue += qty * price;
        }
      }

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 30),
          header: (ctx) => ctx.pageNumber == 1
              ? _buildHeader('Trade Statement', 'Complete record of all buy and sell transactions')
              : pw.SizedBox(),
          footer: _footer,
          build: (ctx) => [
            _buildAccountInfoBlock(userRes['user']),
            pw.Row(
              children: [
                _summaryTile('BUY ORDERS', '$buyCount', valueColor: PdfColors.green700),
                _summaryTile('SELL ORDERS', '$sellCount', valueColor: PdfColors.red700),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                _summaryTile('TOTAL BUY VALUE', '\u20b9${buyValue.toStringAsFixed(2)}'),
                _summaryTile('TOTAL SELL VALUE', '\u20b9${sellValue.toStringAsFixed(2)}'),
              ],
            ),
            pw.SizedBox(height: 22),
            pw.Text('Transaction Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(1.6),
                2: pw.FlexColumnWidth(1.1),
                3: pw.FlexColumnWidth(1.1),
                4: pw.FlexColumnWidth(1.4),
                5: pw.FlexColumnWidth(1.6),
              },
              border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              children: [
                _tableHeaderRow(['Date & Time', 'Symbol', 'Type', 'Qty', 'Price (\u20b9)', 'Total (\u20b9)']),
                ...List.generate(txns.length, (i) {
                  final t = txns[i];
                  final qty = (t['quantity'] as num?)?.toDouble() ?? 0;
                  final price = (t['price'] as num?)?.toDouble() ?? 0;
                  final isBuy = t['buy_sell'] == 'BUY';
                  return _tableDataRow([
                    _formatDateTime(t['created_at']),
                    t['symbol']?.toString() ?? '-',
                    t['buy_sell']?.toString() ?? '-',
                    qty.toStringAsFixed(0),
                    price.toStringAsFixed(2),
                    (qty * price).toStringAsFixed(2),
                  ], i.isOdd, colorCol: 2, isPositive: isBuy);
                }),
              ],
            ),
            if (txns.isEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('No transactions found', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
            ],
          ],
        ),
      );
      await _saveAndShare(doc, 'OneInvest_Trade_Statement.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not generate trade statement')));
      }
    } finally {
      if (mounted) setState(() => _generating = null);
    }
  }

  // ---------- Tax P&L Report ----------

  Future<void> _downloadTaxReport() async {
    setState(() => _generating = 'tax');
    try {
      final dio = await _authedDio();
      final userRes = await ApiService.getMe();
      final res = await dio.get('$_baseUrl/portfolio/tax-report');
      final data = res.data;
      final gains = data['gains'] as List<dynamic>? ?? [];
      final totalStcg = (data['total_stcg'] as num? ?? 0).toDouble();
      final totalLtcg = (data['total_ltcg'] as num? ?? 0).toDouble();
      final estStcgTax = (data['estimated_stcg_tax'] as num? ?? 0).toDouble();
      final estLtcgTax = (data['estimated_ltcg_tax'] as num? ?? 0).toDouble();
      final totalTax = (data['total_estimated_tax'] as num? ?? 0).toDouble();

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 30),
          header: (ctx) => ctx.pageNumber == 1
              ? _buildHeader('Tax P&L Report', 'Realized capital gains and estimated tax liability')
              : pw.SizedBox(),
          footer: _footer,
          build: (ctx) => [
            _buildAccountInfoBlock(userRes['user']),
            pw.Row(
              children: [
                _summaryTile('SHORT-TERM GAINS (STCG)', '\u20b9${totalStcg.toStringAsFixed(2)}'),
                _summaryTile('LONG-TERM GAINS (LTCG)', '\u20b9${totalLtcg.toStringAsFixed(2)}'),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                _summaryTile('EST. STCG TAX (20%)', '\u20b9${estStcgTax.toStringAsFixed(2)}'),
                _summaryTile('EST. LTCG TAX (12.5%)', '\u20b9${estLtcgTax.toStringAsFixed(2)}'),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(color: _brand, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL ESTIMATED TAX LIABILITY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text('\u20b9${totalTax.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ],
              ),
            ),
            pw.SizedBox(height: 22),
            pw.Text('Realized Gains by Trade', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(1.6),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.3),
                3: pw.FlexColumnWidth(1.3),
                4: pw.FlexColumnWidth(1.3),
                5: pw.FlexColumnWidth(1.3),
              },
              border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              children: [
                _tableHeaderRow(['Symbol', 'Qty', 'Buy Price', 'Sell Price', 'Days Held', 'Gain (\u20b9)']),
                ...List.generate(gains.length, (i) {
                  final g = gains[i];
                  final gain = (g['gain'] as num? ?? 0).toDouble();
                  return _tableDataRow([
                    g['symbol']?.toString() ?? '-',
                    (g['quantity'] as num? ?? 0).toStringAsFixed(0),
                    (g['buy_price'] as num? ?? 0).toStringAsFixed(2),
                    (g['sell_price'] as num? ?? 0).toStringAsFixed(2),
                    g['holding_days']?.toString() ?? '-',
                    gain.toStringAsFixed(2),
                  ], i.isOdd, colorCol: 5, isPositive: gain >= 0);
                }),
              ],
            ),
            if (gains.isEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('No realized gains found', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
            ],
            pw.SizedBox(height: 30),
            pw.Text(
              'Disclaimer: This is an estimate for informational purposes only, based on FIFO lot matching, and does not constitute professional tax advice. Please consult a tax advisor for filing purposes.',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
            ),
          ],
        ),
      );
      await _saveAndShare(doc, 'OneInvest_Tax_PL_Report.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not generate tax report')));
      }
    } finally {
      if (mounted) setState(() => _generating = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                  const Expanded(child: Text('Downloads', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _downloadCard(
                    Icons.account_balance_wallet_outlined,
                    'Holdings Statement',
                    'Your current stock holdings summary',
                    'holdings',
                    _downloadHoldings,
                  ),
                  const SizedBox(height: 12),
                  _downloadCard(
                    Icons.receipt_long_outlined,
                    'Trade Statement',
                    'Complete buy/sell trade history',
                    'tradebook',
                    _downloadTradebook,
                  ),
                  const SizedBox(height: 12),
                  _downloadCard(
                    Icons.description_outlined,
                    'Tax P&L Report',
                    'Realized capital gains and estimated tax',
                    'tax',
                    _downloadTaxReport,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _downloadCard(IconData icon, String title, String subtitle, String key, VoidCallback onTap) {
    final loading = _generating == key;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                  : const Icon(Icons.file_download_outlined, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}