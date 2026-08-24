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