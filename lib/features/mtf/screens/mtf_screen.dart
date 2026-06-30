import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/search/screens/search_screen.dart';
import 'package:stock_app/features/mtf/screens/mtf_open_screen.dart';

class MtfScreen extends StatefulWidget {
  const MtfScreen({super.key});

  @override
  State<MtfScreen> createState() => _MtfScreenState();
}

class _MtfScreenState extends State<MtfScreen> {
  List<dynamic> _positions = [];
  bool _loading = true;
  String? _error;
  bool _showOpen = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final positions = await ApiService.getMTFPositions();
      setState(() => _positions = positions);
    } catch (e) {
      setState(() => _error = 'Could not load MTF positions');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    return _positions.where((p) => (p['status'] == 'open') == _showOpen).toList();
  }

  Future<void> _pickStock() async {
    final stock = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen(selectMode: true)),
    );
    if (stock != null && mounted) {
      final opened = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MtfOpenScreen(stock: stock)),
      );
      if (opened == true) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickStock,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Position', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'MTF',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showOpen = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _showOpen ? AppColors.primary : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text('Open', textAlign: TextAlign.center,
                            style: TextStyle(color: _showOpen ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showOpen = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_showOpen ? AppColors.primary : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text('Closed', textAlign: TextAlign.center,
                            style: TextStyle(color: !_showOpen ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)))
                      : _filtered.isEmpty
                          ? Center(
                              child: Text(
                                _showOpen ? 'No open MTF positions' : 'No closed positions yet',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                                itemCount: _filtered.length,
                                itemBuilder: (context, index) {
                                  final p = _filtered[index];
                                  final qty = (p['quantity'] as num).toDouble();
                                  final entryPrice = (p['entry_price'] as num).toDouble();
                                  final margin = (p['margin_paid'] as num).toDouble();
                                  final borrowed = (p['borrowed_amount'] as num).toDouble();
                                  return GestureDetector(
                                    onTap: _showOpen
                                        ? () async {
                                            final closed = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => MtfOpenScreen(
                                                  position: p,
                                                  stock: {'id': p['stock_id'], 'symbol': p['symbol'], 'company_name': p['company_name']},
                                                ),
                                              ),
                                            );
                                            if (closed == true) _load();
                                          }
                                        : null,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.cardBackground,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(p['symbol'] ?? '',
                                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: (_showOpen ? AppColors.success : AppColors.textMuted).withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  _showOpen ? 'OPEN' : 'CLOSED',
                                                  style: TextStyle(
                                                    color: _showOpen ? AppColors.success : AppColors.textMuted,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(p['company_name'] ?? '',
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Qty: ${qty.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                              Text('Entry: ₹${entryPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Margin Paid: ₹${margin.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                              Text('Borrowed: ₹${borrowed.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}