$ErrorActionPreference = "Stop"

$file = "lib\features\portfolio\screens\portfolio_screen.dart"

if (-not (Test-Path $file)) {
    Write-Host "File not found: $file  (run this from your project root, e.g. C:\Users\ABC\Downloads\stockpro-frontend)" -ForegroundColor Red
    exit 1
}

# Read with explicit UTF8 and normalize line endings to LF for reliable matching
$raw = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
$content = $raw -replace "`r`n", "`n"

function Replace-Once {
    param($text, $old, $new, $label)
    $count = ([regex]::Matches($text, [regex]::Escape($old))).Count
    if ($count -eq 0) {
        Write-Host "SKIP ($label): pattern not found - file may already differ. Please check manually." -ForegroundColor Yellow
        return $text
    } elseif ($count -gt 1) {
        Write-Host "WARN ($label): pattern found $count times, replacing all occurrences." -ForegroundColor Yellow
    } else {
        Write-Host "OK ($label): applied." -ForegroundColor Green
    }
    return $text.Replace($old, $new)
}

# 1) Imports
$old1 = @'
import 'package:flutter/material.dart';
import 'package:stock_app/shared/widgets/overview_sheet.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/shared/widgets/account_drawer.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/shared/widgets/error_state.dart';
import 'package:stock_app/shared/widgets/empty_state.dart';
import 'package:stock_app/core/theme/app_typography.dart';
import 'package:stock_app/features/stock_detail/screens/stock_quote_sheet.dart';
import 'package:stock_app/features/portfolio/screens/family_screen.dart';
'@
$new1 = @'
import 'package:flutter/material.dart';
import 'package:stock_app/shared/widgets/overview_sheet.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/shared/widgets/account_drawer.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/shared/widgets/error_state.dart';
import 'package:stock_app/shared/widgets/empty_state.dart';
import 'package:stock_app/core/theme/app_typography.dart';
import 'package:stock_app/shared/widgets/status_badge.dart';
import 'package:stock_app/features/stock_detail/screens/stock_quote_sheet.dart';
import 'package:stock_app/features/portfolio/screens/family_screen.dart';
'@
$content = Replace-Once $content $old1 $new1 "imports"

# 2) New fields
$old2 = @'
  // ignore: unused_field
  List<dynamic> _transactions = [];

  List<dynamic> _mtfPositions = [];
'@
$new2 = @'
  List<dynamic> _transactions = [];
  List<dynamic> _pendingOrders = [];
  Map<String, String> _symbolByStockId = {};

  List<dynamic> _mtfPositions = [];
'@
$content = Replace-Once $content $old2 $new2 "fields"

# 3) Future.wait list - add getPendingOrders + getStocks
$old3 = @'
      final results = await Future.wait([
        ApiService.getHoldings(),
        ApiService.getTransactions(),
        ApiService.getMe(),
        ApiService.getMyFunds().catchError((_) => []),
        ApiService.getMyETFs().catchError((_) => []),
        ApiService.getMTFPositions().catchError((_) => []),
        ApiService.getPositions().catchError((_) => []),
        ApiService.getFutures().catchError((_) => []),
        ApiService.getOptions().catchError((_) => []),
      ]);
'@
$new3 = @'
      final results = await Future.wait([
        ApiService.getHoldings(),
        ApiService.getTransactions(),
        ApiService.getMe(),
        ApiService.getMyFunds().catchError((_) => []),
        ApiService.getMyETFs().catchError((_) => []),
        ApiService.getMTFPositions().catchError((_) => []),
        ApiService.getPositions().catchError((_) => []),
        ApiService.getFutures().catchError((_) => []),
        ApiService.getOptions().catchError((_) => []),
        ApiService.getPendingOrders().catchError((_) => []),
        ApiService.getStocks().catchError((_) => []),
      ]);
'@
$content = Replace-Once $content $old3 $new3 "future-wait-list"

# 4) results destructure + setState
$old4 = @'
      final holdings = results[0] as List<dynamic>;
      final transactions = results[1] as List<dynamic>;
      final me = results[2] as Map<String, dynamic>;
      final myFunds = results[3] as List<dynamic>;
      final myEtfs = results[4] as List<dynamic>;
      final mtfPositions = results[5] as List<dynamic>;
      final unsettledPositions = results[6] as List<dynamic>;
      final futures = results[7] as List<dynamic>;
      final options = results[8] as List<dynamic>;

      setState(() {
        _holdings = holdings;
        _transactions = transactions;
        _balance = (me['user']?['balance'] as num?)?.toDouble() ?? 0;
        _myFunds = myFunds;
        _myEtfs = myEtfs;
        _mtfPositions = mtfPositions;
        _unsettledPositions = unsettledPositions;
        _futures = futures;
        _options = options;
      });
