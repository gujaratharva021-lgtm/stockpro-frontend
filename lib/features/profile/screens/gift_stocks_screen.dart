import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class GiftStocksScreen extends StatefulWidget {
  const GiftStocksScreen({super.key});
  @override
  State<GiftStocksScreen> createState() => _GiftStocksScreenState();
}

class _GiftStocksScreenState extends State<GiftStocksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _sent = [];
  List<dynamic> _received = [];
  bool _loading = true;
  bool _saving = false;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = Dio();
      final token = await ApiService.getToken();
      final headers = Options(headers: {'Authorization': 'Bearer $token'});
      final results = await Future.wait([
        dio.get('${ApiService.baseUrl}/auth/gifts/sent', options: headers),
        dio.get('${ApiService.baseUrl}/auth/gifts/received', options: headers),
      ]);
      setState(() {
        _sent = results[0].data['gifts'] ?? [];
        _received = results[1].data['gifts'] ?? [];
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load gifts')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendGift(String email, String symbol, String qty, String message) async {
    setState(() => _saving = true);
    try {
      final dio = Dio();
      final token = await ApiService.getToken();
      await dio.post(
        '${ApiService.baseUrl}/auth/gifts',
        data: {
          'recipient_email': email,
          'stock_symbol': symbol,
          'quantity': double.parse(qty),
          'message': message,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) Navigator.pop(context);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gift sent'), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send gift')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _respond(String id, String action) async {
    try {
      final dio = Dio();
      final token = await ApiService.getToken();
      final headers = Options(headers: {'Authorization': 'Bearer $token'});
      if (action == 'cancel') {
        await dio.delete('${ApiService.baseUrl}/auth/gifts/$id', options: headers);
      } else {
        await dio.post('${ApiService.baseUrl}/auth/gifts/$id/$action', options: headers);
      }
      _load();
      if (mounted) {
        final msg = action == 'accept' ? 'Gift accepted' : action == 'reject' ? 'Gift rejected' : 'Gift cancelled';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed')),
        );
      }
    }
  }

  void _confirmAction(String id, String action, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(body, style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _respond(id, action);
            },
            child: Text(action == 'accept' ? 'Accept' : action == 'reject' ? 'Reject' : 'Confirm',
                style: TextStyle(color: action == 'accept' ? AppColors.success : AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _showSendSheet() {
    final emailCtrl = TextEditingController();
    final symbolCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gift a Stock', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Recipient Email',
                      labelStyle: const TextStyle(color: AppColors.textMuted),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: symbolCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Stock Symbol',
                      labelStyle: const TextStyle(color: AppColors.textMuted),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      labelStyle: const TextStyle(color: AppColors.textMuted),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Message (optional)',
                      labelStyle: const TextStyle(color: AppColors.textMuted),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () {
                        final email = emailCtrl.text.trim();
                        final symbol = symbolCtrl.text.trim();
                        final qty = qtyCtrl.text.trim();
                        if (email.isEmpty || symbol.isEmpty || qty.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please fill all required fields')),
                          );
                          return;
                        }
                        if (double.tryParse(qty) == null || double.parse(qty) <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Enter a valid quantity')),
                          );
                          return;
                        }
                        _sendGift(email, symbol.toUpperCase(), qty, messageCtrl.text.trim());
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: _saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Send Gift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors.success;
      case 'rejected':
      case 'cancelled':
        return AppColors.danger;
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

  Widget _giftCard(dynamic gift, {required bool isSent}) {
    final status = (gift['status'] ?? 'pending') as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: const Icon(Icons.card_giftcard, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${gift['stock_symbol']} · ${gift['quantity']} shares',
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(isSent ? 'To: ${gift['recipient_email']}' : 'Gift for you', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if ((gift['message'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 10),
            Text(gift['message'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),
          Text('Sent ${_formatDate(gift['created_at'])}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            if (isSent)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _confirmAction(gift['id'], 'cancel', 'Cancel Gift', 'Cancel this gift of ${gift['stock_symbol']}?'),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                  child: const Text('Cancel Gift', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _confirmAction(gift['id'], 'reject', 'Reject Gift', 'Reject this gift of ${gift['stock_symbol']}?'),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                      child: const Text('Reject', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmAction(gift['id'], 'accept', 'Accept Gift', 'Accept this gift of ${gift['stock_symbol']}?'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      child: const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _list(List<dynamic> items, {required bool isSent}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.card_giftcard_outlined, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(isSent ? 'No gifts sent yet' : 'No gifts received yet', style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _giftCard(items[i], isSent: isSent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                  const Expanded(child: Text('Gift Stocks', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.primary), onPressed: _showSendSheet),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              tabs: const [Tab(text: 'Sent'), Tab(text: 'Received')],
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _list(_sent, isSent: true),
                    _list(_received, isSent: false),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}