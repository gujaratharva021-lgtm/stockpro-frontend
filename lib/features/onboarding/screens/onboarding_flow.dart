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

  final _nameController = TextEditingController();
  final _occupationController = TextEditingController(text: 'Student');
  final _panController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _phoneController = TextEditingController();

  final List<String> _stepTitles = ['Personal Details', 'PAN Verification', 'Bank Account', 'Selfie', 'E-Sign'];

  Future<void> _pickSelfie() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    if (picked != null) setState(() => _selfieFile = File(picked.path));
  }

  void _next() {
    if (_step < _stepTitles.length - 1) { setState(() => _step++); } else { _submit(); }
  }

  void _back() {
    if (_step > 0) { setState(() => _step--); } else { Navigator.maybePop(context); }
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
          const SizedBox(width: 48),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: List.generate(_stepTitles.length, (i) => Expanded(
            child: Container(margin: const EdgeInsets.symmetric(horizontal: 3), height: 4, decoration: BoxDecoration(color: i <= _step ? AppColors.primary : AppColors.border, borderRadius: BorderRadius.circular(4))),
          )),
        ),
      ),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildStepContent())),
      Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _next,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_step == _stepTitles.length - 1 ? 'Submit' : 'Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))]),
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
      case 1: return _panStep();
      case 2: return _bankStep();
      case 3: return _selfieStep();
      case 4: return _esignStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _field(String label, TextEditingController controller, {String? hint, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, TextCapitalization textCapitalization = TextCapitalization.none}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: TextField(controller: controller, keyboardType: keyboardType, inputFormatters: inputFormatters, textCapitalization: textCapitalization, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14), decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))),
        ),
      ]),
    );
  }

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

  Widget _panStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.badge_outlined, color: AppColors.primary, size: 40),
      const SizedBox(height: 16),
      const Text('PAN Verification', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Required for regulatory compliance', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 24),
      _field('PAN Number', _panController, hint: 'ABCDE1234F', textCapitalization: TextCapitalization.characters, inputFormatters: [LengthLimitingTextInputFormatter(10), TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase()))]),
    ]);
  }

  Widget _bankStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 40),
      const SizedBox(height: 16),
      const Text('Link Bank Account', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Used to fund your trading wallet', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 24),
      _field('Account Number', _accountController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(20)]),
      _field('IFSC Code', _ifscController, hint: 'e.g. HDFC0001234', textCapitalization: TextCapitalization.characters),
    ]);
  }

  Widget _selfieStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const SizedBox(height: 20),
      GestureDetector(
        onTap: _pickSelfie,
        child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1), border: Border.all(color: AppColors.primary, width: 2), image: _selfieFile != null ? DecorationImage(image: FileImage(_selfieFile!), fit: BoxFit.cover) : null),
            child: _selfieFile == null ? const Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 40) : null),
      ),
      const SizedBox(height: 24),
      Text(_selfieFile == null ? 'Take a selfie' : 'Looking good!', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(_selfieFile == null ? 'Tap the circle to open camera' : 'Tap to retake', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
    ]);
  }

  Widget _esignStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.edit_document, color: AppColors.primary, size: 40),
      const SizedBox(height: 16),
      const Text('Review & E-Sign', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('By submitting, you agree to our Terms & Conditions', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 24),
      if (_selfieFile != null) ...[
        Center(child: ClipRRect(borderRadius: BorderRadius.circular(60), child: Image.file(_selfieFile!, width: 80, height: 80, fit: BoxFit.cover))),
        const SizedBox(height: 20),
      ],
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          _summaryRow('Name', _nameController.text.isEmpty ? '-' : _nameController.text),
          _summaryRow('Occupation', _occupationController.text.isEmpty ? '-' : _occupationController.text),
          _summaryRow('Phone', _phoneController.text.isEmpty ? '-' : _phoneController.text),
          _summaryRow('PAN', _panController.text.isEmpty ? '-' : _panController.text),
          _summaryRow('Bank Account', _accountController.text.isEmpty ? '-' : '••••${_accountController.text.length > 4 ? _accountController.text.substring(_accountController.text.length - 4) : _accountController.text}'),
        ]),
      ),
    ]);
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}