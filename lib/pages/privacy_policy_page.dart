import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Privacy Policy")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: const Text('''
Privacy Policy

Last Updated: 2026

Expense Tracker respects your privacy.

1. Information We Collect
We only collect information necessary to provide core app functionality. This may include:
- Email address (for authentication)
- Transaction data (income & expenses)
- Profile image (stored locally)

2. How We Use Information
Your data is used only to:
- Provide expense tracking features
- Synchronize your account (if applicable)
- Improve app performance

3. Data Storage
- Transaction data is securely stored.
- Profile images are stored locally on your device.
- We do not sell or share your personal information.

4. Third-Party Services
We may use services such as Firebase Authentication for login management.

5. Security
We take reasonable measures to protect your data from unauthorized access.

6. Your Rights
You can:
- Edit or delete your transactions anytime.
- Delete your account if authentication is enabled.

7. Contact Us
If you have questions, contact:
nayansuthar969@gmail.com

By using this app, you agree to this Privacy Policy.
          ''', style: TextStyle(fontSize: 14, height: 1.5)),
      ),
    );
  }
}
