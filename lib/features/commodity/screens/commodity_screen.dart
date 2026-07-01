import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/commodity/screens/commodity_detail_screen.dart';

class CommodityScreen extends StatefulWidget {
  const CommodityScreen({super.key});

  @override
  State<CommodityScreen> createState() => _CommodityScreenState();
}

class _CommodityScreenState extends State<CommodityScreen> {
  List<dynamic> _commodities = [];
  final Map<String, Map<String, dynamic>> _details = {};
  bool _loading = true;
  String? _error;
  int _tab = 0; // 0=Overview, 1=Metals, 2=Energy, 3=Agri, 4=Currency

  static const List<String> _tabs = ['Overview', 'Metals', 'Energy', 'Agri', 'Currency'];

  static const Map<String, String> _categoryMap = {
    'GOLD': 'Metals',
    'SILVER': 'Metals',
    'COPPER': 'Metals',
    'PLATINUM': 'Metals',
    'ALUMINIUM': 'Metals',
    'ZINC': 'Metals',
    'LEAD': 'Metals',
    'NICKEL': 'Metals',
    'CRUDEOIL': 'Energy',
    'NATURALGAS': 'Energy',
    'NATGAS': 'Energy',
    'WHEAT': 'Agri',
    'CORN': 'Agri',
    'SOYBEAN': 'Agri',
    'COTTON': 'Agri',
    'SUGAR': 'Agri',
  };

  static const Map<String, IconData> _icons = {
    'GOLD': Icons.diamond_outlined,
    'SILVER': Icons.circle_outlined,
    'CRUDEOIL': Icons.local_gas_station_outlined,
    'NATURALGAS': Icons.local_fire_department_outlined,
    'NATGAS': Icons.local_fire_department_outlined,
    'COPPER': Icons.hub_outlined,
    'ALUMINIUM': Icons.layers_outlined,
    'ZINC': Icons.science_outlined,
    'LEAD': Icons.battery_charging_full_outlined,
    'NICKEL': Icons.monetization_on_outlined,
    'PLATINUM': Icons.star_outline,
    'WHEAT': Icons.grass_outlined,
    'CORN': Icons.eco_outlined,
    'SOYBEAN': Icons.spa_outlined,
    'COTTON': Icons.cloud_outlined,
    'SUGAR': Icons.cookie_outlined,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final commodities = await ApiService.getCommodities();
      setState(() => _commodities = commodities);
      for (final c in commodities) {
        ApiService.getCommodityDetail(c['id']).then((detail) {
          if (mounted) setState(() => _details[c['id']] = detail);
        }).catchError((_) {});
      }
    } catch (e) {
      setState(() => _error = 'Could not load commodities');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filteredCommodities {
    if (_tab == 0) return _commodities;
    final tabName = _tabs[_tab];
    return _commodities.where((c) {
      final symbol = (c['symbol'] ?? '').toString().toUpperCase();
      return _categoryMap[symbol] == tabName;
    }).toList();
  }

  Color _iconColor(dynamic c) {
    try {
      return Color(int.parse((c['icon_color'] as String).replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                      const Text('Commodity', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.search, color: AppColors.textPrimary), onPressed: () {}),
                ],
              ),
            ),

            // Category tabs
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final active = _tab == index;
                  return GestureDetector(
                    onTap: () => setState(() => _tab = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(_tabs[index], style: TextStyle(color: active ? Colors.white : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))))
            else ...[
                // Table header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('Commodity', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('Change', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: _filteredCommodities.isEmpty
                        ? Center(child: Text('No ${_tabs[_tab]} commodities', style: const TextStyle(color: AppColors.textSecondary)))
                        : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _filteredCommodities.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                      itemBuilder: (context, index) {
                        final c = _filteredCommodities[index];
                        final detail = _details[c['id']];
                        final price = detail != null ? (detail['price'] as num?)?.toDouble() : null;
                        final change = detail != null ? (detail['change'] as num?)?.toDouble() : null;
                        final changePct = detail != null ? (detail['change_percent'] as num?)?.toDouble() : null;
                        final isUp = (change ?? 0) >= 0;
                        final color = _iconColor(c);
                        final icon = _icons[(c['symbol'] ?? '').toString().toUpperCase()] ?? Icons.scatter_plot_outlined;

                        return GestureDetector(
                          onTap: () async {
                            final ok = await Navigator.push(context, MaterialPageRoute(builder: (_) => CommodityDetailScreen(commodityId: c['id'])));
                            if (ok == true) _load();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34, height: 34,
                                        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                        child: Icon(icon, color: color, size: 16),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(c['name'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            Text(c['unit'] ?? 'MCX', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: price != null
                                      ? Text('₹${price.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13))
                                      : const Align(alignment: Alignment.centerRight, child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: change != null
                                      ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${isUp ? '+' : ''}${change.toStringAsFixed(2)}', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                                      Text('${isUp ? '+' : ''}${changePct?.toStringAsFixed(2) ?? '0.00'}%', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 11)),
                                    ],
                                  )
                                      : const SizedBox(),
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
          ],
        ),
      ),
    );
  }
}