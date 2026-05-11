import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _contactSupport(BuildContext context) async {
    const supportEmail = 'support@midnightapp.in';
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': 'Support Request - Midnight App'},
    );
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: MidnightTheme.surfaceColor,
              title: const Text("Email client not found", style: TextStyle(color: Colors.white)),
              content: const Text(
                "Please email us manually at support@midnightapp.in from your preferred mail app.",
                style: TextStyle(color: Colors.grey),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK", style: TextStyle(color: MidnightTheme.primaryColor)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open email app. Please email support@midnightapp.in manually.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Help & Support", style: TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Frequently Asked Questions",
              style: TextStyle(color: MidnightTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            _buildFAQItem("How do I find a listener?", "Simply select your mood on the home screen and tap the large circle button."),
            _buildFAQItem("Is my conversation private?", "Yes, all calls are anonymous and not recorded."),
            _buildFAQItem("How do I become a listener?", "Go to your profile and switch to Listener Mode."),
            _buildFAQItem("How does payment work?", "Your wallet is charged after each session. You can top up your wallet anytime from the wallet screen."),
            _buildFAQItem("How do I report someone?", "During a call, tap the ⋮ menu in the top right corner and select 'Report User'."),
            const SizedBox(height: 32),
            const Text("Need more help?", style: TextStyle(color: MidnightTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _contactSupport(context),
                icon: const Icon(Icons.email, color: Colors.black),
                label: const Text("Contact Support"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(child: Text("support@midnightapp.in", style: TextStyle(color: Colors.grey, fontSize: 12))),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(answer, style: const TextStyle(color: Colors.grey, height: 1.5)),
        ],
      ),
    );
  }
}
