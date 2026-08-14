import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';

class PerformanceScreen extends StatefulWidget {
  final int? navIndex;
  const PerformanceScreen({super.key, this.navIndex});
  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  List<DateTime> _rawDates = [];
  List<double> _rawValues = [];
  bool _loading = true;
  String? _error;

  final List<String> _periods = const ['7D', 'MTD', 'YTD', '1Y', 'All'];
  String _period = 'YTD';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getPerformance();
      final points = (data['performance'] as List);
      points.sort((a, b) => a['date'].compareTo(b['date']));
      setState(() {
        _rawDates = points.map((p) => DateTime.parse(p['date'].toString())).toList();
        _rawValues = points.map((p) => (p['value'] as num).toDouble()).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Performance load error: $e');
      setState(() { _error = 'Failed to load performance'; _loading = false; });
    }
  }

  List<int> get _filteredIndices {
    if (_rawDates.isEmpty) return [];
    final last = _rawDates.last;
    DateTime cutoff;
    switch (_period) {
      case '7D':
        cutoff = last.subtract(const Duration(days: 7));
        break;
      case 'MTD':
        cutoff = DateTime(last.year, last.month, 1);
        break;
      case 'YTD':
        cutoff = DateTime(last.year, 1, 1);
        break;
      case '1Y':
        cutoff = last.subtract(const Duration(days: 365));
        break;
      default:
        cutoff = _rawDates.first;
    }
    final idx = <int>[];
    for (int i = 0; i < _rawDates.length; i++) {
      if (!_rawDates[i].isBefore(cutoff)) idx.add(i);
    }
    return idx.isEmpty ? List.generate(_rawDates.length, (i) => i) : idx;
  }

  String _fmtMonth(DateTime d) => "${_monthAbbr(d.month)} '${d.year.toString().substring(2)}";
  String _monthAbbr(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  @override
  Widget build(BuildContext context) {
    final idx = _filteredIndices;
    final values = idx.map((i) => _rawValues[i]).toList();
    final dates = idx.map((i) => _rawDates[i]).toList();
    final spots = [for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])];

    final beginningValue = values.isNotEmpty ? values.first : 0.0;
    final endingValue = values.isNotEmpty ? values.last : 0.0;
    final netChange = endingValue - beginningValue;
    final returnPct = beginningValue != 0 ? (netChange / beginningValue) * 100 : 0.0;
    final isUp = netChange >= 0;

    final scaffold = Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: widget.navIndex == null,
        title: const Text('Performance', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        actions: [
          if (widget.navIndex != null)
            TextButton(
              onPressed: () => context.push('/portfolio/holdings'),
              child: const Text('Holdings', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          IconButton(icon: const Icon(Icons.menu, color: AppColors.textMuted), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
              : _rawValues.isEmpty
                  ? const Center(child: Text('No transactions yet', style: TextStyle(color: AppColors.textMuted)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        // Period selector: 7D | MTD | YTD | 1Y | All
                        Row(
                          children: _periods.map((p) {
                            final active = _period == p;
                            return Padding(
                              padding: const EdgeInsets.only(right: 22),
                              child: GestureDetector(
                                onTap: () => setState(() => _period = p),
                                child: Container(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 2)),
                                  ),
                                  child: Text(p, style: TextStyle(color: active ? AppColors.primaryDark : AppColors.textSecondary, fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        const Text('Net Liquidation Value', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('₹${endingValue.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '${isUp ? '+' : ''}₹${netChange.toStringAsFixed(2)} (${isUp ? '+' : ''}${returnPct.toStringAsFixed(2)}%)',
                          style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 220,
                          child: spots.length < 2
                              ? const Center(child: Text('Not enough data for this period', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
                              : LineChart(
                                  LineChartData(
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1),
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 56,
                                          getTitlesWidget: (val, _) => Text('₹${(val / 1000).toStringAsFixed(0)}K', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 26,
                                          interval: (dates.length / 3).clamp(1, double.infinity).ceilToDouble(),
                                          getTitlesWidget: (val, _) {
                                            final i = val.toInt();
                                            if (i < 0 || i >= dates.length) return const SizedBox();
                                            return Text(_fmtMonth(dates[i]), style: const TextStyle(color: AppColors.textMuted, fontSize: 10));
                                          },
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: spots,
                                        isCurved: true,
                                        color: AppColors.success,
                                        barWidth: 2.5,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [AppColors.success.withValues(alpha: 0.18), AppColors.success.withValues(alpha: 0.0)],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 28),
                        const Text('Performance Details', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Divider(color: AppColors.border, height: 1),
                        _detailRow('Beginning Value', '₹${beginningValue.toStringAsFixed(2)}'),
                        _detailRow('Net Contributions', '—'),
                        _detailRow('Net Change', '${isUp ? '+' : ''}₹${netChange.toStringAsFixed(2)}', color: isUp ? AppColors.success : AppColors.danger),
                        _detailRow('Ending Value', '₹${endingValue.toStringAsFixed(2)}'),
                        _detailRow('Return', '${isUp ? '+' : ''}${returnPct.toStringAsFixed(2)}%', color: isUp ? AppColors.success : AppColors.danger, last: true),
                      ],
                    ),
    );
    if (widget.navIndex != null) {
      return MainShell(currentIndex: widget.navIndex!, child: scaffold);
    }
    return scaffold;
  }

  Widget _detailRow(String label, String value, {Color? color, bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.border, width: 0.6))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(color: color ?? AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
