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
  static const _baseUrl = 'https://stock-backend-11rm.onrender.com/api/v1';
  String? _generating;

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

  Future<void> _saveAndShare(pw.Document doc, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await doc.save());
    await Share.shareXFiles([XFile(file.path)], text: filename);
  }

  pw.Widget _headerWidget(String title, Map<String, dynamic>? user) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('StockPro', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(title, style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        pw.SizedBox(height: 8),
        pw.Text('Name: ${user?['name'] ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Email: ${user?['email'] ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Generated on: ${_formatDate(DateTime.now().toIso8601String())}', style: const pw.TextStyle(fontSize: 10)),
        pw.Divider(),
      ],
    );
  }

  Future<void> _downloadHoldings() async {
    setState(() => _generating = 'holdings');
    try {
      final dio = await _authedDio();
      final userRes = await ApiService.getMe();
      final res = await dio.get('$_baseUrl/portfolio/holdings');
      final holdings = res.data['holdings'] as List<dynamic>? ?? [];

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          build: (ctx) => [
            _headerWidget('Holdings Statement', userRes['user']),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Symbol', 'Qty', 'Avg Price', 'Invested'],
              data: holdings.map((h) {
                final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
                final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
                return [
                  h['symbol']?.toString() ?? '-',
                  qty.toStringAsFixed(0),
                  avg.toStringAsFixed(2),
                  (qty * avg).toStringAsFixed(2),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ],
        ),
      );
      await _saveAndShare(doc, 'Holdings_Statement.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not generate holdings statement')));
      }
    } finally {
      if (mounted) setState(() => _generating = null);
    }
  }

  Future<void> _downloadTradebook() async {
    setState(() => _generating = 'tradebook');
    try {
      final dio = await _authedDio();
      final userRes = await ApiService.getMe();
      final res = await dio.get('$_baseUrl/portfolio/transactions');
      final txns = res.data['transactions'] as List<dynamic>? ?? [];

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          build: (ctx) => [
            _headerWidget('Trade Statement', userRes['user']),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Date', 'Symbol', 'Type', 'Qty', 'Price', 'Total'],
              data: txns.map((t) {
                final qty = (t['quantity'] as num?)?.toDouble() ?? 0;
                final price = (t['price'] as num?)?.toDouble() ?? 0;
                return [
                  _formatDate(t['created_at']),
                  t['symbol']?.toString() ?? '-',
                  t['buy_sell']?.toString() ?? '-',
                  qty.toStringAsFixed(0),
                  price.toStringAsFixed(2),
                  (qty * price).toStringAsFixed(2),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ],
        ),
      );
      await _saveAndShare(doc, 'Trade_Statement.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not generate trade statement')));
      }
    } finally {
      if (mounted) setState(() => _generating = null);
    }
  }

  Future<void> _downloadTaxReport() async {
    setState(() => _generating = 'tax');
    try {
      final dio = await _authedDio();
      final userRes = await ApiService.getMe();
      final res = await dio.get('$_baseUrl/portfolio/tax-report');
      final data = res.data;
      final gains = data['gains'] as List<dynamic>? ?? [];

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          build: (ctx) => [
            _headerWidget('Tax P&L Report', userRes['user']),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total STCG: ${(data['total_stcg'] as num? ?? 0).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Total LTCG: ${(data['total_ltcg'] as num? ?? 0).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('Estimated Total Tax: ${(data['total_estimated_tax'] as num? ?? 0).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Symbol', 'Qty', 'Buy Price', 'Sell Price', 'Holding Days', 'Gain'],
              data: gains.map((g) {
                return [
                  g['symbol']?.toString() ?? '-',
                  (g['quantity'] as num? ?? 0).toStringAsFixed(0),
                  (g['buy_price'] as num? ?? 0).toStringAsFixed(2),
                  (g['sell_price'] as num? ?? 0).toStringAsFixed(2),
                  g['holding_days']?.toString() ?? '-',
                  (g['gain'] as num? ?? 0).toStringAsFixed(2),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ],
        ),
      );
      await _saveAndShare(doc, 'Tax_PL_Report.pdf');
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