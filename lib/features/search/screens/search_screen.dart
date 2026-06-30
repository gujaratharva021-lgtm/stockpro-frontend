import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool selectMode;
  const SearchScreen({super.key, this.selectMode = false});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<dynamic> _results = [];
  List<dynamic> _allStocks = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAllStocks();
  }

  Future<void> _loadAllStocks() async {
    try {
      final stocks = await ApiService.getStocks();
      setState(() => _allStocks = stocks);
    } catch (_) {}
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  void _search(String query) {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _results = _allStocks.where((s) {
        final symbol = (s['symbol'] ?? '').toString().toLowerCase();
        final name = (s['company_name'] ?? '').toString().toLowerCase();
        return symbol.contains(lower) || name.contains(lower);
      }).toList();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        onChanged: _onChanged,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search stocks by name or symbol',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _results = []);
                            },
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _controller.text.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search, color: AppColors.textMuted, size: 48),
                    const SizedBox(height: 12),
                    const Text('Search for stocks', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('Try "AAPL" or "Reliance"', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              )
                  : _results.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off, color: AppColors.textMuted, size: 48),
                    const SizedBox(height: 12),
                    const Text('No stocks found', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
              )
                  : MediaQuery.of(context).size.width > 768
                  ? GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 3.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final stock = _results[index];
                        return GestureDetector(
                          onTap: () => widget.selectMode
                              ? Navigator.pop(context, stock)
                              : Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock))),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                            child: Row(children: [
                              Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                child: Center(child: Text((stock['symbol'] ?? '?').toString().substring(0, 1), style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)))),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(stock['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(stock['company_name'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis),
                              ])),
                              Text(stock['exchange'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ]),
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final stock = _results[index];
                  return GestureDetector(
                    onTap: () {
                      if (widget.selectMode) {
                        Navigator.pop(context, stock);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock)),
                        );
                      }
                    },
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
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                (stock['symbol'] ?? '?').toString().substring(0, 1),
                                style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stock['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(stock['company_name'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(stock['exchange'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
}