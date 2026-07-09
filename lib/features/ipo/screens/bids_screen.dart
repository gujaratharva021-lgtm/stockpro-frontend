import 'package:flutter/material.dart';
import 'package:stock_app/shared/widgets/overview_sheet.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/features/ipo/screens/ipo_detail_screen.dart';

class BidsScreen extends StatefulWidget {
  const BidsScreen({super.key});

  @override
  State<BidsScreen> createState() => _BidsScreenState();
}

class _BidsScreenState extends State<BidsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['IPO', 'Govt. securities', 'Auctions', 'Corporate Actions'];

  List<dynamic> _ipos = [];
  List<dynamic> _applications = [];
  bool _loading = true;

  int _ipoSubTab = 0; // 0=Ongoing, 1=Applied, 2=Upcoming

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getIPOs(),
        ApiService.getMyIPOApplications(),
      ]);
      if (mounted) {
        setState(() {
          _ipos = results[0];
          _applications = results[1];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _ongoingIpos => _ipos.where((i) => i['status'] == 'open' || i['status'] == 'closed').toList();
  List<dynamic> get _upcomingIpos => _ipos.where((i) => i['status'] == 'upcoming').toList();

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day}${_ordinal(d.day)} ${months[d.month - 1]}';
    } catch (_) {
      return '-';
    }
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  Widget _emptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, color: AppColors.textMuted, size: 44),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _ipoRow(dynamic ipo) {
    final name = (ipo['company_name'] ?? '').toString();
    final status = (ipo['status'] ?? '').toString();
    final priceLow = (ipo['price_band_low'] as num?)?.toStringAsFixed(0) ?? '-';
    final priceHigh = (ipo['price_band_high'] as num?)?.toStringAsFixed(0) ?? '-';
    final isOpen = status == 'open';
    final symbolLike = name.split(' ').first.toUpperCase();

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IpoDetailScreen(ipoId: ipo['id']))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.6))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(symbolLike, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('₹$priceLow - ₹$priceHigh', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('${_formatDate(ipo['open_date'])} - ${_formatDate(ipo['close_date'])}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isOpen)
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IpoDetailScreen(ipoId: ipo['id']))),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                child: const Text('Pre-apply', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.border.withOpacity(0.4), borderRadius: BorderRadius.circular(6)),
                child: const Text('CLOSED', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _applicationRow(dynamic app) {
    final name = (app['company_name'] ?? '').toString();
    final lots = app['lots'] ?? 0;
    final amount = (app['amount'] as num?)?.toStringAsFixed(0) ?? '0';
    final status = (app['status'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.6))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('$lots lot(s) - ₹$amount', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(status.toUpperCase(), style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildIpoTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              _subTabChip('Ongoing', 0),
              const SizedBox(width: 10),
              _subTabChip('Applied', 1),
              const SizedBox(width: 10),
              _subTabChip('Upcoming', 2),
            ],
          ),
        ),
        const Divider(color: AppColors.border, height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _ipoSubTab == 0
                  ? (_ongoingIpos.isEmpty
                      ? _emptyState('No ongoing IPOs', 'Check back later for new IPO listings')
                      : ListView.builder(itemCount: _ongoingIpos.length, itemBuilder: (c, i) => _ipoRow(_ongoingIpos[i])))
                  : _ipoSubTab == 1
                      ? (_applications.isEmpty
                          ? _emptyState('No applications yet', 'IPOs you apply for will show up here')
                          : ListView.builder(itemCount: _applications.length, itemBuilder: (c, i) => _applicationRow(_applications[i])))
                      : (_upcomingIpos.isEmpty
                          ? _emptyState('No upcoming IPOs', 'New IPO announcements will appear here')
                          : ListView.builder(itemCount: _upcomingIpos.length, itemBuilder: (c, i) => _ipoRow(_upcomingIpos[i]))),
        ),
      ],
    );
  }

  Widget _subTabChip(String label, int index) {
    final active = _ipoSubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _ipoSubTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: active ? AppColors.border.withOpacity(0.4) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: active ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: active ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bids', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 24)),
                    GestureDetector(onTap: () => showOverviewSheet(context), child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: [
                  Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('IPO'), const SizedBox(width: 6), _countBadge(_ongoingIpos.length + _upcomingIpos.length)])),
                  const Tab(text: 'Govt. securities'),
                  const Tab(text: 'Auctions'),
                  const Tab(text: 'Corporate Actions'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildIpoTab(),
                    _emptyState('No government securities', 'T-Bills and G-Secs bidding is not available yet on this app'),
                    _emptyState('No stocks for auctions', 'Stocks eligible to be sold in the auction will be listed here'),
                    _emptyState('No corporate actions', 'Buybacks and other corporate actions will be listed here'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)),
      child: Text('$count', style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}