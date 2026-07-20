import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:candlesticks/candlesticks.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/constants/nifty_symbols.dart';

class TechnicalsScreen extends StatefulWidget {
  final Map<String, dynamic> stock;
  const TechnicalsScreen({super.key, required this.stock});

  @override
  State<TechnicalsScreen> createState() => _TechnicalsScreenState();
}

class _TechEvent {
  final String name;
  final DateTime time;
  _TechEvent(this.name, this.time);
}

// Curated set of real, prominent NSE-listed companies used for the Markets
// tab (heatmap / movers / breakouts). Computing this for all 1500+ catalog
// stocks would require too many live-quote calls to be practical client-side,
// so we scope it to well-known large caps across major sectors - all real
// symbols from the catalog, not fabricated.


class _TechnicalsScreenState extends State<TechnicalsScreen> with SingleTickerProviderStateMixin {
  late TabController _mainTab;

  final List<Map<String, String>> _intervals = [
    {'key': '5m', 'label': '5min'},
    {'key': '10m', 'label': '10min'},
    {'key': '15m', 'label': '15min'},
    {'key': '30m', 'label': '30min'},
    {'key': '1h', 'label': '1 Hour'},
    {'key': 'day', 'label': 'day'},
  ];
  String _selectedInterval = '1h';

  bool _loading = true;
  String? _error;
  List<Candle> _candles = [];
  List<Map<String, dynamic>> _raw = [];
  Map<String, dynamic>? _quote;

  // ---- Markets tab state ----
  bool _marketsLoading = true;
  Map<String, dynamic>? _nifty;
  List<dynamic> _marketStocks = [];
  final Map<String, Map<String, dynamic>> _marketQuotes = {};
  final Map<String, List<dynamic>> _marketHistory = {};
  int _moversTab = 0; // 0 = Gainers, 1 = Losers
  int _breakoutTab = 0; // 0 = Volume Breakout, 1 = Opening Range Breakdown

  @override
  void initState() {
    super.initState();
    _mainTab = TabController(length: 2, vsync: this);
    _loadQuote();
    _load();
    _loadMarkets();
  }

  @override
  void dispose() {
    _mainTab.dispose();
    super.dispose();
  }

