import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:stock_app/core/theme/app_colors.dart';

/// Full TradingView "Advanced Chart" widget embedded via WebView.
/// This gives the real TradingView UI - drawing tools, indicators,
/// timeframes, log scale, etc. - exactly like the Kite/TradingView
/// screenshots, since it loads TradingView's own free embeddable widget
/// rather than a custom-built chart.
///
/// Note: this shows TradingView's own live market data for the symbol
/// (not our backend's data). NSE/BSE-listed symbols are available on
/// TradingView under prefixes like NSE: or BSE:.
class AdvancedChartScreen extends StatefulWidget {
  final String symbol;
  final String companyName;
  final List<dynamic> history; // kept for API compatibility, unused now
  final double? currentPrice;
  final double? changePercent;
  final String exchange; // 'NSE' or 'BSE', defaults to NSE

  const AdvancedChartScreen({
    super.key,
    required this.symbol,
    required this.companyName,
    required this.history,
    this.currentPrice,
    this.changePercent,
    this.exchange = 'NSE',
  });

  @override
  State<AdvancedChartScreen> createState() => _AdvancedChartScreenState();
}

class _AdvancedChartScreenState extends State<AdvancedChartScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  String get _tvSymbol {
    final ex = widget.exchange.trim().toUpperCase();
    final prefix = (ex == 'BSE') ? 'BSE' : 'NSE';
    return '$prefix:${widget.symbol}';
  }

  String get _widgetHtml => '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
    <style>
      html, body { margin:0; padding:0; height:100%; background:#ffffff; }
      #tv_chart { height:100%; width:100%; }
    </style>
  </head>
  <body>
    <div id="tv_chart"></div>
    <script src="https://s3.tradingview.com/tv.js"></script>
    <script>
      new TradingView.widget({
        "autosize": true,
        "symbol": "$_tvSymbol",
        "interval": "D",
        "timezone": "Asia/Kolkata",
        "theme": "light",
        "style": "1",
        "locale": "in",
        "toolbar_bg": "#f1f3f6",
        "enable_publishing": false,
        "hide_top_toolbar": false,
        "hide_legend": false,
        "withdateranges": true,
        "allow_symbol_change": false,
        "details": true,
        "hotlist": false,
        "calendar": false,
        "studies": [],
        "container_id": "tv_chart"
      });
    </script>
  </body>
</html>
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadHtmlString(_widgetHtml, baseUrl: 'https://s3.tradingview.com');
  }

  @override
  Widget build(BuildContext context) {
    final isUp = (widget.changePercent ?? 0) >= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(widget.companyName, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (widget.currentPrice != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\u20b9${widget.currentPrice!.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${isUp ? '+' : ''}${widget.changePercent?.toStringAsFixed(2) ?? '0.00'}%', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_loading)
                    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
