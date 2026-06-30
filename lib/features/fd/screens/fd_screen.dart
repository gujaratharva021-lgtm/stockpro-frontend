import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/fd/screens/fd_invest_screen.dart';

class FdScreen extends StatefulWidget {
  const FdScreen({super.key});

  @override
  State<FdScreen> createState() => _FdScreenState();
}

class _FdScreenState extends State<FdScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _products = [];
  List<dynamic> _investments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await ApiService.getFDProducts();
      final investments = await ApiService.getFDInvestments();
      setState(() {
        _products = products;
        _investments = investments;
      });
    } catch (e) {
      setState(() => _error = 'Could not load FD data');
    } finally {
      if (mounted) setState(() => _loading = false);
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Fixed Deposits',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Explore'),
                Tab(text: 'My Investments'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildProductsList(),
                            _buildInvestmentsList(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    if (_products.isEmpty) {
      return const Center(child: Text('No FD products available', style: TextStyle(color: AppColors.textSecondary)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final p = _products[index];
          final rate = (p['interest_rate'] as num).toDouble();
          final tenure = p['tenure_months'] as int;
          final insured = (p['insured_upto'] as num).toDouble();
          final isTaxSaving = p['is_tax_saving'] as bool? ?? false;
          Color bankColor;
          try {
            bankColor = Color(int.parse((p['logo_color'] as String).replaceFirst('#', '0xFF')));
          } catch (_) {
            bankColor = AppColors.primary;
          }

          return GestureDetector(
            onTap: () async {
              final invested = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FdInvestScreen(product: p)),
              );
              if (invested == true) _load();
            },
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
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: bankColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                        child: Center(
                          child: Text(
                            (p['bank_name'] as String).substring(0, 1),
                            style: TextStyle(color: bankColor, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['bank_name'] ?? '',
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('Insured up to ₹${(insured / 100000).toStringAsFixed(0)}L',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (isTaxSaving)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Tax Saving', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Interest Rate', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text('${rate.toStringAsFixed(2)}%',
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Tenure', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text(tenure >= 12 ? '${(tenure / 12).toStringAsFixed(tenure % 12 == 0 ? 0 : 1)} yr' : '$tenure mo',
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () async {
                            final invested = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => FdInvestScreen(product: p)),
                            );
                            if (invested == true) _load();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('INVEST NOW', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInvestmentsList() {
    if (_investments.isEmpty) {
      return const Center(child: Text('No FD investments yet', style: TextStyle(color: AppColors.textSecondary)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _investments.length,
        itemBuilder: (context, index) {
          final inv = _investments[index];
          final principal = (inv['principal'] as num).toDouble();
          final maturityAmount = (inv['maturity_amount'] as num).toDouble();
          final rate = (inv['interest_rate'] as num).toDouble();
          final status = inv['status'] as String;
          final isActive = status == 'active';

          return GestureDetector(
            onTap: isActive
                ? () async {
                    final withdrawn = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FdInvestScreen(investment: inv)),
                    );
                    if (withdrawn == true) _load();
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
                      Text(inv['bank_name'] ?? '',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isActive ? AppColors.success : AppColors.textMuted).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(color: isActive ? AppColors.success : AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Principal: ₹${principal.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text('Rate: ${rate.toStringAsFixed(2)}%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Maturity Value: ₹${maturityAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}