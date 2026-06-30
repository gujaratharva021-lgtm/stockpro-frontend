import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';

class ScreenerScreen extends StatefulWidget {
  const ScreenerScreen({super.key});
  @override
  State<ScreenerScreen> createState() => _ScreenerScreenState();
}

class _ScreenerScreenState extends State<ScreenerScreen> {
  List<dynamic> _allStocks = [];
  final Map<String, Map<String, dynamic>> _quotes = {};
  bool _loading = true;

  Set<String> _selectedSectors = {};
  String _changeFilter = 'ALL'; // ALL, GAINERS, LOSERS
  double _minPrice = 0;
  double _maxPrice = 50000;
  String _sortBy = 'NAME'; // NAME, PRICE_HIGH, PRICE_LOW, CHANGE_HIGH, CHANGE_LOW

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stocks = await ApiService.getStocks();
      setState(() => _allStocks = stocks);

      await Future.wait(stocks.map((s) async {
        try {
          final q = await ApiService.getQuote(s['symbol']);
          _quotes[s['symbol']] = q;
        } catch (_) {}
      }));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _allSectors {
    final sectors = _allStocks.map((s) => (s['sector'] ?? 'Other').toString()).toSet().toList();
    sectors.sort();
    return sectors;
  }

  List<dynamic> get _filteredStocks {
    var result = _allStocks.where((s) {
      final sector = (s['sector'] ?? 'Other').toString();
      if (_selectedSectors.isNotEmpty && !_selectedSectors.contains(sector)) return false;

      final quote = _quotes[s['symbol']];
      final price = quote != null && quote['price'] != null ? (quote['price'] as num).toDouble() : null;
      final changePercent = quote != null && quote['change_percent'] != null ? (quote['change_percent'] as num).toDouble() : null;

      if (price != null && (price < _minPrice || price > _maxPrice)) return false;

      if (_changeFilter == 'GAINERS' && (changePercent == null || changePercent <= 0)) return false;
      if (_changeFilter == 'LOSERS' && (changePercent == null || changePercent >= 0)) return false;

      return true;
    }).toList();

    result.sort((a, b) {
      final qa = _quotes[a['symbol']];
      final qb = _quotes[b['symbol']];
      switch (_sortBy) {
        case 'PRICE_HIGH':
          return ((qb?['price'] as num?)?.toDouble() ?? 0).compareTo((qa?['price'] as num?)?.toDouble() ?? 0);
        case 'PRICE_LOW':
          return ((qa?['price'] as num?)?.toDouble() ?? 0).compareTo((qb?['price'] as num?)?.toDouble() ?? 0);
        case 'CHANGE_HIGH':
          return ((qb?['change_percent'] as num?)?.toDouble() ?? 0).compareTo((qa?['change_percent'] as num?)?.toDouble() ?? 0);
        case 'CHANGE_LOW':
          return ((qa?['change_percent'] as num?)?.toDouble() ?? 0).compareTo((qb?['change_percent'] as num?)?.toDouble() ?? 0);
        default:
          return (a['symbol'] ?? '').compareTo(b['symbol'] ?? '');
      }
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStocks;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Stock Screener',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.filter_list, color: AppColors.textSecondary),
                    onPressed: _showFilterSheet,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _quickFilter('ALL', 'All')),
                  const SizedBox(width: 8),
                  Expanded(child: _quickFilter('GAINERS', 'Gainers')),
                  const SizedBox(width: 8),
                  Expanded(child: _quickFilter('LOSERS', 'Losers')),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${filtered.length} stocks', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  if (_selectedSectors.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _selectedSectors = {}),
                      child: const Text('Clear sectors', style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    final quote = _quotes[s['symbol']];
                    final price = quote != null && quote['price'] != null ? (quote['price'] as num).toDouble() : null;
                    final changePercent = quote != null && quote['change_percent'] != null ? (quote['change_percent'] as num).toDouble() : null;
                    final isUp = (changePercent ?? 0) >= 0;

                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(stock: s))),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(s['sector'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            if (price != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(
                                    '${changePercent != null && changePercent >= 0 ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%',
                                    style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              )
                            else
                              const Text('N/A', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickFilter(String value, String label) {
    final isActive = _changeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _changeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: isActive ? Colors.white : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filters', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Sector', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allSectors.map((sector) {
                      final isActive = _selectedSectors.contains(sector);
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            if (isActive) {
                              _selectedSectors.remove(sector);
                            } else {
                              _selectedSectors.add(sector);
                            }
                          });
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primary : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
                          ),
                          child: Text(sector, style: TextStyle(color: isActive ? Colors.white : AppColors.textSecondary, fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Sort By', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _sortChip('NAME', 'Name', setSheetState),
                      _sortChip('PRICE_HIGH', 'Price: High to Low', setSheetState),
                      _sortChip('PRICE_LOW', 'Price: Low to High', setSheetState),
                      _sortChip('CHANGE_HIGH', '% Change: High to Low', setSheetState),
                      _sortChip('CHANGE_LOW', '% Change: Low to High', setSheetState),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _sortChip(String value, String label, StateSetter setSheetState) {
    final isActive = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setSheetState(() => _sortBy = value);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(color: isActive ? Colors.white : AppColors.textSecondary, fontSize: 12)),
      ),
    );
  }
}