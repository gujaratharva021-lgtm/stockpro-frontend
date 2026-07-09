import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/advanced_chart_screen.dart';
import 'package:stock_app/features/stock_detail/screens/basket_service.dart';

class OptionChainScreen extends StatefulWidget {
  final Map<String, dynamic> stock;
  const OptionChainScreen({super.key, required this.stock});

  @override
  State<OptionChainScreen> createState() => _OptionChainScreenState();
}

class _OptionChainScreenState extends State<OptionChainScreen> {
  List<dynamic> _optionChain = [];
  bool _loading = false;
  String? _error;
  String _selectedExpiry = '2026-07-28';
  final List<String> _expiryOptions = ['2026-07-28', '2026-08-25', '2026-09-29'];
  Map<String, dynamic>? _quote;
  List<dynamic> _history = [];
  String _view = 'OI';
  String _changeMode = 'percent';
  String _greekMetric = 'iv';

  @override
  void initState() {
    super.initState();
    _loadQuote();
    _loadOptionChain();
    _loadHistory();
  }

  Future<void> _loadQuote() async {
    try {
      final quote = await ApiService.getQuote(widget.stock['symbol']);
      if (mounted) setState(() => _quote = quote);
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ApiService.getHistory(widget.stock['symbol']);
      if (mounted) setState(() => _history = history);
    } catch (_) {}
  }

