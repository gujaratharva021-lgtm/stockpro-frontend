import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class FnOScreen extends StatefulWidget {
  const FnOScreen({super.key});
  @override
  State<FnOScreen> createState() => _FnOScreenState();
}

class _FnOScreenState extends State<FnOScreen> {
  bool _showOptions = false;
  List<dynamic> _futures = [];
  List<dynamic> _options = [];
  List<dynamic> _stocks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = await ApiService.getFutures();
      final options = await ApiService.getOptions();
      final stocks = await ApiService.getStocks();
      setState(() {
        _futures = futures;
        _options = options;
        _stocks = stocks;
      });
    } catch (e) {
      setState(() => _error = 'Could not load positions');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeFutures(Map<String, dynamic> position) async {
    try {
      await ApiService.closeFutures(position['id'], position['symbol']);
      _load();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not close position')));
    }
  }

  Future<void> _closeOption(Map<String, dynamic> position) async {
    try {
      await ApiService.closeOption(position['id'], position['symbol']);
      _load();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not close position')));
    }
  }

  void _openNewPositionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _NewPositionSheet(
        isOptions: _showOptions,
        stocks: _stocks,
        onSubmit: () => _load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _showOptions ? _options : _futures;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewPositionSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Position', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Colors.white,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text('F&O', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _showOptions = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_showOptions ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text('Futures', style: TextStyle(color: !_showOptions ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _showOptions = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _showOptions ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text('Options', style: TextStyle(color: _showOptions ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else if (_error != null)
                SliverFillRemaining(child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))))
              else if (list.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_showOptions ? Icons.tune : Icons.show_chart, color: AppColors.textMuted, size: 48),
                          const SizedBox(height: 12),
                          Text('No ${_showOptions ? 'options' : 'futures'} positions yet', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('Tap "New Position" below to open one', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    sliver: MediaQuery.of(context).size.width > 768
                        ? SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final p = list[index];
                          return _showOptions ? _optionCard(p) : _futuresCard(p);
                        },
                        childCount: list.length,
                      ),
                    )
                        : SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final p = list[index];
                          return _showOptions ? _optionCard(p) : _futuresCard(p);
                        },
                        childCount: list.length,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _futuresCard(Map<String, dynamic> p) {
    final isOpen = p['status'] == 'OPEN';
    final isLong = p['position_type'] == 'LONG';
    final pnl = p['pnl'] != null ? (p['pnl'] as num).toDouble() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(p['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isLong ? AppColors.success : AppColors.danger).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(p['position_type'] ?? '', style: TextStyle(color: isLong ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Text(isOpen ? 'OPEN' : 'CLOSED', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lot: ${p['lot_size']} · Entry: ₹${(p['entry_price'] as num).toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              if (pnl != null)
                Text(
                  '₹${pnl.toStringAsFixed(2)}',
                  style: TextStyle(color: pnl >= 0 ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                ),
            ],
          ),
          if (isOpen) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton(
                onPressed: () => _closeFutures(p),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                child: const Text('Close Position', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionCard(Map<String, dynamic> p) {
    final isOpen = p['status'] == 'OPEN';
    final isCall = p['option_type'] == 'CALL';
    final pnl = p['pnl'] != null ? (p['pnl'] as num).toDouble() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(p['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isCall ? AppColors.success : AppColors.danger).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(p['option_type'] ?? '', style: TextStyle(color: isCall ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Text(isOpen ? 'OPEN' : 'CLOSED', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Strike: ₹${(p['strike_price'] as num).toStringAsFixed(2)} · Premium: ₹${(p['premium'] as num).toStringAsFixed(2)} · Lot: ${p['lot_size']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text('Expiry: ${(p['expiry_date'] ?? '').toString().split('T').first}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          if (pnl != null) ...[
            const SizedBox(height: 6),
            Text('₹${pnl.toStringAsFixed(2)}', style: TextStyle(color: pnl >= 0 ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
          if (isOpen) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton(
                onPressed: () => _closeOption(p),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                child: const Text('Exit Position', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NewPositionSheet extends StatefulWidget {
  final bool isOptions;
  final List<dynamic> stocks;
  final VoidCallback onSubmit;
  const _NewPositionSheet({required this.isOptions, required this.stocks, required this.onSubmit});

  @override
  State<_NewPositionSheet> createState() => _NewPositionSheetState();
}

class _NewPositionSheetState extends State<_NewPositionSheet> {
  Map<String, dynamic>? _selectedStock;
  String _positionType = 'LONG';
  String _optionType = 'CALL';
  final _lotSizeCtrl = TextEditingController(text: '1');
  final _strikeCtrl = TextEditingController();
  DateTime _expiry = DateTime.now().add(const Duration(days: 30));
  bool _submitting = false;
  String? _error;

  Future<void> _pickStock() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _StockPicker(stocks: widget.stocks),
    );
    if (selected != null) setState(() => _selectedStock = selected);
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _submit() async {
    if (_selectedStock == null) {
      setState(() => _error = 'Please select a stock');
      return;
    }
    final lotSize = int.tryParse(_lotSizeCtrl.text) ?? 0;
    if (lotSize <= 0) {
      setState(() => _error = 'Lot size must be greater than zero');
      return;
    }
    if (widget.isOptions) {
      final strike = double.tryParse(_strikeCtrl.text) ?? 0;
      if (strike <= 0) {
        setState(() => _error = 'Please enter a valid strike price');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (widget.isOptions) {
        await ApiService.buyOption(
          _selectedStock!['id'],
          _selectedStock!['symbol'],
          _optionType,
          double.parse(_strikeCtrl.text),
          lotSize,
          _expiry.toIso8601String().split('T').first,
        );
      } else {
        await ApiService.openFutures(
          _selectedStock!['id'],
          _selectedStock!['symbol'],
          _positionType,
          lotSize,
        );
      }
      widget.onSubmit();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Failed to open position. Check margin/balance.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text(
                widget.isOptions ? 'Buy Option' : 'Open Futures Position',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),

              const Text('Stock', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickStock,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedStock != null ? '${_selectedStock!['symbol']} — ${_selectedStock!['company_name']}' : 'Select a stock',
                          style: TextStyle(color: _selectedStock != null ? AppColors.textPrimary : AppColors.textMuted, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (!widget.isOptions) ...[
                const Text('Position Type', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _choiceChip('LONG', _positionType == 'LONG', () => setState(() => _positionType = 'LONG'), AppColors.success)),
                    const SizedBox(width: 10),
                    Expanded(child: _choiceChip('SHORT', _positionType == 'SHORT', () => setState(() => _positionType = 'SHORT'), AppColors.danger)),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Text('Option Type', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _choiceChip('CALL', _optionType == 'CALL', () => setState(() => _optionType = 'CALL'), AppColors.success)),
                    const SizedBox(width: 10),
                    Expanded(child: _choiceChip('PUT', _optionType == 'PUT', () => setState(() => _optionType = 'PUT'), AppColors.danger)),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Strike Price (₹)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                _textField(_strikeCtrl, 'e.g. 1500', isNumber: true),
                const SizedBox(height: 16),

                const Text('Expiry Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickExpiry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(_expiry.toIso8601String().split('T').first, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                        const Icon(Icons.calendar_today_outlined, color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Text('Lot Size', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              _textField(_lotSizeCtrl, 'e.g. 1', isNumber: true),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(widget.isOptions ? 'Buy Option' : 'Open Position', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceChip(String label, bool selected, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: selected ? color : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _StockPicker extends StatefulWidget {
  final List<dynamic> stocks;
  const _StockPicker({required this.stocks});

  @override
  State<_StockPicker> createState() => _StockPickerState();
}

class _StockPickerState extends State<_StockPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.stocks
        : widget.stocks.where((s) {
      final symbol = (s['symbol'] ?? '').toString().toLowerCase();
      final name = (s['company_name'] ?? '').toString().toLowerCase();
      return symbol.contains(_query.toLowerCase()) || name.contains(_query.toLowerCase());
    }).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search stock',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final s = filtered[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text((s['symbol'] ?? '?').toString().substring(0, 1), style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(s['symbol'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(s['company_name'] ?? ''),
                  onTap: () => Navigator.pop(context, s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}