  Future<void> _loadQuote() async {
    try {
      final q = await ApiService.getQuote(widget.stock['symbol']);
      if (mounted) setState(() => _quote = q);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      List<dynamic> points;
      if (_selectedInterval == 'day') {
        points = await ApiService.getHistory(widget.stock['symbol']);
      } else {
        points = await ApiService.getIntraday(widget.stock['symbol'], _selectedInterval);
      }

      final raw = <Map<String, dynamic>>[];
      for (final p in points) {
        final open = (p['open'] as num?)?.toDouble();
        final high = (p['high'] as num?)?.toDouble();
        final low = (p['low'] as num?)?.toDouble();
        final close = (p['close'] as num?)?.toDouble();
        if (open == null || high == null || low == null || close == null) continue;
        DateTime dt;
        if (p['date'] != null) {
          dt = DateTime.parse(p['date'].toString());
        } else if (p['timestamp'] != null) {
          dt = DateTime.fromMillisecondsSinceEpoch(((p['timestamp'] as num).toInt()) * 1000);
        } else {
          continue;
        }
        raw.add({'date': dt, 'open': open, 'high': high, 'low': low, 'close': close, 'volume': (p['volume'] as num?)?.toDouble() ?? 0});
      }

      final rawSorted = List<Map<String, dynamic>>.from(raw)..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      final candles = rawSorted.reversed.map((r) => Candle(
        date: r['date'] as DateTime,
        open: r['open'] as double,
        high: r['high'] as double,
        low: r['low'] as double,
        close: r['close'] as double,
        volume: r['volume'] as double,
      )).toList();

      if (mounted) {
        setState(() {
          _raw = rawSorted;
          _candles = candles;
        });
      }
    } catch (e) {
      setState(() => _error = 'Could not load chart data');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMarkets() async {
    setState(() => _marketsLoading = true);
    try {
      // Real NIFTY 50 index value, fetched directly (same approach already
      // used elsewhere in this app's Markets screen).
      try {
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)));
        final res = await dio.get('https://query1.finance.yahoo.com/v8/finance/chart/%5ENSEI?interval=15m&range=1d');
        final result = res.data['chart']['result'][0];
        final meta = result['meta'];
        final price = (meta['regularMarketPrice'] as num).toDouble();
        final prevClose = (meta['previousClose'] as num? ?? meta['chartPreviousClose'] as num).toDouble();
        final percent = prevClose > 0 ? ((price - prevClose) / prevClose) * 100 : 0.0;
        if (mounted) {
          setState(() => _nifty = {'value': price, 'change': price - prevClose, 'percent': percent});
        }
      } catch (_) {}

      final allStocks = await ApiService.getStocks();
      final selected = allStocks.where((s) => kNiftyWatchSymbols.contains(s['symbol'])).toList();
      if (mounted) setState(() => _marketStocks = selected);

      const batchSize = 12;
      for (var i = 0; i < selected.length; i += batchSize) {
        final batch = selected.sublist(i, i + batchSize > selected.length ? selected.length : i + batchSize);
        await Future.wait(batch.map((s) async {
          final symbol = s['symbol'];
          try {
            final q = await ApiService.getQuote(symbol);
            if (mounted) setState(() => _marketQuotes[symbol] = q);
          } catch (_) {}
          try {
            final h = await ApiService.getHistory(symbol);
            if (mounted) setState(() => _marketHistory[symbol] = h);
          } catch (_) {}
        }));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _marketsLoading = false);
    }
  }

  // ---- Per-stock indicators (real, computed) ----

  double? _rsi14() {
    final closes = _raw.map((r) => r['close'] as double).toList();
    if (closes.length < 15) return null;
    double gainSum = 0, lossSum = 0;
    for (int i = closes.length - 14; i < closes.length; i++) {
      final diff = closes[i] - closes[i - 1];
      if (diff > 0) {
        gainSum += diff;
      } else {
        lossSum += -diff;
      }
    }
    final avgGain = gainSum / 14;
    final avgLoss = lossSum / 14;
    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  String _rsiLabel(double rsi) {
    if (rsi >= 70) return 'Overbought';
    if (rsi <= 30) return 'Oversold';
    return 'Neutral';
  }

  double? _sma(List<double> closes, int period) {
    if (closes.length < period) return null;
    final slice = closes.sublist(closes.length - period);
    return slice.reduce((a, b) => a + b) / period;
  }

  String _crossoverSignal(int shortP, int longP) {
    final closes = _raw.map((r) => r['close'] as double).toList();
    final shortSma = _sma(closes, shortP);
    final longSma = _sma(closes, longP);
    if (shortSma == null || longSma == null) return '-----';
    return shortSma >= longSma ? 'Bullish' : 'Bearish';
  }

  List<_TechEvent> _detectEvents() {
    final events = <_TechEvent>[];
    if (_raw.length < 6) return events;

    for (int i = 1; i < _raw.length; i++) {
      final o = _raw[i]['open'] as double;
      final c = _raw[i]['close'] as double;
      final h = _raw[i]['high'] as double;
      final l = _raw[i]['low'] as double;
      final range = h - l;
      if (range <= 0) continue;
      final body = (c - o).abs();
      final upperShadow = h - (o > c ? o : c);
      final lowerShadow = (o < c ? o : c) - l;
      if (body / range < 0.3 && upperShadow > body && lowerShadow > body) {
        events.add(_TechEvent(c >= o ? 'Spinning Top Green' : 'Spinning Top Red', _raw[i]['date'] as DateTime));
      }
    }

    for (int i = 6; i < _raw.length; i++) {
      final h = _raw[i]['high'] as double;
      final l = _raw[i]['low'] as double;
      final range = h - l;
      double avgRange = 0;
      for (int j = i - 6; j < i; j++) {
        avgRange += (_raw[j]['high'] as double) - (_raw[j]['low'] as double);
      }
      avgRange /= 6;
      if (avgRange > 0 && range > avgRange * 1.6) {
        events.add(_TechEvent('Volatility Expansion', _raw[i]['date'] as DateTime));
      }
    }

    double haOpenPrev = ((_raw[0]['open'] as double) + (_raw[0]['close'] as double)) / 2;
    double haClosePrev = ((_raw[0]['open'] as double) + (_raw[0]['high'] as double) + (_raw[0]['low'] as double) + (_raw[0]['close'] as double)) / 4;
    bool prevBullish = haClosePrev >= haOpenPrev;
    for (int i = 1; i < _raw.length; i++) {
      final o = _raw[i]['open'] as double;
      final h = _raw[i]['high'] as double;
      final l = _raw[i]['low'] as double;
      final c = _raw[i]['close'] as double;
      final haClose = (o + h + l + c) / 4;
      final haOpen = (haOpenPrev + haClosePrev) / 2;
      final haLow = [l, haOpen, haClose].reduce((a, b) => a < b ? a : b);
      final isBearish = haClose < haOpen;
      final noLowerWick = (haOpen - haLow).abs() < (haOpen * 0.0005);
      if (prevBullish && isBearish && noLowerWick) {
        events.add(_TechEvent('Heikin Ashi Bearish Reversal', _raw[i]['date'] as DateTime));
      }
      prevBullish = haClose >= haOpen;
      haOpenPrev = haOpen;
      haClosePrev = haClose;
    }

    events.sort((a, b) => b.time.compareTo(a.time));
    return events.take(10).toList();
  }

  String _formatEventTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'pm' : 'am';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // ---- Markets tab computations (real, from live quotes / history) ----

  double _changePctOf(String symbol) {
    final q = _marketQuotes[symbol];
    return q != null ? (q['change_percent'] as num?)?.toDouble() ?? 0 : 0;
  }

  List<dynamic> get _sortedGainers {
    final list = List<dynamic>.from(_marketStocks);
    list.sort((a, b) => _changePctOf(b['symbol']).compareTo(_changePctOf(a['symbol'])));
    return list.take(5).toList();
  }

  List<dynamic> get _sortedLosers {
    final list = List<dynamic>.from(_marketStocks);
    list.sort((a, b) => _changePctOf(a['symbol']).compareTo(_changePctOf(b['symbol'])));
    return list.take(5).toList();
  }

  // Volume Breakout: today's volume vs the average of the previous 5 sessions.
  List<Map<String, dynamic>> get _volumeBreakouts {
    final out = <Map<String, dynamic>>[];
    for (final s in _marketStocks) {
      final symbol = s['symbol'];
      final hist = _marketHistory[symbol];
      if (hist == null || hist.length < 6) continue;
      final today = (hist.last['volume'] as num?)?.toDouble() ?? 0;
      final prev = hist.sublist(hist.length - 6, hist.length - 1);
      final avg = prev.map((h) => (h['volume'] as num?)?.toDouble() ?? 0).reduce((a, b) => a + b) / prev.length;
      if (avg > 0 && today > avg * 1.5) {
        out.add({'symbol': symbol, 'ratio': today / avg, 'change': _changePctOf(symbol)});
      }
    }
    out.sort((a, b) => (b['ratio'] as double).compareTo(a['ratio'] as double));
    return out.take(5).toList();
  }

  // Opening Range Breakdown: current price trading below today's open.
  List<Map<String, dynamic>> get _openingRangeBreakdowns {
    final out = <Map<String, dynamic>>[];
    for (final s in _marketStocks) {
      final symbol = s['symbol'];
      final hist = _marketHistory[symbol];
      final q = _marketQuotes[symbol];
      if (hist == null || hist.isEmpty || q == null) continue;
      final open = (hist.last['open'] as num?)?.toDouble();
      final price = (q['price'] as num?)?.toDouble();
      if (open == null || price == null || open == 0) continue;
      final diffPct = ((price - open) / open) * 100;
      if (diffPct < -0.3) {
        out.add({'symbol': symbol, 'change': diffPct});
      }
    }
    out.sort((a, b) => (a['change'] as double).compareTo(b['change'] as double));
    return out.take(5).toList();
  }

  Map<String, List<dynamic>> get _sectorGroups {
    final map = <String, List<dynamic>>{};
    for (final s in _marketStocks) {
      final sector = (s['sector'] ?? 'Other').toString();
      map.putIfAbsent(sector, () => []).add(s);
    }
    return map;
  }

  Widget _statRow(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.6))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTechnicalsTab() {
    final rsi = _rsi14();
    final events = _loading ? <_TechEvent>[] : _detectEvents();
    return ListView(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _intervals.map((iv) {
                final selected = _selectedInterval == iv['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(iv['label']!),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedInterval = iv['key']!);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _statRow('Short Term (5 & 20 SMA CrossOver)', _loading ? '-----' : _crossoverSignal(5, 20),
            valueColor: _loading ? null : (_crossoverSignal(5, 20) == 'Bullish' ? AppColors.success : (_crossoverSignal(5, 20) == 'Bearish' ? AppColors.danger : null))),
        _statRow('Long Term (50 & 200 SMA CrossOver)', _loading ? '-----' : _crossoverSignal(50, 200),
            valueColor: _loading ? null : (_crossoverSignal(50, 200) == 'Bullish' ? AppColors.success : (_crossoverSignal(50, 200) == 'Bearish' ? AppColors.danger : null))),
        _statRow('RSI (14)', rsi == null ? '-----' : '${rsi.toStringAsFixed(0)} - ${_rsiLabel(rsi)}'),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Technical Events', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
        else if (_error != null)
          Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))))
        else if (_candles.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No chart data available', style: TextStyle(color: AppColors.textSecondary))))
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 320,
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Candlesticks(candles: _candles),
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (!_loading && events.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('No technical events detected in this range', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          )
        else
          ...events.map((e) => _statRow(e.name, _formatEventTime(e.time))),
        const SizedBox(height: 24),
      ],
    );
  }

  Color _heatColor(double pct) {
    if (pct >= 2) return const Color(0xFF0F7B3F);
    if (pct >= 0.5) return const Color(0xFF3FA65C);
    if (pct >= 0) return const Color(0xFF8FCB9C);
    if (pct >= -0.5) return const Color(0xFFF3A6A0);
    if (pct >= -2) return const Color(0xFFD9564E);
    return const Color(0xFF9B1C13);
  }

  Widget _heatTile(dynamic s) {
    final symbol = s['symbol'];
    final pct = _changePctOf(symbol);
    return Container(
      width: 100,
      height: 70,
      margin: const EdgeInsets.all(2),
      color: _heatColor(pct),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%', style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMarketsTab() {
    if (_marketsLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final niftyVal = _nifty;
    final niftyIsUp = niftyVal != null && (niftyVal['change'] as double) >= 0;
    final sectors = _sectorGroups;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        if (niftyVal != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('NIFTY 50', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Text((niftyVal['value'] as double).toStringAsFixed(2), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    Text('${niftyIsUp ? '+' : ''}${(niftyVal['change'] as double).toStringAsFixed(2)} (${(niftyVal['percent'] as double).toStringAsFixed(2)}%)',
                        style: TextStyle(color: niftyIsUp ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        ...sectors.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(children: entry.value.map((s) => _heatTile(s)).toList()),
                  const SizedBox(height: 10),
                ],
              ),
            )),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Top Movers', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _moversTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _moversTab == 0 ? AppColors.primary : AppColors.border, width: 2))),
                    alignment: Alignment.center,
                    child: Text('Gainers', style: TextStyle(color: _moversTab == 0 ? AppColors.primary : AppColors.textMuted, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _moversTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _moversTab == 1 ? AppColors.primary : AppColors.border, width: 2))),
                    alignment: Alignment.center,
                    child: Text('Losers', style: TextStyle(color: _moversTab == 1 ? AppColors.primary : AppColors.textMuted, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...(_moversTab == 0 ? _sortedGainers : _sortedLosers).map((s) {
          final symbol = s['symbol'];
          final q = _marketQuotes[symbol];
          final price = q != null ? (q['price'] as num?)?.toDouble() : null;
          final pct = _changePctOf(symbol);
          final isUp = pct >= 0;
          return _statRow('$symbol\nNSE'.split('\n')[0], '${price?.toStringAsFixed(2) ?? '-'} (${isUp ? '+' : ''}${pct.toStringAsFixed(2)}%)', valueColor: isUp ? AppColors.success : AppColors.danger);
        }),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Breakouts', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _breakoutTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _breakoutTab == 0 ? AppColors.primary : AppColors.border, width: 2))),
                    alignment: Alignment.center,
                    child: Text('Volume Breakout', textAlign: TextAlign.center, style: TextStyle(color: _breakoutTab == 0 ? AppColors.primary : AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _breakoutTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _breakoutTab == 1 ? AppColors.primary : AppColors.border, width: 2))),
                    alignment: Alignment.center,
                    child: Text('Opening Range Breakdown', textAlign: TextAlign.center, style: TextStyle(color: _breakoutTab == 1 ? AppColors.primary : AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_breakoutTab == 0)
          if (_volumeBreakouts.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No volume breakouts detected', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))))
          else
            ..._volumeBreakouts.map((v) => _statRow(v['symbol'], '${(v['ratio'] as double).toStringAsFixed(1)}x avg vol', valueColor: AppColors.success))
        else if (_openingRangeBreakdowns.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No opening range breakdowns detected', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))))
        else
          ..._openingRangeBreakdowns.map((v) => _statRow(v['symbol'], '${(v['change'] as double).toStringAsFixed(2)}%', valueColor: AppColors.danger)),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.stock['symbol'] ?? '';
    final price = _quote != null ? (_quote!['price'] as num?)?.toDouble() : null;
    final changePercent = _quote != null ? (_quote!['change_percent'] as num?)?.toDouble() : null;
    final isUp = (changePercent ?? 0) >= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text('Technicals', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            if (price != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    Text(price.toStringAsFixed(2), style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                    const SizedBox(width: 8),
                    Text('(${isUp ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%)', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            TabBar(
              controller: _mainTab,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              tabs: const [Tab(text: 'Technicals'), Tab(text: 'Markets')],
            ),
            Expanded(
              child: TabBarView(
                controller: _mainTab,
                children: [
                  _buildTechnicalsTab(),
                  _buildMarketsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
