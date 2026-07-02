import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/services/biometric_service.dart';
import 'package:stock_app/features/notifications/screens/notifications_screen.dart';
import 'package:stock_app/features/mutualfunds/screens/sip_screen.dart';
import 'package:stock_app/features/profile/screens/personal_details_screen.dart';
import 'package:stock_app/features/profile/screens/bank_accounts_screen.dart';
import 'package:stock_app/features/profile/screens/kyc_documents_screen.dart';
import 'package:stock_app/features/profile/screens/security_screen.dart';
import 'package:stock_app/features/profile/screens/help_support_screen.dart';
import 'package:stock_app/features/profile/screens/user_manual_screen.dart';
import 'package:stock_app/features/profile/screens/invite_friends_screen.dart';
import 'package:stock_app/features/profile/screens/tradebook_screen.dart';
import 'package:stock_app/features/profile/screens/downloads_screen.dart';
import 'package:stock_app/features/profile/screens/connected_apps_screen.dart';
import 'package:stock_app/features/profile/screens/family_screen.dart';
import 'package:stock_app/features/profile/screens/gift_stocks_screen.dart';
import 'package:stock_app/features/profile/screens/app_code_screen.dart';
import 'package:stock_app/features/tax/screens/pnl_report_screen.dart';
import 'package:stock_app/core/services/privacy_mode_service.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  late Razorpay _razorpay;
  double _pendingAmount = 0;
  String _pendingOrderId = '';

  @override
  void initState() {
    super.initState();
    _load();
    _checkBiometric();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    _privacyMode = PrivacyModeService.enabled.value;
    PrivacyModeService.enabled.addListener(_onPrivacyModeChanged);
  }

  void _onPrivacyModeChanged() {
    if (mounted) setState(() => _privacyMode = PrivacyModeService.enabled.value);
  }

  @override
  void dispose() {
    _razorpay.clear();
    PrivacyModeService.enabled.removeListener(_onPrivacyModeChanged);
    super.dispose();
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await ApiService.confirmPayment(
        response.orderId ?? _pendingOrderId,
        response.paymentId ?? '',
        response.signature ?? '',
        _pendingAmount,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('₹${_pendingAmount.toStringAsFixed(0)} added successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment received but balance update failed. Contact support.'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${response.message ?? 'Unknown error'}'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('External wallet selected: ${response.walletName}')),
      );
    }
  }

  Future<void> _startAddFunds(double amount) async {
    try {
      final order = await ApiService.createPaymentOrder(amount);
      _pendingAmount = amount;
      _pendingOrderId = order['order_id'];

      final options = {
        'key': order['key_id'],
        'amount': order['amount'],
        'currency': order['currency'],
        'name': 'StockPro',
        'description': 'Add funds to wallet',
        'order_id': order['order_id'],
        'prefill': {
          'contact': '',
          'email': _user?['email'] ?? '',
        },
        'theme': {'color': '#F5A623'},
      };

      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start payment. Please try again.'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showAddFundsDialog() {
    final amountController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: '₹ ', labelText: 'Amount', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [100, 500, 1000, 5000].map((amt) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      onPressed: () {
                        amountController.text = amt.toString();
                        setState(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('₹$amt', maxLines: 1, style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(amountController.text);
                  if (amt == null || amt <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                    return;
                  }
                  Navigator.pop(ctx);
                  _startAddFunds(amt);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Proceed to Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    final balance = _user?['balance'] != null ? (_user!['balance'] as num).toDouble() : 0.0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Withdraw Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text('Available balance: ₹${balance.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: '₹ ', labelText: 'Amount', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amountController.text);
                  if (amt == null || amt <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                    return;
                  }
                  if (amt > balance) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Insufficient balance')));
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await ApiService.withdrawFunds(amt);
                    await _load();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('₹${amt.toStringAsFixed(0)} withdrawn successfully'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Withdrawal failed'), backgroundColor: AppColors.danger),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                child: const Text('Withdraw', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getMe();
      setState(() => _user = res['user']);
    } catch (_) {
      // fail silently, show empty state below
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _uploadingAvatar = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _privacyMode = false;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      await ApiService.uploadAvatar(picked.path);
      await _load(); // refresh profile so new avatar_url shows
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload image')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    if (mounted) context.go('/login');
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? error;
    bool deleting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Account'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will permanently delete your account and all your data (orders, portfolio, watchlist). This cannot be undone.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Enter your password to confirm',
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: deleting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: deleting
                      ? null
                      : () async {
                          if (passwordController.text.isEmpty) {
                            setDialogState(() => error = 'Password is required');
                            return;
                          }
                          setDialogState(() {
                            deleting = true;
                            error = null;
                          });
                          try {
                            await ApiService.deleteAccount(passwordController.text);
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              context.go('/login');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Account deleted successfully')),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              deleting = false;
                              error = 'Incorrect password or something went wrong';
                            });
                          }
                        },
                  child: deleting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Delete', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycDone = _user?['kyc_completed'] == true;
    final name = _user?['name'] ?? 'Trader';
    final email = _user?['email'] ?? '';
    final balance = _user?['balance'] != null ? (_user!['balance'] as num).toDouble() : 0.0;

    return MainShell(
      currentIndex: 4,
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const Text('Profile', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: Stack(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                              image: _user?['avatar_url'] != null
                                  ? DecorationImage(
                                      image: NetworkImage('https://stock-backend-11rm.onrender.com${_user!['avatar_url']}'),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _user?['avatar_url'] == null
                                ? Center(
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                                    ),
                                  )
                                : null,
                          ),
                          if (_uploadingAvatar)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryDark),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 2),
                          Text(email, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kycDone ? AppColors.success.withOpacity(0.08) : AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kycDone ? AppColors.success.withOpacity(0.3) : AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        kycDone ? Icons.verified_outlined : Icons.warning_amber_outlined,
                        color: kycDone ? AppColors.success : AppColors.primaryDark,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kycDone ? 'KYC Verified' : 'KYC Pending',
                              style: TextStyle(
                                color: kycDone ? AppColors.success : AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              kycDone ? 'Your account is fully verified' : 'Complete KYC to unlock all features',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (!kycDone)
                        TextButton(
                          onPressed: () => context.go('/onboarding'),
                          child: const Text('Complete', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Wallet Balance', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Row(
                        children: [
                          Text(
                            _privacyMode ? '₹••••••' : '₹${balance.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => PrivacyModeService.enabled.value = !PrivacyModeService.enabled.value,
                            child: Icon(_privacyMode ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _showAddFundsDialog,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('+ Add Funds', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _showWithdrawDialog,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.textSecondary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Withdraw', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _menuSection('Account', [
                _menuItem(Icons.person_outline, 'Personal Details', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalDetailsScreen()))),
                _menuItem(Icons.receipt_long_outlined, 'Tax P&L Report', onTap: () => context.push('/tax-report')),
                _menuItem(Icons.bar_chart_outlined, 'P&L Report', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PnLReportScreen()))),
                _menuItem(Icons.list_alt_outlined, 'Tradebook', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TradebookScreen()))),
                _menuItem(Icons.download_outlined, 'Downloads', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()))),
                _menuItem(Icons.apps_outlined, 'Connected Apps', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectedAppsScreen()))),
                _menuItem(Icons.family_restroom_outlined, 'Family', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen()))),
                _menuItem(Icons.card_giftcard_outlined, 'Gift Stocks', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GiftStocksScreen()))),
                _menuItem(Icons.repeat, 'My SIPs', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SipScreen()))),
                _menuItem(Icons.lock_outline, 'App Code', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppCodeScreen()))),
              ]),
              const SizedBox(height: 20),
              _menuSection('Preferences', [
                _menuItem(Icons.notifications_outlined, 'Notifications', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                }),
                _menuItem(Icons.pending_actions_outlined, 'Limit & Stop-Loss Orders', onTap: () => context.push('/pending-orders')),
                _menuItem(Icons.calculate_outlined, 'Brokerage Calculator', onTap: () => context.push('/brokerage-calculator')),
                if (_biometricAvailable)
                  _menuItemWithToggle(
                    Icons.fingerprint,
                    'Biometric Login',
                    _biometricEnabled,
                    (val) async {
                      await BiometricService.setEnabled(val);
                      setState(() => _biometricEnabled = val);
                    },
                  ),
                _menuItemWithToggle(
                  Icons.remove_red_eye_outlined,
                  'Privacy Mode',
                  _privacyMode,
                  (val) => PrivacyModeService.enabled.value = val,
                ),
                _menuItem(Icons.security_outlined, 'Security', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()))),
                _menuItem(Icons.privacy_tip_outlined, 'Privacy Policy', onTap: () => _openUrl('https://gujaratharva021-lgtm.github.io/stockpro-legal/privacy-policy.html')),
                _menuItem(Icons.description_outlined, 'Terms of Service', onTap: () => _openUrl('https://gujaratharva021-lgtm.github.io/stockpro-legal/terms-of-service.html')),
                _menuItem(Icons.help_outline, 'Help & Support', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
              ]),
              const SizedBox(height: 20),
              _menuSection('More', [
                _menuItem(Icons.menu_book_outlined, 'User Manual', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManualScreen()))),
                _menuItem(Icons.person_add_alt_outlined, 'Invite Friends', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteFriendsScreen()))),
                _menuItem(Icons.description_outlined, 'Licenses', onTap: () => showLicensePage(context: context, applicationName: 'StockPro', applicationVersion: 'v1.0')),
              ]),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextButton(
                  onPressed: _confirmDeleteAccount,
                  child: const Text(
                    'Delete Account',
                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('StockPro v1.0', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _menuSection(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: items),
          ),
        ],
      ),
    );
  }



  Widget _menuItemWithToggle(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary, size: 20),
        title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}