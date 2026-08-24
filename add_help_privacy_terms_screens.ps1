$ErrorActionPreference = "Stop"

function Write-Utf8NoBom {
    param($Path, $Content)
    $normalized = $Content -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText($Path, $normalized, [System.Text.UTF8Encoding]::new($false))
}

# ---------- 1) static_content_screen.dart (reusable renderer) ----------
$dir = "lib\features\profile\screens"
if (-not (Test-Path $dir)) {
    Write-Host "Directory not found: $dir - run this from your project root." -ForegroundColor Red
    exit 1
}

$staticContent = @'
import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class StaticContentSection {
  final String? heading;
  final String body;
  const StaticContentSection({this.heading, required this.body});
}

class StaticContentScreen extends StatelessWidget {
  final String title;
  final List<StaticContentSection> sections;
  const StaticContentScreen({super.key, required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final s in sections) ...[
            if (s.heading != null) ...[
              Text(s.heading!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
            Text(s.body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
'@
Write-Utf8NoBom "$dir\static_content_screen.dart" $staticContent
Write-Host "OK: created static_content_screen.dart" -ForegroundColor Green

# ---------- 2) privacy_policy_screen.dart ----------
$privacyPolicy = @'
import 'package:flutter/material.dart';
import 'package:stock_app/features/profile/screens/static_content_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaticContentScreen(
      title: 'Privacy Policy',
      sections: [
        StaticContentSection(
          body: 'This app is a virtual trading simulator for practice and learning purposes. No real money is invested or withdrawn through this app.',
        ),
        StaticContentSection(
          heading: 'Information We Collect',
          body: 'We collect the information you provide when creating an account, such as your name, email address, and phone number, along with your in-app trading activity (virtual orders, holdings, and watchlists).',
        ),
        StaticContentSection(
          heading: 'How We Use Your Information',
          body: 'Your information is used to operate your account, show your portfolio and order history, and improve app features. We do not sell your personal information to third parties.',
        ),
        StaticContentSection(
          heading: 'Data Storage',
          body: 'Your account data is stored securely on our servers. We take reasonable measures to protect it from unauthorized access.',
        ),
        StaticContentSection(
          heading: 'Third-Party Services',
          body: 'The app may use third-party services for market data and read-only brokerage account linking. These services have their own privacy policies governing the data they process.',
        ),
        StaticContentSection(
          heading: 'Your Choices',
          body: 'You can update or delete your account information from within the app, or by contacting support.',
        ),
        StaticContentSection(
          heading: 'Contact Us',
          body: 'If you have questions about this policy, reach out to us via the Help & Support section in the app.',
        ),
      ],
    );
  }
}
'@
Write-Utf8NoBom "$dir\privacy_policy_screen.dart" $privacyPolicy
Write-Host "OK: created privacy_policy_screen.dart" -ForegroundColor Green

# ---------- 3) terms_of_service_screen.dart ----------
$termsOfService = @'
import 'package:flutter/material.dart';
import 'package:stock_app/features/profile/screens/static_content_screen.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaticContentScreen(
      title: 'Terms of Service',
      sections: [
        StaticContentSection(
          body: 'By using this app, you agree to the following terms. Please read them carefully.',
        ),
        StaticContentSection(
          heading: '1. Virtual Trading Only',
          body: 'This app provides a simulated trading environment using virtual currency. No real securities are bought or sold, and no real money changes hands through the trading features.',
        ),
        StaticContentSection(
          heading: '2. Not Investment Advice',
          body: 'Prices, predictions, and analytics shown in the app are for educational purposes only and do not constitute financial or investment advice. Always consult a licensed advisor before making real investment decisions.',
        ),
        StaticContentSection(
          heading: '3. Account Responsibility',
          body: 'You are responsible for maintaining the confidentiality of your account credentials and for all activity under your account.',
        ),
        StaticContentSection(
          heading: '4. Acceptable Use',
          body: 'You agree not to misuse the app, attempt to disrupt its operation, or use it for any unlawful purpose.',
        ),
        StaticContentSection(
          heading: '5. Changes to the Service',
          body: 'We may update, modify, or discontinue features of the app at any time without prior notice.',
        ),
        StaticContentSection(
          heading: '6. Limitation of Liability',
          body: 'The app is provided as is without warranties of any kind. We are not liable for any losses arising from reliance on data shown in the app.',
        ),
        StaticContentSection(
          heading: '7. Contact',
          body: 'For questions about these terms, please reach out via the Help & Support section.',
        ),
      ],
    );
  }
}
'@
Write-Utf8NoBom "$dir\terms_of_service_screen.dart" $termsOfService
Write-Host "OK: created terms_of_service_screen.dart" -ForegroundColor Green

