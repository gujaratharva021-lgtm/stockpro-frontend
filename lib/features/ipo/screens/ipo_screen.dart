import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/ipo/screens/ipo_detail_screen.dart';

class IpoScreen extends StatefulWidget {
  const IpoScreen({super.key});
  @override
  State<IpoScreen> createState() => _IpoScreenState();
}

class _IpoScreenState extends State<IpoScreen> {
  List<dynamic> _ipos = [];
  bool _loading = true;
  String? _error;
  String _selectedStatus = 'All';

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
      final ipos = await ApiService.getIPOs();
      setState(() => _ipos = ipos);
    } catch (e) {
      setState(() => _error = 'Could not load IPOs');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _statuses {
    final stats = _ipos.map((i) => (i['status'] ?? '').toString()).where((s) => s.isNotEmpty).toSet().toList();
    stats.sort();
    return ['All', ...stats];
  }

  List<dynamic> get _filteredIpos {
    if (_selectedStatus == 'All') return _ipos;
    return _ipos.where((i) => i['status'] == _selectedStatus).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return const Color(0xFF16A34A);
      case 'upcoming':
        return const Color(0xFFF59E0B);
      case 'closed':
        return const Color(0xFFEF4444);
      case 'listed':
        return const Color(0xFF3B4FE8);
      default:
        return AppColors.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Open Now';
      case 'upcoming':
        return 'Upcoming';
      case 'closed':
        return 'Closed';
      case 'listed':
        return 'Listed';
      default:
        return status;
    }
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
                      const Text('IPO', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),

              if (!_loading && _error == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD81B60), Color(0xFFAD1457)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Apply for IPOs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${_ipos.length} IPOs available', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),

              if (!_loading && _error == null && _ipos.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _statuses.length,
                      itemBuilder: (context, index) {
                        final status = _statuses[index];
                        final selected = _selectedStatus == status;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedStatus = status),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                            ),
                            child: Text(
                              status == 'All' ? 'All' : _statusLabel(status),
                              style: TextStyle(
                                color: selected ? Colors.white : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))),
                )
              else if (_filteredIpos.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No IPOs in this category', style: TextStyle(color: AppColors.textSecondary))),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _IpoCard(
                        ipo: _filteredIpos[index],
                        color: _statusColor((_filteredIpos[index]['status'] ?? '').toString()),
                        statusLabel: _statusLabel((_filteredIpos[index]['status'] ?? '').toString()),
                      ),
                      childCount: _filteredIpos.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IpoCard extends StatelessWidget {
  final dynamic ipo;
  final Color color;
  final String statusLabel;
  const _IpoCard({required this.ipo, required this.color, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    final priceLow = (ipo['price_band_low'] as num?)?.toDouble() ?? 0.0;
    final priceHigh = (ipo['price_band_high'] as num?)?.toDouble() ?? 0.0;
    final name = (ipo['company_name'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'I';
    final lotSize = ipo['lot_size'] ?? 0;
    final issueSize = (ipo['issue_size'] ?? '').toString();

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IpoDetailScreen(ipoId: ipo['id']))),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(statusLabel, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Price Band', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text('₹${priceLow.toStringAsFixed(0)} - ₹${priceHigh.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lot Size', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text('$lotSize shares', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Issue Size', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text(issueSize, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Closes ${_formatDate(ipo['close_date'])}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return '';
    }
  }
}