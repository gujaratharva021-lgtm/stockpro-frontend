import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';
import 'package:stock_app/shared/widgets/stock_logo.dart';
import 'package:stock_app/shared/widgets/app_card.dart';
import 'package:stock_app/shared/widgets/empty_state.dart';
import 'package:stock_app/shared/widgets/price_change.dart';

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
  final Map<String, Map<String, dynamic>> _quotes = {};

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
    _loadQuotesForVisibleResults();
  }

  // Fetches LTP/change for whatever's currently on screen. Capped so a
  // broad query (e.g. a single letter) can't fan out into dozens of quote
  // requests -- only the results a user could actually see get fetched.
  Future<void> _loadQuotesForVisibleResults() async {
    final visible = _results.take(25);
    for (final s in visible) {
      final symbol = s['symbol'];
      if (symbol == null || _quotes.containsKey(symbol)) continue;
      try {
        final quote = await ApiService.getQuote(symbol);
        if (mounted) setState(() => _quotes[symbol] = quote);
      } catch (_) {}
    }
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
                  ? const EmptyState(
                      icon: Icons.search,
                      message: 'Search for stocks\nTry "AAPL" or "Reliance"',
                    )
                  : _results.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      message: 'No stocks found',
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
                        final symbol = stock['symbol']?.toString();
                        final quote = _quotes[symbol];
                        final price = quote != null ? (quote['price'] as num?)?.toDouble() : null;
                        final changePercent = quote != null ? (quote['change_percent'] as num?)?.toDouble() : null;
                        return GestureDetector(
                          onTap: () => widget.selectMode
                              ? Navigator.pop(context, stock)
                              : Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock))),
                          child: AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              StockLogo(symbol: stock['symbol']?.toString(), companyName: stock['company_name']?.toString(), size: 36),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(stock['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(stock['company_name'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis),
                              ])),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(stock['exchange'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                  if (price != null) Text(price.toStringAsFixed(2), style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                                  if (changePercent != null) PriceChange(change: changePercent, changePercent: changePercent, fontSize: 9.5, showParens: false),
                                ],
                              ),
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
                  final symbol = stock['symbol']?.toString();
                  final quote = _quotes[symbol];
                  final price = quote != null ? (quote['price'] as num?)?.toDouble() : null;
                  final changePercent = quote != null ? (quote['change_percent'] as num?)?.toDouble() : null;
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
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            StockLogo(symbol: stock['symbol']?.toString(), companyName: stock['company_name']?.toString(), size: 40),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(stock['exchange'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                if (price != null) ...[
                                  const SizedBox(height: 2),
                                  Text(price.toStringAsFixed(2), style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                                if (changePercent != null)
                                  PriceChange(change: changePercent, changePercent: changePercent, fontSize: 10.5, showParens: false),
                              ],
                            ),
                          ],
                        ),
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