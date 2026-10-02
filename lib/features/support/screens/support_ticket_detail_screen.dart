import 'package:flutter/material.dart';
import 'package:stock_app/core/services/support_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class SupportTicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final String subject;
  const SupportTicketDetailScreen({super.key, required this.ticketId, required this.subject});
  @override
  State<SupportTicketDetailScreen> createState() => _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  final _ctrl = TextEditingController();
  List<dynamic> _messages = [];
  String _status = 'OPEN';
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await SupportService.getTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _status = (data['ticket'] as Map?)?['status']?.toString() ?? 'OPEN';
        _messages = (data['messages'] as List?) ?? [];
      });
    } catch (e) {
      if (mounted) setState(() => _error = SupportService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await SupportService.reply(widget.ticketId, text);
      _ctrl.clear();
      await _load(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SupportService.errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.78;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(widget.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => _load())],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i] as Map;
                          final admin = m['is_admin'] == true;
                          return Align(
                            alignment: admin ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: maxW),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: admin ? AppColors.cardBackground : AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${admin ? 'Support' : 'You'} · ${SupportService.formatTime(m['created_at']?.toString())}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(m['body'].toString(), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, height: 1.35)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (!_loading && _error == null)
            SafeArea(
              top: false,
              child: _status == 'OPEN'
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              maxLength: 2000,
                              minLines: 1,
                              maxLines: 4,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: const InputDecoration(hintText: 'Write a reply...', counterText: '', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _sending ? null : _send,
                            icon: _sending
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.send, color: AppColors.primary),
                          ),
                        ],
                      ),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('This ticket is closed. Create a new ticket if you still need help.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                    ),
            ),
        ],
      ),
    );
  }
}