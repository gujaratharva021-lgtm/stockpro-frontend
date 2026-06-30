import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

const _bg = Color(0xFFF5F6FA);
const _card = Color(0xFFFFFFFF);
const _cardBorder = Color(0xFFE8EAF0);
const _accent = Color(0xFF3B4FE8);
const _textPrimary = Color(0xFF111827);
const _textSub = Color(0xFF6B7280);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);

class FiiDiiScreen extends StatefulWidget {
  const FiiDiiScreen({super.key});
  @override
  State<FiiDiiScreen> createState() => _FiiDiiScreenState();
}

class _FiiDiiScreenState extends State<FiiDiiScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;
  String? _error;
  List<dynamic> _fiiData = [];
  List<dynamic> _diiData = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Accept': 'application/json',
          'Referer': 'https://www.nseindia.com',
        },
      ));

      // NSE FII/DII endpoint
      final res = await dio.get(
        'https://www.nseindia.com/api/fiidiiTradeReact',
      );

      final data = res.data as List<dynamic>;
      setState(() {
        _fiiData = data.where((e) => e['category']?.toString().toLowerCase().contains('fii') == true || e['category']?.toString().toLowerCase().contains('fpi') == true).toList();
        _diiData = data.where((e) => e['category']?.toString().toLowerCase().contains('dii') == true).toList();
        if (_fiiData.isEmpty && _diiData.isEmpty) {
          // fallback: split evenly
          _fiiData = data.take(data.length ~/ 2).toList();
          _diiData = data.skip(data.length ~/ 2).toList();
        }
      });
    } catch (e) {
      setState(() => _error = 'NSE se data nahi aaya.\nCheck internet connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('FII / DII Activity', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tab,
          labelColor: _accent,
          unselectedLabelColor: _textSub,
          indicatorColor: _accent,
          tabs: const [Tab(text: 'FII / FPI'), Tab(text: 'DII')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _accent),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.cloud_off, color: _textSub, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _textSub, fontSize: 13)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      style: ElevatedButton.styleFrom(backgroundColor: _accent),
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                    ),
                  ]),
                )
              : TabBarView(
                  controller: _tab,
                  children: [
                    _buildTable(_fiiData),
                    _buildTable(_diiData),
                  ],
                ),
    );
  }

  Widget _buildTable(List<dynamic> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available', style: TextStyle(color: _textSub)));
    }
    return RefreshIndicator(
      color: _accent,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Summary Cards
            _buildSummaryCards(data),
            const SizedBox(height: 16),
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Date', style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text('Buy (Cr)', style: TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('Sell (Cr)', style: TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('Net (Cr)', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Rows
            ...data.map((e) => _buildRow(e)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(List<dynamic> data) {
    double totalBuy = 0, totalSell = 0, totalNet = 0;
    for (final e in data) {
      totalBuy += _parseNum(e['buyValue'] ?? e['buy_value'] ?? e['BuyValue']);
      totalSell += _parseNum(e['sellValue'] ?? e['sell_value'] ?? e['SellValue']);
      totalNet += _parseNum(e['netValue'] ?? e['net_value'] ?? e['NetValue']);
    }
    return Row(children: [
      _summaryCard('Total Buy', '₹${_formatCr(totalBuy)} Cr', _green),
      const SizedBox(width: 8),
      _summaryCard('Total Sell', '₹${_formatCr(totalSell)} Cr', _red),
      const SizedBox(width: 8),
      _summaryCard('Net', '₹${_formatCr(totalNet)} Cr', totalNet >= 0 ? _green : _red),
    ]);
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Text(label, style: const TextStyle(color: _textSub, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildRow(dynamic e) {
    final buy = _parseNum(e['buyValue'] ?? e['buy_value'] ?? e['BuyValue']);
    final sell = _parseNum(e['sellValue'] ?? e['sell_value'] ?? e['SellValue']);
    final net = _parseNum(e['netValue'] ?? e['net_value'] ?? e['NetValue']);
    final date = e['date'] ?? e['Date'] ?? e['tradeDate'] ?? '--';
    final isPositive = net >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(children: [
        Expanded(flex: 3, child: Text(date.toString(), style: const TextStyle(color: _textPrimary, fontSize: 12))),
        Expanded(flex: 2, child: Text(_formatCr(buy), style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text(_formatCr(sell), style: const TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text(
          '${isPositive ? '+' : ''}${_formatCr(net)}',
          style: TextStyle(color: isPositive ? _green : _red, fontSize: 12, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        )),
      ]),
    );
  }

  double _parseNum(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().replaceAll(',', '')) ?? 0;
  }

  String _formatCr(double val) {
    if (val.abs() >= 100000) return '${(val / 100000).toStringAsFixed(2)}L';
    if (val.abs() >= 1000) return '${(val / 1000).toStringAsFixed(2)}K';
    return val.toStringAsFixed(2);
  }
}