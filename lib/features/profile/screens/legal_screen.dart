import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          content,
          style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.6),
        ),
      ),
    );
  }

  // Helper to get Privacy Policy Content
  static String getPrivacyPolicy() {
    return """
Privacy Policy for Midnight App

Last Updated: March 2026

1. Introduction
Welcome to Midnight. Your privacy is critically important to us.

2. Information We Collect
- Account Info: Your nickname/handle and email.
- Usage Data: Duration of calls and session history.
- Audio: Calls are peer-to-peer and NOT recorded by our servers.

3. How We Use Data
We use your data strictly to provide the matchmaking service and process listener earnings.

4. Third Parties
We use Firebase for data storage and Agora for audio transmission. We do not sell your personal data.

5. Your Rights
You can delete your account and all associated data at any time from the Account Settings screen.
    """;
  }

  // Helper to get Terms of Use Content
  static String getTermsOfUse() {
    return """
Terms of Use for Midnight App

Last Updated: March 2026

1. Acceptance of Terms
By using Midnight, you agree to these terms.

2. Conduct
- You must be 18+ to use this app.
- Abusive, harassing, or illegal behavior during calls will result in an immediate ban.
- Midnight is NOT a professional therapy or crisis intervention service.

3. Payments
- Seeker payments are processed via Razorpay.
- Listener earnings are subject to a platform fee.
- Minimal withdrawal limit is ₹500.

4. Limitation of Liability
Midnight is provided "as is". We are not liable for any emotional distress or disagreements arising from peer-to-peer conversations.
    """;
  }
}
