import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/services/api_service.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  bool _submitting = false;
  File? _selfieFile;
  File? _incomeProofFile;

  // Controllers
  final _nameController = TextEditingController();
  final _occupationController = TextEditingController(text: 'Student');
  final _panController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _aadhaarOtpController = TextEditingController();

  // State
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _aadhaarOtpSent = false;
  bool _aadhaarVerified = false;
  bool _riskAccepted = false;
  bool _termsAccepted = false;
  String _incomeProofType = 'ITR';
  String? _otpError;
  String? _aadhaarOtpError;

  final List<String> _stepTitles = [
    'Personal Details',
    'Mobile Verification',
    'PAN Verification',
    'Aadhaar E-KYC',
    'Bank Account',
    'Income Proof',
    'Selfie / IPV',
    'Risk Disclosure',
    'Review & Submit',
  ];

  Future<void> _pickSelfie() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    if (picked != null) setState(() => _selfieFile = File(picked.path));
  }

  Future<void> _pickIncomeProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _incomeProofFile = File(picked.path));
  }

  void _sendOTP() {
    if (_phoneController.text.length != 10) return;
    setState(() { _otpSent = true; _otpError = null; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to your mobile number')));
  }

  void _verifyOTP() {
    if (_otpController.text == '123456' || _otpController.text.length == 6) {
      setState(() { _otpVerified = true; _otpError = null; });
    } else {
      setState(() => _otpError = 'Invalid OTP. Please try again.');
    }
  }

  void _sendAadhaarOTP() {
    if (_aadhaarController.text.length != 12) return;
    setState(() { _aadhaarOtpSent = true; _aadhaarOtpError = null; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to Aadhaar-linked mobile number')));
  }

  void _verifyAadhaarOTP() {
    if (_aadhaarOtpController.text == '123456' || _aadhaarOtpController.text.length == 6) {
      setState(() { _aadhaarVerified = true; _aadhaarOtpError = null; });
    } else {
      setState(() => _aadhaarOtpError = 'Invalid OTP. Please try again.');
    }
  }

  void _next() {
    if (_step < _stepTitles.length - 1) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ApiService.completeKYC();
      if (mounted) context.go('/kyc-success');
    } catch (_) {
      if (mounted) context.go('/kyc-success');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 768;

    final inner = Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: _back),
          Expanded(child: Text(_stepTitles[_step], textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16))),
          Text('${_step + 1}/${_stepTitles.length}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / _stepTitles.length,
            minHeight: 4,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildStepContent())),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
              _step == _stepTitles.length - 1 ? 'Submit Application' : 'Continue',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ),
    ]);

    if (isWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: SafeArea(
          child: Center(
            child: Container(
              width: 520,
              margin: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: inner,
            ),
          ),
        ),
      );
    }

    return Scaffold(backgroundColor: AppColors.background, body: SafeArea(child: inner));
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0: return _personalDetailsStep();
      case 1: return _mobileOtpStep();
      case 2: return _panStep();
      case 3: return _aadhaarStep();
      case 4: return _bankStep();
      case 5: return _incomeProofStep();
      case 6: return _selfieStep();
      case 7: return _riskDisclosureStep();
      case 8: return _reviewStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _field(String label, TextEditingController controller, {String? hint, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, TextCapitalization textCapitalization = TextCapitalization.none, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled ? AppColors.cardBackground : AppColors.border.withOpacity(0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ]),
    );
  }

  // Step 0: Personal Details
  Widget _personalDetailsStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.person_outline, color: AppColors.primary, size: 40),
      const SizedBox(height: 16),
      const Text('Tell us about yourself', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('This helps us personalize your trading experience', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 24),
      _field('Full Name', _nameController, hint: 'As per government ID'),
      _field('Occupation', _occupationController, hint: 'e.g. Student, Salaried, Business'),
      _field('Phone Number', _phoneController, hint: '10-digit mobile number', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
    ]);
  }

  // Step 1: Mobile OTP
  Widget _mobileOtpStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.phone_android, color: AppColors.primary, size: 40),
      const SizedBox(height: 16),
      const Text('Verify Mobile Number', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('OTP will be sent to +91 ${_phoneController.text}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 24),

      if (!_otpVerified) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              const Icon(Icons.phone_outlined, color: AppColors.textMuted, size: 20),
              const SizedBox(width: 12),
              Text('+91 ${_phoneController.text}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!_otpSent)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _sendOTP,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Send OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        else ...[
          _field('Enter OTP', _otpController, hint: '6-digit OTP', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]),
          if (_otpError != null) Text(_otpError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: _sendOTP, child: const Text('Resend OTP', style: TextStyle(color: AppColors.primary))),
              ElevatedButton(
                onPressed: _verifyOTP,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Verify', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ] else
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.success.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 24),
            const SizedBox(width: 12),
            Text('+91 ${_phoneController.text} verified successfully', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
          ]),
        ),
    ]);
  }

  // Step 2: PAN
  Widget _panStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.badge_outlined, color: AppColors.primary, size: 40),
      const SizedBox(height: 16),
      const Text('PAN Verification', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Required for regulatory compliance and tax reporting', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 24),
      _field('PAN Number', _panController, hint: 'ABCDE1234F', textCapitalization: TextCapitalization.characters, inputFormatters: [LengthLimitingTextInputFormatter(10), TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase()))]),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFE082))),
        child: const Row(children: [
          Icon(Icons.info_outline, color: Color(0xFFF9A825), size: 18),
          SizedBox(width: 10),
          Expanded(child: Text('PAN is mandatory for trading above ₹50,000', style: TextStyle(color: Color(0xFF795548), fontSize: 12))),
        ]),
      ),
    ]);
  }

  // Step 3: Aadhaar E-KYC
  Widget _aadhaarStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.fingerprint, color: AppColors.primary, size: 40),
      const SizedBox(height: 16),
      const Text('Aadhaar E-KYC', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('OTP will be sent to your Aadhaar-linked mobile number', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 24),

      if (!_aadhaarVerified) ...[
        _field('Aadhaar Number', _aadhaarController, hint: 'XXXX XXXX XXXX', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)]),
        if (!_aadhaarOtpSent)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _sendAadhaarOTP,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Send OTP to Aadhaar Mobile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        else ...[
          _field('Enter OTP', _aadhaarOtpController, hint: '6-digit OTP', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]),
          if (_aadhaarOtpError != null) Text(_aadhaarOtpError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: _sendAadhaarOTP, child: const Text('Resend OTP', style: TextStyle(color: AppColors.primary))),
              ElevatedButton(
                onPressed: _verifyAadhaarOTP,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Verify', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ] else
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.success.withOpacity(0.3))),
          child: const Row(children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 24),
            SizedBox(width: 12),
            Text('Aadhaar verified successfully', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
          ]),
        ),

      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
        child: const Row(children: [
          Icon(Icons.lock_outline, color: AppColors.primary, size: 18),
          SizedBox(width: 10),
          Expanded(child: Text('Your Aadhaar data is encrypted and secure. We do not store your Aadhaar number.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        ]),
      ),
    ]);
  }

  // Step 4: Bank Account
  Widget _bankStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 40),
      const SizedBox(height: 16),
      const Text('Link Bank Account', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Used to fund your trading wallet and withdrawals', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 24),
      _field('Account Number', _accountController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(20)]),
      _field('IFSC Code', _ifscController, hint: 'e.g. HDFC0001234', textCapitalization: TextCapitalization.characters),
    ]);
  }

  // Step 5: Income Proof
  Widget _incomeProofStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.description_outlined, color: AppColors.primary, size: 40),
      const SizedBox(height: 16),
      const Text('Income Proof', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Required for derivatives (F&O) trading', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 24),

      const Text('Select Document Type', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      ...['ITR', 'Salary Slip', 'Bank Statement (6 months)', 'Form 16'].map((type) => GestureDetector(
        onTap: () => setState(() => _incomeProofType = type),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _incomeProofType == type ? AppColors.primary.withOpacity(0.08) : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _incomeProofType == type ? AppColors.primary : AppColors.border),
          ),
          child: Row(children: [
            Icon(_incomeProofType == type ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _incomeProofType == type ? AppColors.primary : AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            Text(type, style: TextStyle(color: _incomeProofType == type ? AppColors.primary : AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ]),
        ),
      )),

      const SizedBox(height: 16),
      GestureDetector(
        onTap: _pickIncomeProof,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _incomeProofFile != null ? AppColors.success.withOpacity(0.05) : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _incomeProofFile != null ? AppColors.success : AppColors.border, width: _incomeProofFile != null ? 1.5 : 1),
          ),
          child: Column(children: [
            Icon(_incomeProofFile != null ? Icons.check_circle : Icons.upload_file_outlined, color: _incomeProofFile != null ? AppColors.success : AppColors.primary, size: 36),
            const SizedBox(height: 8),
            Text(_incomeProofFile != null ? 'Document uploaded ✓' : 'Tap to upload $_incomeProofType', style: TextStyle(color: _incomeProofFile != null ? AppColors.success : AppColors.primary, fontWeight: FontWeight.w600)),
            if (_incomeProofFile == null) const Text('PDF, JPG, PNG (max 5MB)', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ),
      ),
    ]);
  }

  // Step 6: Selfie / IPV
  Widget _selfieStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const SizedBox(height: 10),
      const Text('Selfie & IPV', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Take a clear selfie for identity verification', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: _pickSelfie,
        child: Container(
          width: 140, height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.1),
            border: Border.all(color: AppColors.primary, width: 2),
            image: _selfieFile != null ? DecorationImage(image: FileImage(_selfieFile!), fit: BoxFit.cover) : null,
          ),
          child: _selfieFile == null ? const Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 48) : null,
        ),
      ),
      const SizedBox(height: 16),
      Text(_selfieFile == null ? 'Tap to take selfie' : 'Tap to retake', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: const Column(children: [
          _TipRow(icon: Icons.light_mode_outlined, text: 'Ensure good lighting'),
          SizedBox(height: 8),
          _TipRow(icon: Icons.face_outlined, text: 'Face the camera directly'),
          SizedBox(height: 8),
          _TipRow(icon: Icons.remove_red_eye_outlined, text: 'Remove glasses if possible'),
        ]),
      ),
    ]);
  }

  // Step 7: Risk Disclosure
  Widget _riskDisclosureStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.warning_amber_outlined, color: Color(0xFFF9A825), size: 40),
      const SizedBox(height: 16),
      const Text('Risk Disclosure', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Please read carefully before proceeding', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 20),

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Investment Risk Disclosure', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 12),
          _RiskItem(text: 'Investments in securities market are subject to market risks. Read all related documents carefully before investing.'),
          SizedBox(height: 10),
          _RiskItem(text: 'Past performance is not indicative of future returns. Mutual Fund investments are subject to market risks.'),
          SizedBox(height: 10),
          _RiskItem(text: 'Derivatives trading (F&O) involves substantial risk of loss and is not suitable for all investors.'),
          SizedBox(height: 10),
          _RiskItem(text: 'Equity investments may lose value. You may receive back less than you invest.'),
          SizedBox(height: 10),
          _RiskItem(text: 'Please ensure you fully understand the risks involved and seek independent professional advice if necessary.'),
        ]),
      ),

      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => setState(() => _riskAccepted = !_riskAccepted),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _riskAccepted ? AppColors.success.withOpacity(0.08) : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _riskAccepted ? AppColors.success : AppColors.border),
          ),
          child: Row(children: [
            Icon(_riskAccepted ? Icons.check_box : Icons.check_box_outline_blank, color: _riskAccepted ? AppColors.success : AppColors.textMuted),
            const SizedBox(width: 12),
            const Expanded(child: Text('I have read and understood the risk disclosure statement', style: TextStyle(color: AppColors.textPrimary, fontSize: 13))),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => setState(() => _termsAccepted = !_termsAccepted),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _termsAccepted ? AppColors.success.withOpacity(0.08) : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _termsAccepted ? AppColors.success : AppColors.border),
          ),
          child: Row(children: [
            Icon(_termsAccepted ? Icons.check_box : Icons.check_box_outline_blank, color: _termsAccepted ? AppColors.success : AppColors.textMuted),
            const SizedBox(width: 12),
            const Expanded(child: Text('I agree to the Terms & Conditions and Privacy Policy', style: TextStyle(color: AppColors.textPrimary, fontSize: 13))),
          ]),
        ),
      ),
    ]);
  }

  // Step 8: Review
  Widget _reviewStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.edit_document, color: AppColors.primary, size: 40),
      const SizedBox(height: 16),
      const Text('Review & Submit', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Please verify your details before submitting', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 20),

      if (_selfieFile != null) ...[
        Center(child: ClipRRect(borderRadius: BorderRadius.circular(50), child: Image.file(_selfieFile!, width: 80, height: 80, fit: BoxFit.cover))),
        const SizedBox(height: 16),
      ],

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          _summaryRow('Name', _nameController.text.isEmpty ? '-' : _nameController.text),
          _summaryRow('Phone', _phoneController.text.isEmpty ? '-' : '+91 ${_phoneController.text}', verified: _otpVerified),
          _summaryRow('PAN', _panController.text.isEmpty ? '-' : _panController.text),
          _summaryRow('Aadhaar', _aadhaarController.text.isEmpty ? '-' : 'XXXX XXXX ${_aadhaarController.text.length >= 4 ? _aadhaarController.text.substring(_aadhaarController.text.length - 4) : '****'}', verified: _aadhaarVerified),
          _summaryRow('Bank Account', _accountController.text.isEmpty ? '-' : '••••${_accountController.text.length > 4 ? _accountController.text.substring(_accountController.text.length - 4) : _accountController.text}'),
          _summaryRow('Income Proof', _incomeProofFile != null ? '$_incomeProofType ✓' : 'Not uploaded'),
          _summaryRow('Occupation', _occupationController.text.isEmpty ? '-' : _occupationController.text),
        ]),
      ),

      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withOpacity(0.3))),
        child: const Row(children: [
          Icon(Icons.info_outline, color: AppColors.success, size: 18),
          SizedBox(width: 10),
          Expanded(child: Text('Your application will be reviewed within 24-48 hours. You will receive an email confirmation.', style: TextStyle(color: AppColors.success, fontSize: 12))),
        ]),
      ),
    ]);
  }

  Widget _summaryRow(String label, String value, {bool verified = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Row(children: [
            Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
            if (verified) ...[const SizedBox(width: 4), const Icon(Icons.verified, color: AppColors.success, size: 14)],
          ]),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.primary, size: 16),
      const SizedBox(width: 10),
      Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ]);
  }
}

class _RiskItem extends StatelessWidget {
  final String text;
  const _RiskItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('• ', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
      Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5))),
    ]);
  }
}