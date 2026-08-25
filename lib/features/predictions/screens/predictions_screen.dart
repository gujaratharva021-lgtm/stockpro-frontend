import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/shared/widgets/account_drawer.dart';

/// Predictions tab. No prediction backend exists yet, so every number on
/// this screen is illustrative placeholder data (clearly labelled as a
/// preview) rather than fabricated real market data. Structure/UX modeled
/// as an India-first prediction markets experience: categories grid,
/// category filter chips, and "Trending"/category rails of market cards
/// with multi-contract Yes/No rows, matching the reference layout.
///
/// Search is functional against this placeholder dataset: it matches on
/// market title, category label, and contract name.
class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionCategory {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  _PredictionCategory(this.label, this.icon, this.gradient);
}

class _PredictionContract {
  final String name;
  final int yesPct;
  final int noPct;
  const _PredictionContract(this.name, this.yesPct, this.noPct);
}

class _PredictionMarket {
  final String title;
  final String category;
  final String closesLabel;
  final String volumeLabel;
  final String moreCount;
  final List<_PredictionContract> contracts;
  const _PredictionMarket({
    required this.title,
    required this.category,
    required this.closesLabel,
    required this.volumeLabel,
    required this.moreCount,
    required this.contracts,
  });
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String? _selectedCategory;

  late final List<_PredictionCategory> _categories = [
    _PredictionCategory('Elections', Icons.how_to_vote_outlined, [AppColors.primary, AppColors.primaryDark]),
    _PredictionCategory('Financial Markets', Icons.show_chart, [AppColors.success, const Color(0xFF0B6B47)]),
    _PredictionCategory('Cricket & Sports', Icons.sports_cricket_outlined, [AppColors.warning, const Color(0xFF8A5A12)]),
    _PredictionCategory('Economic Indicators', Icons.bar_chart_rounded, [const Color(0xFF7C5CFF), const Color(0xFF3E2E99)]),
    _PredictionCategory('Government Policy', Icons.account_balance_outlined, [const Color(0xFF4C8DFF), const Color(0xFF1E3F73)]),
    _PredictionCategory('Weather & Monsoon', Icons.water_drop_outlined, [const Color(0xFF2FB8C6), const Color(0xFF105B63)]),
  ];

  // Single source of truth for every placeholder market. Trending and
  // per-category rails, plus search, all read from this list so nothing
  // has to be duplicated or kept in sync by hand.
  late final List<_PredictionMarket> _allMarkets = [
    const _PredictionMarket(
      title: '2026 State Assembly Elections: Majority Alliance',
      category: 'Elections',
      closesLabel: 'Closes Mar 2026',
      volumeLabel: '18.4K traders',
      moreCount: 'See 12 more contracts',
      contracts: [
        _PredictionContract('NDA-led Alliance Majority', 54, 46),
        _PredictionContract('INDIA Bloc Majority', 41, 59),
      ],
    ),
    const _PredictionMarket(
      title: 'RBI Monetary Policy — December 2026',
      category: 'Economic Indicators',
      closesLabel: 'Closes Dec 2026',
      volumeLabel: '12.1K traders',
      moreCount: 'See 4 more contracts',
      contracts: [
        _PredictionContract('Repo Rate Cut (25 bps)', 38, 62),
        _PredictionContract('Repo Rate Held Steady', 55, 45),
      ],
    ),
    const _PredictionMarket(
      title: 'India vs Australia Test Series 2026-27',
      category: 'Cricket & Sports',
      closesLabel: 'Closes Jan 2027',
      volumeLabel: '31.6K traders',
      moreCount: 'See 8 more contracts',
      contracts: [
        _PredictionContract('India Wins Series', 62, 38),
        _PredictionContract('Series Drawn 2-2', 14, 86),
      ],
    ),
    const _PredictionMarket(
      title: 'Nifty 50 Year-End Level',
      category: 'Financial Markets',
      closesLabel: 'Closes Dec 2026',
      volumeLabel: '9.8K traders',
      moreCount: 'See 6 more contracts',
      contracts: [
        _PredictionContract('Closes Above 26,000', 47, 53),
        _PredictionContract('Closes Above 27,000', 22, 78),
      ],
    ),
    const _PredictionMarket(
      title: 'Parliament Winter Session: Key Bill Passage',
      category: 'Government Policy',
      closesLabel: 'Closes Dec 2026',
      volumeLabel: '3.9K traders',
      moreCount: 'See 3 more contracts',
      contracts: [
        _PredictionContract('Bill Passed This Session', 58, 42),
        _PredictionContract('Referred to Select Committee', 27, 73),
      ],
    ),
    const _PredictionMarket(
      title: 'Monsoon 2026 Rainfall (IMD)',
      category: 'Weather & Monsoon',
      closesLabel: 'Closes Sep 2026',
      volumeLabel: '4.2K traders',
      moreCount: 'See 2 more contracts',
      contracts: [
        _PredictionContract('Above Normal Rainfall', 44, 56),
        _PredictionContract('Below Normal Rainfall', 18, 82),
      ],
    ),
  ];

  // Trending rail shows the first four markets, in this fixed order.
  List<_PredictionMarket> get _trending => _allMarkets.take(4).toList();

  Map<String, List<_PredictionMarket>> get _byCategory {
    final map = <String, List<_PredictionMarket>>{};
    for (final c in _categories) {
      map[c.label] = _allMarkets.where((m) => m.category == c.label).toList();
    }
    return map;
  }

