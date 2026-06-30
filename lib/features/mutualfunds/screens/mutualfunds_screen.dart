import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/mutualfunds/screens/fund_detail_screen.dart';

class MutualFundsScreen extends StatefulWidget {
  const MutualFundsScreen({super.key});
  @override
  State<MutualFundsScreen> createState() => _MutualFundsScreenState();
}

class _MutualFundsScreenState extends State<MutualFundsScreen> {
  List<dynamic> _funds = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'All';

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
      final funds = await ApiService.getMutualFunds();
      setState(() => _funds = funds);
    } catch (e) {
      setState(() => _error = 'Could not load mutual funds');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _categories {
    final cats = _funds.map((f) => (f['category'] ?? '').toString()).where((c) => c.isNotEmpty).toSet().toList();
    cats.sort();
    return cats;
  }

  List<dynamic> get _filteredFunds {
    if (_selectedCategory == 'All') return _funds;
    return _funds.where((f) => f['category'] == _selectedCategory).toList();
  }

  Color _categoryColor(String category) {
    if (category.contains('Large Cap')) return const Color(0xFF3B4FE8);
    if (category.contains('Mid Cap')) return const Color(0xFF8B5CF6);
    if (category.contains('Small Cap')) return const Color(0xFFEC4899);
    if (category.contains('Flexi')) return const Color(0xFF16A34A);
    if (category.contains('Hybrid')) return const Color(0xFFF59E0B);
    if (category.contains('Index')) return const Color(0xFF06B6D4);
    return AppColors.primary;
  }

  IconData _categoryIcon(String category) {
    if (category.contains('Large Cap')) return Icons.show_chart;
    if (category.contains('Mid Cap')) return Icons.trending_up;
    if (category.contains('Small Cap')) return Icons.bolt;
    if (category.contains('Flexi')) return Icons.shuffle;
    if (category.contains('Hybrid')) return Icons.balance;
    if (category.contains('Index')) return Icons.layers;
    return Icons.savings_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Colors.white,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(child: Text('Mutual Funds', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                    ],
                  ),
                ),
              ),

              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else if (_error != null)
                SliverFillRemaining(child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))))
              else ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Popular Categories
                  if (_categories.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Popular Categories', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: () => setState(() => _selectedCategory = 'All'),
                              child: const Text('View All >', style: TextStyle(color: AppColors.primaryDark, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final color = _categoryColor(cat);
                            final selected = _selectedCategory == cat;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedCategory = selected ? 'All' : cat),
                              child: Container(
                                width: 78,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: selected ? color : color.withOpacity(0.12),
                                        border: selected ? null : Border.all(color: color.withOpacity(0.3)),
                                      ),
                                      child: Icon(_categoryIcon(cat), color: selected ? Colors.white : color, size: 22),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(cat, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],

                  // Fund list header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategory == 'All' ? 'All Mutual Funds' : _selectedCategory,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          if (_selectedCategory != 'All')
                            GestureDetector(
                              onTap: () => setState(() => _selectedCategory = 'All'),
                              child: const Text('Clear filter', style: TextStyle(color: AppColors.primaryDark, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  if (_filteredFunds.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: Text('No funds in this category', style: TextStyle(color: AppColors.textSecondary))),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: MediaQuery.of(context).size.width > 768
                          ? SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.6,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                              (context, index) => _FundCard(
                            fund: _filteredFunds[index],
                            color: _categoryColor((_filteredFunds[index]['category'] ?? '').toString()),
                          ),
                          childCount: _filteredFunds.length,
                        ),
                      )
                          : SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) => _FundCard(
                            fund: _filteredFunds[index],
                            color: _categoryColor((_filteredFunds[index]['category'] ?? '').toString()),
                          ),
                          childCount: _filteredFunds.length,
                        ),
                      ),
                    ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FundCard extends StatelessWidget {
  final dynamic fund;
  final Color color;
  const _FundCard({required this.fund, required this.color});

  @override
  Widget build(BuildContext context) {
    final nav = (fund['nav'] as num?)?.toDouble() ?? 0.0;
    final name = (fund['name'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'F';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FundDetailScreen(fundId: fund['id']))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${nav.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    const Text('NAV', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              fund['description'] ?? '',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    fund['category'] ?? '',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}