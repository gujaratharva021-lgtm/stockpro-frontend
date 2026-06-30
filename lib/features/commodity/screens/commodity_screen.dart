import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/commodity/screens/commodity_detail_screen.dart';

class CommodityScreen extends StatefulWidget {
  const CommodityScreen({super.key});

  @override
  State<CommodityScreen> createState() => _CommodityScreenState();
}

class _CommodityScreenState extends State<CommodityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _commodities = [];
  List<dynamic> _holdings = [];
  final Map<String, double> _prices = {};
  bool _loading = true;
  String? _error;

  static const Map<String, IconData> _icons = {
    'GOLD': Icons.diamond_outlined,
    'SILVER': Icons.circle_outlined,
    'CRUDEOIL': Icons.local_gas_station_outlined,
    'NATURALGAS': Icons.local_fire_department_outlined,
    'COPPER': Icons.hub_outlined,
  };

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
      final commodities = await ApiService.getCommodities();
      final holdings = await ApiService.getCommodityPortfolio();
      setState(() {
        _commodities = commodities;
        _holdings = holdings;
        _loading = false;
      });
      for (final c in commodities) {
        ApiService.getCommodityDetail(c['id']).then((detail) {
          if (mounted) {
            setState(() => _prices[c['id']] = (detail['price'] as num?)?.toDouble() ?? 0);
          }
        }).catchError((_) {});
      }
    } catch (e) {
      setState(() {
        _error = 'Could not load commodities';
        _loading = false;
      });
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
                    'Commodity',
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
                Tab(text: 'My Holdings'),
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
                            _buildExploreList(),
                            _buildHoldingsList(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreList() {
    if (_commodities.isEmpty) {
      return const Center(child: Text('No commodities found', style: TextStyle(color: AppColors.textSecondary)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _commodities.length,
        itemBuilder: (context, index) {
          final c = _commodities[index];
          Color iconColor;
          try {
            iconColor = Color(int.parse((c['icon_color'] as String).replaceFirst('#', '0xFF')));
          } catch (_) {
            iconColor = AppColors.primary;
          }
          final icon = _icons[c['symbol']] ?? Icons.scatter_plot_outlined;
          final price = _prices[c['id']];

          return GestureDetector(
            onTap: () async {
              final ok = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CommodityDetailScreen(commodityId: c['id'])),
              );
              if (ok == true) _load();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [iconColor.withOpacity(0.20), iconColor.withOpacity(0.08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['name'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(c['unit'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      price != null
                          ? Text('\$${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15))
                          : const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      const SizedBox(height: 4),
                      const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
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

  Widget _buildHoldingsList() {
    if (_holdings.isEmpty) {
      return const Center(child: Text('No commodity holdings yet', style: TextStyle(color: AppColors.textSecondary)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _holdings.length,
        itemBuilder: (context, index) {
          final h = _holdings[index];
          Color iconColor;
          try {
            iconColor = Color(int.parse((h['icon_color'] as String).replaceFirst('#', '0xFF')));
          } catch (_) {
            iconColor = AppColors.primary;
          }
          final icon = _icons[h['symbol']] ?? Icons.scatter_plot_outlined;
          final qty = (h['quantity'] as num).toDouble();
          final avgPrice = (h['avg_price'] as num).toDouble();

          return GestureDetector(
            onTap: () async {
              final ok = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CommodityDetailScreen(commodityId: h['commodity_id'])),
              );
              if (ok == true) _load();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h['name'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Qty: ${qty.toStringAsFixed(4)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Avg \$${avgPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16),
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
}