  List<_PredictionMarket> _filteredMarkets(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _allMarkets.where((market) {
      if (market.title.toLowerCase().contains(q)) return true;
      if (market.category.toLowerCase().contains(q)) return true;
      for (final contract in market.contracts) {
        if (contract.name.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      if (value.trim().isNotEmpty) _selectedCategory = null;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    _searchFocusNode.unfocus();
  }

  void _focusSearch() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    FocusScope.of(context).requestFocus(_searchFocusNode);
  }

  void _selectCategory(String label) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchQuery = '';
      _selectedCategory = label;
    });
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _clearCategory() {
    setState(() => _selectedCategory = null);
  }

  void _showPreviewNotice() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Live India prediction markets are launching soon — this is a preview of the experience.',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.cardBackground,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _byCategory;
    final isSearching = _searchQuery.trim().isNotEmpty;
    final isCategoryView = !isSearching && _selectedCategory != null;
    final results = isSearching
        ? _filteredMarkets(_searchQuery)
        : isCategoryView
            ? (grouped[_selectedCategory] ?? const <_PredictionMarket>[])
            : const <_PredictionMarket>[];

    return MainShell(
      currentIndex: 1,
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: const AccountDrawer(),
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(icon: const Icon(Icons.menu, color: AppColors.textPrimary), onPressed: () => Scaffold.of(ctx).openDrawer()),
          ),
          title: const Text('Prediction Markets', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: _showPreviewNotice,
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _previewBanner(),
              _searchBar(),
              if (isSearching) ...[
                const SizedBox(height: 16),
                _searchResultsSection(results),
              ] else if (isCategoryView) ...[
                const SizedBox(height: 16),
                _categoryResultsSection(_selectedCategory!, results),
              ] else ...[
                const SizedBox(height: 20),
                _sectionHeader('Explore Categories'),
                const SizedBox(height: 12),
                _categoriesGrid(),
                const SizedBox(height: 24),
                _categoryChipsRow(),
                const SizedBox(height: 24),
                _sectionHeader('Trending'),
                const SizedBox(height: 12),
                _marketRail(_trending),
                const SizedBox(height: 28),
                for (final category in _categories) ...[
                  _sectionHeader(category.label),
                  const SizedBox(height: 12),
                  _marketRail(grouped[category.label] ?? const []),
                  const SizedBox(height: 28),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Preview — India markets launching soon. Prices shown are illustrative, not live data.',
              style: TextStyle(color: AppColors.warning.withValues(alpha: 0.95), fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search by market or contract name',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _clearSearch,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, color: AppColors.textMuted, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  Widget _searchResultsSection(List<_PredictionMarket> results) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            results.isEmpty
                ? 'No markets found for "${_searchQuery.trim()}"'
                : '${results.length} result${results.length == 1 ? '' : 's'} for "${_searchQuery.trim()}"',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Try a different market, category, or contract name.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            for (final market in results) ...[
              _marketCard(market, width: double.infinity, fixedHeight: false),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _categoryResultsSection(String categoryLabel, List<_PredictionMarket> results) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _clearCategory,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                ),
              ),
              Expanded(
                child: Text(
                  categoryLabel,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            results.isEmpty ? 'No markets in this category yet.' : '${results.length} market${results.length == 1 ? '' : 's'}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('More markets coming soon.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            )
          else
            for (final market in results) ...[
              _marketCard(market, width: double.infinity, fixedHeight: false),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _categoriesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
        ),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _selectCategory(category.label),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: category.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(category.icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _categoryChipsRow() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(icon: Icons.search, label: null, onTap: _focusSearch, highlighted: true),
          const SizedBox(width: 10),
          for (final category in _categories) ...[
            _chip(icon: category.icon, label: category.label, onTap: () => _selectCategory(category.label)),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _chip({required IconData icon, String? label, required VoidCallback onTap, bool highlighted = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: label == null ? 12 : 14, vertical: 10),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: highlighted ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: highlighted ? AppColors.primary : AppColors.textSecondary),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: highlighted ? AppColors.primary : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _marketRail(List<_PredictionMarket> markets) {
    if (markets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('More markets coming soon.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }
    return SizedBox(
      height: 268,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: markets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _marketCard(markets[index]),
      ),
    );
  }

  // `fixedHeight: true` is used inside the horizontal rail, where the
  // parent SizedBox gives the card a tight height and the content must be
  // squeezed to fit exactly (Expanded + Spacer, like the original design).
  // `fixedHeight: false` is used in the vertical search-results list, where
  // there is no bounded height from the parent, so the card must size
  // itself naturally instead (Expanded/Spacer would throw there).
  Widget _marketCard(_PredictionMarket market, {double width = 290, bool fixedHeight = true}) {
    final category = _categories.firstWhere((c) => c.label == market.category, orElse: () => _categories.first);
    final header = Container(
      height: 92,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: category.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          Positioned(right: -6, top: -6, child: Icon(category.icon, color: Colors.white.withValues(alpha: 0.18), size: 64)),
          Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              market.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.2),
            ),
          ),
        ],
      ),
    );

    final footer = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(market.moreCount, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(market.volumeLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );

    final contractRows = [for (final contract in market.contracts) _contractRow(contract, market.closesLabel)];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _showPreviewNotice,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: fixedHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            header,
            if (fixedHeight)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...contractRows,
                      const Spacer(),
                      const Divider(color: AppColors.border, height: 1),
                      footer,
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...contractRows,
                    const Divider(color: AppColors.border, height: 16),
                    footer,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contractRow(_PredictionContract contract, String closesLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contract.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(closesLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _pctPill('Yes', contract.yesPct, AppColors.success),
              const SizedBox(height: 4),
              _pctPill('No', contract.noPct, AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pctPill(String label, int pct, Color color) {
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          Text('$pct%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
