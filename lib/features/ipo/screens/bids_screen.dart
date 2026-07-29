import 'package:flutter/material.dart';
import 'package:stock_app/shared/widgets/overview_sheet.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/shared/widgets/stock_logo.dart';
import 'package:stock_app/features/ipo/screens/ipo_detail_screen.dart';

const Color _kWarning = Color(0xFFF59E0B);
const Color _kPurple = Color(0xFF8B5CF6);
const List<Color> _kAccentColors = [AppColors.primary, AppColors.success, _kPurple];

class BidsScreen extends StatefulWidget {
  const BidsScreen({super.key});

  @override
  State<BidsScreen> createState() => _BidsScreenState();
}

class _BidsScreenState extends State<BidsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['IPO', 'Govt. securities', 'Auctions', 'Corporate actions'];

  List<dynamic> _ipos = [];
  List<dynamic> _applications = [];
  bool _loading = true;

  int _mainTab = 0;
  int _ipoSubTab = 0; // 0=Ongoing, 1=Upcoming, 2=Applied

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _mainTab = _tabController.index);
      }
    });
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
  int get _totalApplications => _ongoingIpos.length + _upcomingIpos.length + _applications.length;

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

  Widget _statsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.trending_up, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Applications', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text('$_totalApplications', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 22)),
              ],
            ),
          ),
          _statPill('Ongoing', _ongoingIpos.length, AppColors.primary),
          const SizedBox(width: 14),
          _statPill('Upcoming', _upcomingIpos.length, _kWarning),
          const SizedBox(width: 14),
          _statPill('Applied', _applications.length, AppColors.success),
        ],
      ),
    );
  }

  Widget _statPill(String label, int count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  Widget _subTabChip(String label, IconData icon, int index) {
    final active = _ipoSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _ipoSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: active ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ipoCard(dynamic ipo, int index) {
    final companyName = (ipo['company_name'] ?? '').toString();
    final status = (ipo['status'] ?? '').toString();
    final priceLow = (ipo['price_band_low'] as num?)?.toStringAsFixed(0) ?? '-';
    final priceHigh = (ipo['price_band_high'] as num?)?.toStringAsFixed(0) ?? '-';
    final isOpen = status == 'open';
    final symbolLike = companyName.split(' ').first.toUpperCase();
    final lotSize = ipo['lot_size'];
    final accent = _kAccentColors[index % _kAccentColors.length];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IpoDetailScreen(ipoId: ipo['id']))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: accent, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StockLogo(symbol: symbolLike, companyName: companyName, size: 44, borderRadiusFactor: 1.0),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(companyName, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(symbolLike, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(5)),
                        child: const Text('IPO', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('₹$priceLow - ₹$priceHigh', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('${_formatDate(ipo['open_date'])} - ${_formatDate(ipo['close_date'])}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Min. Lot Size', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                      Text(lotSize != null ? '$lotSize Shares' : '-', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (isOpen)
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IpoDetailScreen(ipoId: ipo['id']))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Pre-apply', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
                    child: const Text('CLOSED', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _applicationCard(dynamic app, int index) {
    final name = (app['company_name'] ?? '').toString();
    final lots = app['lots'] ?? 0;
    final amount = (app['amount'] as num?)?.toStringAsFixed(0) ?? '0';
    final status = (app['status'] ?? '').toString();
    final accent = _kAccentColors[index % _kAccentColors.length];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          StockLogo(companyName: name, size: 40, borderRadiusFactor: 1.0),
          const SizedBox(width: 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(status.toUpperCase(), style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _promoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Text('🚀', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Stay ahead of the market', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('Get notified about new IPOs and never miss an opportunity.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Explore IPOs', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: AppColors.primary, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpoTab() {
    return Column(
      children: [
        _statsBar(),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              _subTabChip('Ongoing', Icons.access_time, 0),
              _subTabChip('Upcoming', Icons.calendar_today_outlined, 1),
              _subTabChip('Applied', Icons.check_circle_outline, 2),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _ipoSubTab == 0
                  ? (_ongoingIpos.isEmpty
                      ? _emptyState('No ongoing IPOs', 'Check back later for new IPO listings')
                      : ListView.builder(
                          itemCount: _ongoingIpos.length + 1,
                          itemBuilder: (c, i) => i < _ongoingIpos.length ? _ipoCard(_ongoingIpos[i], i) : _promoBanner(),
                        ))
                  : _ipoSubTab == 1
                      ? (_upcomingIpos.isEmpty
                          ? _emptyState('No upcoming IPOs', 'New IPO announcements will appear here')
                          : ListView.builder(itemCount: _upcomingIpos.length, itemBuilder: (c, i) => _ipoCard(_upcomingIpos[i], i)))
                      : (_applications.isEmpty
                          ? _emptyState('No applications yet', 'IPOs you apply for will show up here')
                          : ListView.builder(itemCount: _applications.length, itemBuilder: (c, i) => _applicationCard(_applications[i], i))),
        ),
      ],
    );
  }

  Widget _mainTabPill(String label, int index, {int? badge}) {
    final active = _mainTab == index;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.border.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: active ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text('$badge', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Bids', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 26)),
                          SizedBox(height: 2),
                          Text('Track your IPO & auction applications', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => showOverviewSheet(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                        child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _mainTabPill('IPO', 0, badge: _ongoingIpos.length + _upcomingIpos.length + _applications.length),
                      _mainTabPill('Govt. securities', 1),
                      _mainTabPill('Auctions', 2),
                      _mainTabPill('Corporate actions', 3),
                    ],
                  ),
                ),
              ),
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
}