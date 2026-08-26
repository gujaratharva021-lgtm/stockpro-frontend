$path = Join-Path (Get-Location) "lib\features\onboarding\screens\onboarding_flow.dart"
$content = [System.IO.File]::ReadAllText($path)

$old = @'
  void _next() {
    if (_step < _stepTitles.length - 1) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }
'@

$new = @'
  void _next() {
    final error = _validateStep();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (_step < _stepTitles.length - 1) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  String? _validateStep() {
    switch (_step) {
      case 0:
        if (_nameController.text.trim().isEmpty) return 'Please enter your full name';
        if (_occupationController.text.trim().isEmpty) return 'Please enter your occupation';
        if (_phoneController.text.trim().length != 10) return 'Please enter a valid 10-digit phone number';
        return null;
      case 1:
        if (!_otpVerified) return 'Please verify your mobile number with OTP';
        return null;
      case 2:
        if (_panController.text.trim().length != 10) return 'Please enter a valid 10-character PAN number';
        return null;
      case 3:
        if (!_aadhaarVerified) return 'Please verify your Aadhaar with OTP';
        return null;
      case 4:
        if (_accountController.text.trim().isEmpty) return 'Please enter your bank account number';
        if (_ifscController.text.trim().isEmpty) return 'Please enter your IFSC code';
        return null;
      case 5:
        if (_incomeProofFile == null) return 'Please upload your income proof document';
        return null;
      case 6:
        if (_selfieFile == null) return 'Please take a selfie for identity verification';
        return null;
      case 7:
        if (!_riskAccepted) return 'Please accept the risk disclosure statement';
        if (!_termsAccepted) return 'Please accept the Terms & Conditions';
        return null;
      default:
        return null;
    }
  }
'@

if ($content -notmatch [regex]::Escape($old)) {
    Write-Host "ERROR: Original block not found - file might have changed. No edits made." -ForegroundColor Red
} else {
    $content = $content.Replace($old, $new)
    [System.IO.File]::WriteAllText($path, $content)
    Write-Host "SUCCESS: _next() replaced with validated version." -ForegroundColor Green
}