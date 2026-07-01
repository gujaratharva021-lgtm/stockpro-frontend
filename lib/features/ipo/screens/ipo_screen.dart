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
  int _tab = 0; // 0=Current, 1=Upcoming, 2=Listed

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ipos = await ApiService.getIPOs();
      setState(() => _ipos = ipos);
    } catch (e) {
      setState(() => _error = 'Could not load IPOs');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _currentIpos => _ipos.where((i) => i['status'] == 'open').toList();
  List<dynamic> get _upcomingIpos => _ipos.where((i) => i['status'] == 'upcoming').toList();
  List<dynamic> get _listedIpos => _ipos.where((i) => i['status'] == 'listed' || i['status'] == 'closed').toList();

  List<dynamic> get _filteredIpos {
    switch (_tab) {
      case 1: return _upcomingIpos;
      case 2: return _listedIpos;
      default: return _currentIpos;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open': return const Color(0xFF16A34A);
      case 'upcoming': return const Color(0xFFF59E0B);
      case 'closed': return const Color(0xFFEF4444);
      case 'listed': return const Color(0xFF3B4FE8);
      default: return AppColors.primary;
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return '-'; }
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
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                          const Text('IPO', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.search, color: AppColors.textPrimary), onPressed: () {}),
                    ],
                  ),
                ),
              ),

              // Tabs
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _tabChip('Current IPOs', _currentIpos.length, 0),
                      const SizedBox(width: 20),
                      _tabChip('Upcoming', _upcomingIpos.length, 1),
                      const SizedBox(width: 20),
                      _tabChip('Listed', _listedIpos.length, 2),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Divider(color: AppColors.border, height: 20)),

              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else if (_error != null)
                SliverFillRemaining(child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))))
              else if (_filteredIpos.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_outlined, color: AppColors.textMuted, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _tab == 0 ? 'No open IPOs right now' : _tab == 1 ? 'No upcoming IPOs' : 'No listed IPOs',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                    if (_tab == 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text('Current IPOs', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) => _IpoCard(
                            ipo: _filteredIpos[index],
                            statusColor: _statusColor((_filteredIpos[index]['status'] ?? '').toString()),
                            formatDate: _formatDate,
                            isOpen: _filteredIpos[index]['status'] == 'open',
                          ),
                          childCount: _filteredIpos.length,
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

  Widget _tabChip(String label, int count, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(color: active ? AppColors.primaryDark : AppColors.textSecondary, fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: active ? AppColors.primary.withOpacity(0.15) : AppColors.border, borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: TextStyle(color: active ? AppColors.primaryDark : AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (active) Container(margin: const EdgeInsets.only(top: 6), height: 2, width: 24, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _IpoCard extends StatelessWidget {
  final dynamic ipo;
  final Color statusColor;
  final String Function(dynamic) formatDate;
  final bool isOpen;

  const _IpoCard({required this.ipo, required this.statusColor, required this.formatDate, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final name = (ipo['company_name'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'I';
    final priceLow = (ipo['price_band_low'] as num?)?.toDouble() ?? 0.0;
    final priceHigh = (ipo['price_band_high'] as num?)?.toDouble() ?? 0.0;
    final lotSize = ipo['lot_size'] ?? 0;
    final issueSize = (ipo['issue_size'] ?? '-').toString();
    final exchange = (ipo['exchange'] ?? 'Mainboard').toString();
    final status = (ipo['status'] ?? '').toString();

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IpoDetailScreen(ipoId: ipo['id']))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Text(initial, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                                  child: Text(exchange, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                  child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _stat('Price Band', '₹${priceLow.toStringAsFixed(0)} - ₹${priceHigh.toStringAsFixed(0)}'),
                      _stat('Lot Size', '$lotSize Shares'),
                      _stat('Issue Size', issueSize),
                      if (isOpen)
                        _stat('Closing In', _daysLeft(ipo['close_date'])),
                    ],
                  ),
                  if (ipo['close_date'] != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      isOpen ? 'Apply By ${formatDate(ipo['close_date'])}' : 'Closed on ${formatDate(ipo['close_date'])}',
                      style: TextStyle(color: isOpen ? AppColors.textSecondary : AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            if (isOpen)
              Container(
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IpoDetailScreen(ipoId: ipo['id']))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
                          child: const Center(child: Text('Apply Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _daysLeft(dynamic closeDate) {
    if (closeDate == null) return '-';
    try {
      final close = DateTime.parse(closeDate.toString());
      final diff = close.difference(DateTime.now()).inDays;
      if (diff < 0) return 'Closed';
      if (diff == 0) return 'Today';
      return '$diff Days';
    } catch (_) { return '-'; }
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}