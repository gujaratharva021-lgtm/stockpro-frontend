import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:stock_app/core/theme/app_colors.dart';

/// Full TradingView "Advanced Chart" widget embedded via WebView, using
/// TradingView's current official embed script
/// (embed-widget-advanced-chart.js). The older tv.js + `new
/// TradingView.widget()` approach silently falls back to a demo symbol
/// (e.g. Apple) when it fails to resolve - this uses the documented,
/// currently-supported embed method instead.
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

  String get _widgetHtml {
    final config = {
      "autosize": true,
      "symbol": _tvSymbol,
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
      "support_host": "https://www.tradingview.com"
    };
    final configJson = jsonEncode(config);

    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
    <style>
      html, body { margin:0; padding:0; height:100%; background:#ffffff; }
      .tradingview-widget-container { height:100%; width:100%; }
      .tradingview-widget-container__widget { height:100%; width:100%; }
    </style>
  </head>
  <body>
    <div class="tradingview-widget-container">
      <div class="tradingview-widget-container__widget"></div>
      <script type="text/javascript" src="https://s3.tradingview.com/external-embedding/embed-widget-advanced-chart.js" async>
        $configJson
      </script>
    </div>
  </body>
</html>
''';
  }

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