  void _showAddToBasket() {
    final basketService = BasketService();
    final currentPrice = _quote != null ? (_quote!['price'] as num).toDouble() : 0.0;
    int qty = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Add to Basket', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(widget.stock['symbol'] + ' - ' + currentPrice.toStringAsFixed(2), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Qty: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  IconButton(onPressed: () { if (qty > 1) setS(() => qty--); }, icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary)),
                  Text(qty.toString(), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(onPressed: () => setS(() => qty++), icon: const Icon(Icons.add_circle_outline, color: AppColors.primary)),
                  const Spacer(),
                  Text((qty * currentPrice).toStringAsFixed(2), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              if (basketService.baskets.isEmpty) ...[
                const Text('No baskets yet. Create one from the stock screen first.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ] else ...[
                const Text('Select basket:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                ...basketService.baskets.map((b) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(b.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text(b.items.length.toString() + ' stocks - ' + b.totalValue.toStringAsFixed(0), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: ElevatedButton(
                    onPressed: () {
                      basketService.addToBasket(b.id, BasketItem(
                        stockId: widget.stock['id'] ?? '',
                        symbol: widget.stock['symbol'] ?? '',
                        companyName: widget.stock['company_name'] ?? '',
                        quantity: qty,
                        price: currentPrice,
                      ));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ' + b.name)));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadOptionChain() async {
    setState(() { _loading = true; _error = null; });
    try {
      final chain = await ApiService.getOptionChain(widget.stock['symbol'], _selectedExpiry);
      setState(() => _optionChain = chain);
    } catch (e) {
      setState(() => _error = 'Option chain unavailable right now');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _expiryLabel(String expiry) {
    try {
      final date = DateTime.parse(expiry);
      final now = DateTime.now();
      final days = date.difference(now).inDays;
      final dd = DateFormat('d MMM').format(date);
      if (days <= 0) return dd;
      if (days < 45) {
        final weeks = (days / 7).round();
        final weekLabel = weeks <= 1 ? '1 Week' : weeks.toString() + ' Weeks';
        return dd + ' (' + weekLabel + ')';
      }
      final months = (days / 30).round();
      final monthLabel = months <= 1 ? '1 Month' : months.toString() + ' Months';
      return dd + ' (' + monthLabel + ')';
    } catch (_) {
      return expiry;
    }
  }

  double? _changePct(Map<String, dynamic>? opt) {
    if (opt == null) return null;
    final ltp = (opt['ltp'] as num?)?.toDouble();
    final close = (opt['close_price'] as num?)?.toDouble();
    if (ltp == null || close == null || close == 0) return null;
    return ((ltp - close) / close) * 100;
  }

  double? _changeAbs(Map<String, dynamic>? opt) {
    if (opt == null) return null;
    final ltp = (opt['ltp'] as num?)?.toDouble();
    final close = (opt['close_price'] as num?)?.toDouble();
    if (ltp == null || close == null) return null;
    return ltp - close;
  }

  String _formatChange(double value) {
    final sign = value >= 0 ? '+' : '';
    if (_changeMode == 'absolute') {
      return sign + value.toStringAsFixed(2);
    }
    return sign + value.toStringAsFixed(2) + '%';
  }

  String _greekLabel(String key) {
    switch (key) {
      case 'iv': return 'IV';
      case 'delta': return 'Delta';
      case 'theta': return 'Theta';
      case 'vega': return 'Vega';
      case 'gamma': return 'Gamma';
    }
    return key;
  }

  double? get _pcr {
    if (_optionChain.isEmpty) return null;
    double callOi = 0;
    double putOi = 0;
    for (final row in _optionChain) {
      final call = row['call_option'];
      final put = row['put_option'];
      callOi += ((call?['oi'] as num?) ?? 0).toDouble();
      putOi += ((put?['oi'] as num?) ?? 0).toDouble();
    }
    if (callOi == 0) return null;
    return putOi / callOi;
  }

  double? get _maxPain {
    if (_optionChain.isEmpty) return null;
    double? best;
    double bestLoss = double.infinity;
    for (final row in _optionChain) {
      final strike = (row['strike_price'] as num?)?.toDouble();
      if (strike == null) continue;
      double loss = 0;
      for (final r in _optionChain) {
        final s = (r['strike_price'] as num?)?.toDouble();
        if (s == null) continue;
        final callOi = ((r['call_option']?['oi'] as num?) ?? 0).toDouble();
        final putOi = ((r['put_option']?['oi'] as num?) ?? 0).toDouble();
        if (strike > s) loss += (strike - s) * callOi;
        if (strike < s) loss += (s - strike) * putOi;
      }
      if (loss < bestLoss) {
        bestLoss = loss;
        best = strike;
      }
    }
    return best;
  }

  double? get _atmIv {
    if (_optionChain.isEmpty) return null;
    final spot = (_optionChain.first['underlying_spot_price'] as num?)?.toDouble();
    if (spot == null) return null;
    Map<String, dynamic>? closest;
    double bestDiff = double.infinity;
    for (final row in _optionChain) {
      final strike = (row['strike_price'] as num?)?.toDouble();
      if (strike == null) continue;
      final diff = (strike - spot).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        closest = row;
      }
    }
    if (closest == null) return null;
    final callIv = (closest['call_option']?['greeks']?['iv'] as num?)?.toDouble();
    final putIv = (closest['put_option']?['greeks']?['iv'] as num?)?.toDouble();
    if (callIv != null && putIv != null) return (callIv + putIv) / 2;
    return callIv ?? putIv;
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _viewToggle(String label) {
    final selected = _view == label;
    return GestureDetector(
      onTap: () => setState(() => _view = label),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textMuted, fontWeight: selected ? FontWeight.bold : FontWeight.w500, fontSize: 15)),
            const SizedBox(height: 4),
            Container(height: 2, width: 28, color: selected ? AppColors.primary : Colors.transparent),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = _quote != null ? (_quote!['price'] as num?)?.toDouble() : null;
    final changePercent = _quote != null ? (_quote!['change_percent'] as num?)?.toDouble() : null;
    final isUp = (changePercent ?? 0) >= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 12, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                  _viewToggle('OI'),
                  _viewToggle('Greeks'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.textPrimary, size: 22),
                    onPressed: _showAddToBasket,
                  ),
                  IconButton(
                    icon: const Icon(Icons.bar_chart, color: AppColors.primary, size: 22),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AdvancedChartScreen(
                        symbol: widget.stock['symbol'] ?? '',
                        companyName: widget.stock['company_name'] ?? '',
                        history: _history,
                        currentPrice: price,
                        changePercent: changePercent,
                      )));
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textPrimary, size: 22),
                    onSelected: (value) => setState(() => _changeMode = value),
                    itemBuilder: (ctx) => [
                      CheckedPopupMenuItem(value: 'absolute', checked: _changeMode == 'absolute', child: const Text('Absolute change')),
                      CheckedPopupMenuItem(value: 'percent', checked: _changeMode == 'percent', child: const Text('Percentage change')),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                    const SizedBox(width: 10),
                    Text(widget.stock['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    if (price != null) ...[
                      Text(price.toStringAsFixed(2), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 6),
                      Text((isUp ? '+' : '') + (changePercent?.toStringAsFixed(2) ?? '0.00') + '%', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _expiryOptions.map((exp) {
                    final selected = exp == _selectedExpiry;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_expiryLabel(exp)),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _selectedExpiry = exp);
                          _loadOptionChain();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (_view == 'Greeks')
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['iv', 'delta', 'theta', 'vega', 'gamma'].map((k) {
                      final selected = _greekMetric == k;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_greekLabel(k)),
                          selected: selected,
                          onSelected: (_) => setState(() => _greekMetric = k),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(child: Text(_view == 'OI' ? 'Call LTP' : 'Call ' + _greekLabel(_greekMetric), style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 70, child: Text('Strike', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                  Expanded(child: Text(_view == 'OI' ? 'Put LTP' : 'Put ' + _greekLabel(_greekMetric), textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 12),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))))
            else if (_optionChain.isEmpty)
              const Expanded(child: Center(child: Text('No option chain data available', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _optionChain.length,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (context, index) {
                    final row = _optionChain[index];
                    final call = row['call_option'];
                    final put = row['put_option'];
                    final strike = row['strike_price'];
                    final atm = price != null && strike != null && ((strike as num).toDouble() - price).abs() < 2.5;
                    final callChange = _changeMode == 'absolute' ? _changeAbs(call) : _changePct(call);
                    final putChange = _changeMode == 'absolute' ? _changeAbs(put) : _changePct(put);
                    final callGreekVal = call?['greeks']?[_greekMetric];
                    final putGreekVal = put?['greeks']?[_greekMetric];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _view == 'OI'
                                  ? [
                                      Text((call?['ltp'] ?? '-').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      if (callChange != null)
                                        Text(_formatChange(callChange), style: TextStyle(fontSize: 11, color: callChange >= 0 ? AppColors.success : AppColors.danger)),
                                      Text('OI: ' + (call?['oi'] ?? '-').toString(), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ]
                                  : [
                                      Text((callGreekVal ?? '-').toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    ],
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: atm ? AppColors.textPrimary : AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(strike.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: atm ? Colors.white : AppColors.textPrimary)),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: _view == 'OI'
                                  ? [
                                      Text((put?['ltp'] ?? '-').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      if (putChange != null)
                                        Text(_formatChange(putChange), style: TextStyle(fontSize: 11, color: putChange >= 0 ? AppColors.success : AppColors.danger)),
                                      Text('OI: ' + (put?['oi'] ?? '-').toString(), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ]
                                  : [
                                      Text((putGreekVal ?? '-').toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (_optionChain.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    _statBox('PCR', _pcr != null ? _pcr!.toStringAsFixed(2) : '-'),
                    _statBox('Max Pain', _maxPain != null ? _maxPain!.toStringAsFixed(0) : '-'),
                    _statBox('ATM IV', _atmIv != null ? _atmIv!.toStringAsFixed(2) : '-'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}