# ---------- 4) help_support_screen.dart ----------
$helpSupport = @'
import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    {
      'q': 'Is this real trading with real money?',
      'a': 'No. All trades here are virtual and use simulated funds for learning purposes only.',
    },
    {
      'q': 'Why is my order still Pending?',
      'a': 'Limit and stop-loss orders stay Pending until the market price reaches your trigger price. You can check status anytime under Orders.',
    },
    {
      'q': 'How do I cancel or modify an order?',
      'a': 'Go to Orders, then tap Modify or Cancel on the relevant order.',
    },
    {
      'q': 'How do I link my brokerage account?',
      'a': 'You can link a read-only brokerage account from the Import Holdings option in your Portfolio to view your real holdings alongside your virtual ones.',
    },
    {
      'q': 'How do I reset my password?',
      'a': 'Use the Forgot Password link on the sign-in screen to receive a reset link on your registered email.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Help & Support', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Frequently Asked Questions', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                for (int i = 0; i < _faqs.length; i++)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      iconColor: AppColors.primary,
                      collapsedIconColor: AppColors.textMuted,
                      title: Text(_faqs[i]['q']!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_faqs[i]['a']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Still need help?', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.email_outlined, color: AppColors.primary, size: 18),
                    SizedBox(width: 10),
                    Text('support@oneinvest.app', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.access_time, color: AppColors.primary, size: 18),
                    SizedBox(width: 10),
                    Text('We usually respond within 24-48 hours', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
'@
Write-Utf8NoBom "$dir\help_support_screen.dart" $helpSupport
Write-Host "OK: created help_support_screen.dart" -ForegroundColor Green

# ---------- 5) patch settings_screen.dart ----------
$settingsFile = "$dir\settings_screen.dart"
$raw = [System.IO.File]::ReadAllText($settingsFile, [System.Text.Encoding]::UTF8)
$content = $raw -replace "`r`n", "`n"

function Replace-Once {
    param($text, $old, $new, $label)
    $count = ([regex]::Matches($text, [regex]::Escape($old))).Count
    if ($count -eq 1) {
        Write-Host "OK ($label): applied." -ForegroundColor Green
        return $text.Replace($old, $new)
    } elseif ($count -eq 0) {
        Write-Host "SKIP ($label): pattern not found." -ForegroundColor Yellow
        return $text
    } else {
        Write-Host "WARN ($label): matched $count times, replacing all." -ForegroundColor Yellow
        return $text.Replace($old, $new)
    }
}

# imports
$oldImports = @'
import 'package:stock_app/features/profile/screens/security_screen.dart';
'@
$newImports = @'
import 'package:stock_app/features/profile/screens/security_screen.dart';
import 'package:stock_app/features/profile/screens/help_support_screen.dart';
import 'package:stock_app/features/profile/screens/privacy_policy_screen.dart';
import 'package:stock_app/features/profile/screens/terms_of_service_screen.dart';
'@
$content = Replace-Once $content $oldImports $newImports "imports"

# last card (Help & Support / Privacy Policy / Terms of Service)
$oldCard = @'
          _card([
            _navItem(Icons.help_outline, 'Help & Support', null, onTap: () => _comingSoon('Help & Support')),
            _navItem(Icons.privacy_tip_outlined, 'Privacy Policy', null, onTap: () => _comingSoon('Privacy Policy')),
            _navItem(Icons.description_outlined, 'Terms of Service', null, onTap: () => _comingSoon('Terms of Service'), showDivider: false),
          ]),
'@
$newCard = @'
          _card([
            _navItem(Icons.help_outline, 'Help & Support', null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
            _navItem(Icons.privacy_tip_outlined, 'Privacy Policy', null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()))),
            _navItem(Icons.description_outlined, 'Terms of Service', null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen())), showDivider: false),
          ]),
'@
$content = Replace-Once $content $oldCard $newCard "help-privacy-terms-card"

Write-Utf8NoBom $settingsFile $content
Write-Host ""
Write-Host "Done. Run: flutter analyze  then  flutter run" -ForegroundColor Cyan
