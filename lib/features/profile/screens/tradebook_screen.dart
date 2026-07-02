import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class TradebookScreen extends StatefulWidget {
  const TradebookScreen({super.key});
  @override
  State<TradebookScreen> createState() => _TradebookScreenState();
}

class _TradebookScreenState extends State<TradebookScreen> {
  List<dynamic> _transactions = [];
  bool _loading = true;
  String _filter = 'ALL'; // ALL, BUY, SELL

  static const _baseUrl = 'https://stock-backend-11rm.onrender.com/api/v1';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = Dio();
      final token = await ApiService.getToken();
      final res = await dio.get(
        '$_baseUrl/portfolio/transactions',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _transactions = res.data['transactions'] ?? []);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load tradebook')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    if (_filter == 'ALL') return _transactions;
    return _transactions.where((t) => t['buy_sell'] == _filter).toList();
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
    } catch (_) {
      return '-';
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
                  const Expanded(child: Text('Tradebook', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _filterChip('ALL', 'All'),
                  const SizedBox(width: 8),
                  _filterChip('BUY', 'Buy'),
                  const SizedBox(width: 8),
                  _filterChip('SELL', 'Sell'),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 48),
                      SizedBox(height: 12),
                      Text('No trades found', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final t = _filtered[i];
                      final isBuy = t['buy_sell'] == 'BUY';
                      final qty = (t['quantity'] as num?)?.toDouble() ?? 0;
                      final price = (t['price'] as num?)?.toDouble() ?? 0;
                      final total = qty * price;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: (isBuy ? AppColors.success : AppColors.danger).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isBuy ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isBuy ? AppColors.success : AppColors.danger,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(t['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isBuy ? AppColors.success : AppColors.danger).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          t['buy_sell'] ?? '',
                                          style: TextStyle(color: isBuy ? AppColors.success : AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_formatDate(t['created_at']), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${qty.toStringAsFixed(0)} @ ₹${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ],
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

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}