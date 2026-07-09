import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class IpoDetailScreen extends StatefulWidget {
  final String ipoId;
  const IpoDetailScreen({super.key, required this.ipoId});

  @override
  State<IpoDetailScreen> createState() => _IpoDetailScreenState();
}

class _IpoDetailScreenState extends State<IpoDetailScreen> {
  Map<String, dynamic>? _ipo;
  bool _loading = true;
  String? _error;
  bool _applying = false;
  int _lots = 1;
  final _upiController = TextEditingController();
  String? _upiError;

  bool _isValidUpi(String upi) {
    final regex = RegExp(r'^[\w.\-]{2,256}@[a-zA-Z][a-zA-Z0-9]{2,64}$');
    return regex.hasMatch(upi.trim());
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ipo = await ApiService.getIPODetail(widget.ipoId);
      setState(() => _ipo = ipo);
    } catch (e) {
      setState(() => _error = 'Could not load IPO details');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return const Color(0xFF16A34A);
      case 'upcoming':
        return const Color(0xFFF59E0B);
      case 'closed':
        return const Color(0xFFEF4444);
      case 'listed':
        return const Color(0xFF3B4FE8);
      default:
        return AppColors.primary;
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return '-';
    }
  }

  String _formatDateShort(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr.toString());
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  Future<void> _confirmApply() async {
    final upi = _upiController.text.trim();
    if (!_isValidUpi(upi)) {
      setState(() => _upiError = 'Enter a valid UPI ID (e.g. name@bank)');
      return;
    }
    setState(() => _upiError = null);

    final lotSize = _ipo!['lot_size'] as int;
    final priceHigh = (_ipo!['price_band_high'] as num).toDouble();
    final amount = _lots * lotSize * priceHigh;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Confirm Application', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Apply for $_lots lot(s) (${_lots * lotSize} shares) of ${_ipo!['company_name']} at ₹${priceHigh.toStringAsFixed(0)}/share?\n\nTotal amount: ₹${amount.toStringAsFixed(0)}\nUPI ID: $upi',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _applying = true);
    try {
      await ApiService.applyIPO(widget.ipoId, _lots, upi);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      String message = 'Application failed';
      String serverMsg = '';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          serverMsg = data['error'].toString();
        }
      }
      if (serverMsg.isEmpty) serverMsg = e.toString();

      if (serverMsg.contains('insufficient balance')) {
        message = 'Insufficient balance to apply';
      } else if (serverMsg.contains('already applied')) {
        message = 'You have already applied for this IPO';
      } else if (serverMsg.contains('not currently open')) {
        message = 'This IPO is not open for applications';
      } else if (serverMsg.isNotEmpty) {
        message = serverMsg;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final ipo = _ipo!;
    final status = (ipo['status'] ?? '').toString();
    final color = _statusColor(status);
    final priceLow = (ipo['price_band_low'] as num?)?.toDouble() ?? 0.0;
    final priceHigh = (ipo['price_band_high'] as num?)?.toDouble() ?? 0.0;
    final lotSize = ipo['lot_size'] ?? 1;
    final isOpen = status == 'open';
    final aboutText = ipo['about_text'] as String?;
    final strengths = (ipo['strengths'] as List<dynamic>?)?.cast<String>();
    final risks = (ipo['risks'] as List<dynamic>?)?.cast<String>();
    final financials = (ipo['financials'] as List<dynamic>?)?.cast<Map<String, dynamic>>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ipo['company_name'] ?? '',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      ipo['company_name'] ?? '',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _detailRow('Min Qty', '${ipo['min_qty'] ?? lotSize}'),
                      const Divider(height: 24, color: AppColors.border),
                      _detailRow('Price Band', '₹${priceLow.toStringAsFixed(0)} - ₹${priceHigh.toStringAsFixed(0)}'),
                      const Divider(height: 24, color: AppColors.border),
                      _detailRow('Lot Size', '$lotSize shares'),
                      const Divider(height: 24, color: AppColors.border),
                      _detailRow('Issue Size', (ipo['issue_size'] ?? '-').toString()),
                      const Divider(height: 24, color: AppColors.border),
                      _detailRow('Open Date', _formatDate(ipo['open_date'])),
                      const Divider(height: 24, color: AppColors.border),
                      _detailRow('Close Date', _formatDate(ipo['close_date'])),
                      if (ipo['listing_date'] != null) ...[
                        const Divider(height: 24, color: AppColors.border),
                        _detailRow('Listing Date', _formatDate(ipo['listing_date'])),
                      ],
                    ],
                  ),
                ),

                if (aboutText != null) ...[
                  const SizedBox(height: 24),
                  const Text('About the company', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text(aboutText, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
                ],

                if (financials != null && financials.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Financials', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      const Text('₹ in crores', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ..._buildFinancialsChart(financials),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _legendDot(const Color(0xFF90A4E8), 'Total Assets'),
                      const SizedBox(width: 14),
                      _legendDot(const Color(0xFFF0C674), 'Revenue'),
                      const SizedBox(width: 14),
                      _legendDot(const Color(0xFFEF8C7C), 'Profit After Tax'),
                    ],
                  ),
                ],

                if (strengths != null && strengths.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('Strengths', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  ...strengths.map((s) => _bulletLine(s)),
                ],

                if (risks != null && risks.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('Risks', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  ...risks.map((r) => _bulletLine(r)),
                ],

                if (ipo['allotment_date'] != null) ...[
                  const SizedBox(height: 24),
                  const Text('IPO status', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 14),
                  _timelineStep('Offer start', _formatDateShort(ipo['open_date']), false),
                  _timelineStep('Offer end', _formatDateShort(ipo['close_date']), false),
                  _timelineStep('Allotment', _formatDateShort(ipo['allotment_date']), false),
                  _timelineStep('Refund Initiation', _formatDateShort(ipo['refund_date']), false),
                  _timelineStep('Demat transfer', _formatDateShort(ipo['demat_transfer_date']), false),
                  _timelineStep('Listing', _formatDateShort(ipo['listing_date']), false),
                  _timelineStep('Mandate end', _formatDateShort(ipo['mandate_end_date']), true),
                ],

                if (isOpen) ...[
                  const SizedBox(height: 24),
                  const Text('UPI ID', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _upiController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'yourname@bank',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      errorText: _upiError,
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) {
                      if (_upiError != null) setState(() => _upiError = null);
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Number of Lots', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _lotButton(Icons.remove, () {
                        if (_lots > 1) setState(() => _lots--);
                      }),
                      Expanded(
                        child: Center(
                          child: Column(
                            children: [
                              Text('$_lots', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
                              Text('${_lots * (lotSize as int)} shares', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      _lotButton(Icons.add, () => setState(() => _lots++)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        Text(
                          '₹${(_lots * lotSize * priceHigh).toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _applying ? null : _confirmApply,
                child: _applying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Apply Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildFinancialsChart(List<Map<String, dynamic>> financials) {
    double maxVal = 0;
    for (final f in financials) {
      final assets = (f['total_assets'] as num?)?.toDouble() ?? 0;
      final revenue = (f['revenue'] as num?)?.toDouble() ?? 0;
      if (assets > maxVal) maxVal = assets;
      if (revenue > maxVal) maxVal = revenue;
    }
    if (maxVal <= 0) maxVal = 1;

    return financials.map((f) {
      final assets = (f['total_assets'] as num?)?.toDouble() ?? 0;
      final revenue = (f['revenue'] as num?)?.toDouble() ?? 0;
      final pat = (f['profit_after_tax'] as num?)?.toDouble() ?? 0;
      final year = (f['year'] ?? '').toString();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(year, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            _financialBar(assets, maxVal, const Color(0xFF90A4E8)),
            const SizedBox(height: 4),
            _financialBar(revenue, maxVal, const Color(0xFFF0C674)),
            const SizedBox(height: 4),
            _financialBar(pat, maxVal, const Color(0xFFEF8C7C)),
          ],
        ),
      );
    }).toList();
  }

  Widget _financialBar(double value, double maxVal, Color color) {
    final fraction = (value / maxVal).clamp(0.03, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth * 0.75;
        return Row(
          children: [
            Container(
              width: barWidth * fraction,
              height: 14,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 8),
            Text(value.toStringAsFixed(2), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        );
      },
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _bulletLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 5, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }

  Widget _timelineStep(String label, String date, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border, width: 1.5)),
              ),
              if (!isLast) Expanded(child: Container(width: 1.5, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                const SizedBox(height: 2),
                Text(date, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  Widget _lotButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
    );
  }
}