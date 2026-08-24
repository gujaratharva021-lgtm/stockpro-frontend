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