'@
$new4 = @'
      final holdings = results[0] as List<dynamic>;
      final transactions = results[1] as List<dynamic>;
      final me = results[2] as Map<String, dynamic>;
      final myFunds = results[3] as List<dynamic>;
      final myEtfs = results[4] as List<dynamic>;
      final mtfPositions = results[5] as List<dynamic>;
      final unsettledPositions = results[6] as List<dynamic>;
      final futures = results[7] as List<dynamic>;
      final options = results[8] as List<dynamic>;
      final pendingOrders = results[9] as List<dynamic>;
      final stocks = results[10] as List<dynamic>;
      final symbolMap = <String, String>{};
      for (final s in stocks) {
        if (s['id'] != null && s['symbol'] != null) {
          symbolMap[s['id'].toString()] = s['symbol'].toString();
        }
      }

      setState(() {
        _holdings = holdings;
        _transactions = transactions;
        _balance = (me['user']?['balance'] as num?)?.toDouble() ?? 0;
        _myFunds = myFunds;
        _myEtfs = myEtfs;
        _mtfPositions = mtfPositions;
        _unsettledPositions = unsettledPositions;
        _futures = futures;
        _options = options;
        _pendingOrders = pendingOrders;
        _symbolByStockId = symbolMap;
      });
'@
$content = Replace-Once $content $old4 $new4 "results-destructure"

# 5) Tab rendering - wire up real tabs
$old5 = @'
                  if (_tab == 0) ..._buildHoldingsTab(),
                  if (_tab == 1) ..._buildPositionsTab(),
                  if (_tab == 2) ..._buildEmptyTab(),
                  if (_tab == 3) ..._buildEmptyTab(),
                  if (_tab == 4) ..._buildEmptyTab(),
                  if (_tab == 5) ..._buildEmptyTab(),
'@
$new5 = @'
                  if (_tab == 0) ..._buildHoldingsTab(),
                  if (_tab == 1) ..._buildPositionsTab(),
                  if (_tab == 2) ..._buildEmptyTab(),
                  if (_tab == 3) ..._buildOrdersTab(),
                  if (_tab == 4) ..._buildEmptyTab(),
                  if (_tab == 5) ..._buildTradesTab(),
'@
$content = Replace-Once $content $old5 $new5 "tab-rendering"

# 6) Insert new methods (_buildOrdersTab, _orderRow, _buildTradesTab, _tradeRow) before _buildMutualFundsTab
$old6 = @'
            childCount: allPositions.length,
          ),
        ),
      ),
    ];
  }

  // ignore: unused_element
  List<Widget> _buildMutualFundsTab() {
'@
$new6 = @'
            childCount: allPositions.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildOrdersTab() {
    final orders = _pendingOrders.where((o) => o['is_gtt'] != true).toList();
    if (orders.isEmpty) {
      return [
        SliverFillRemaining(
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'No orders yet\nPlace an order from a stock screen',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _orderRow(orders[index]),
            childCount: orders.length,
          ),
        ),
      ),
    ];
  }

  AppStatusTone _orderStatusTone(String status) {
    if (status == 'REJECTED') return AppStatusTone.error;
    if (status == 'EXECUTED') return AppStatusTone.positive;
    return AppStatusTone.warning;
  }

  Future<void> _cancelPendingOrder(String orderId) async {
    try {
      await ApiService.cancelPendingOrder(orderId);
      _loadAll();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not cancel order')));
    }
  }

  Widget _orderRow(Map<String, dynamic> order) {
    final isBuy = order['buy_sell'] == 'BUY';
    final status = (order['status'] ?? '').toString();
    final accentColor = isBuy ? AppColors.success : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(order['buy_sell'] ?? '', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order['symbol']?.toString() ?? '',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(label: status, tone: _orderStatusTone(status)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Qty: ${order['quantity'] ?? '-'}  \u2022  Trigger: \u20b9${order['trigger_price'] ?? '-'}  \u2022  ${order['order_type'] ?? '-'}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (status == 'PENDING') ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _cancelPendingOrder(order['id']),
                style: TextButton.styleFrom(backgroundColor: AppColors.danger.withValues(alpha: 0.1), padding: const EdgeInsets.symmetric(horizontal: 10)),
                child: const Text('Cancel', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildTradesTab() {
    if (_transactions.isEmpty) {
      return [
        SliverFillRemaining(
          child: EmptyState(
            icon: Icons.receipt_outlined,
            message: 'No trades yet',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _tradeRow(_transactions[index]),
            childCount: _transactions.length,
          ),
        ),
      ),
    ];
  }

  Widget _tradeRow(dynamic t) {
    final isBuy = t['buy_sell'] == 'BUY';
    final accentColor = isBuy ? AppColors.success : AppColors.danger;
    final qty = (t['quantity'] as num?) ?? 0;
    final price = (t['price'] as num?) ?? 0;
    final symbol = t['symbol']?.toString() ?? _symbolByStockId[t['stock_id']?.toString()] ?? '-';
    String timeStr = '-';
    final createdAt = t['created_at'] != null ? DateTime.tryParse(t['created_at'].toString()) : null;
    if (createdAt != null) timeStr = DateFormat('dd MMM, h:mm a').format(createdAt.toLocal());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(isBuy ? 'BUY' : 'SELL', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text('Qty $qty @ \u20b9${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(timeStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  // ignore: unused_element
  List<Widget> _buildMutualFundsTab() {
'@
$content = Replace-Once $content $old6 $new6 "insert-new-methods"

# Restore CRLF and write back without BOM
$final = $content -replace "`n", "`r`n"
[System.IO.File]::WriteAllText($file, $final, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "Done. Now run: flutter analyze  (to check for errors), then flutter run" -ForegroundColor Cyan
