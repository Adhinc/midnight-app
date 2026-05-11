import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme.dart';
import '../../auth/screens/phone_login_screen.dart';
import 'legal_screen.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Delete Account", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will permanently delete your account, wallet balance, and all your data. This cannot be undone.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete Everything", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: MidnightTheme.primaryColor)),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final uid = user.uid;
        final firestore = FirebaseFirestore.instance;

        // 1. Cancel all active/ending calls
        final activeStatuses = ['open', 'pending', 'accepted', 'connected', 'ending'];
        final seekerRequests = await firestore.collection('requests').where('seekerId', isEqualTo: uid).where('status', whereIn: activeStatuses).get();
        final listenerRequests = await firestore.collection('requests').where('listenerId', isEqualTo: uid).where('status', whereIn: activeStatuses).get();
        
        final batch = firestore.batch();
        for (var doc in [...seekerRequests.docs, ...listenerRequests.docs]) {
          batch.update(doc.reference, {'status': 'cancelled', 'cancelledAt': FieldValue.serverTimestamp()});
        }
        if (seekerRequests.docs.isNotEmpty || listenerRequests.docs.isNotEmpty) await batch.commit();

        // 2. Delete Firestore Data (Subcollections first)
        // Note: Client-side subcollection deletion is limited. Ideally this would be a Cloud Function.
        // We'll delete the main subcollections we know about.
        final transactions = await firestore.collection('users').doc(uid).collection('transactions').get();
        final connections = await firestore.collection('users').doc(uid).collection('stay_connected').get();
        
        final deleteBatch = firestore.batch();
        for (var doc in transactions.docs) deleteBatch.delete(doc.reference);
        for (var doc in connections.docs) deleteBatch.delete(doc.reference);
        deleteBatch.delete(firestore.collection('users').doc(uid));
        
        await deleteBatch.commit();

        // 3. Delete Auth Account LAST
        try {
          await user.delete();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            if (context.mounted) {
              Navigator.pop(context); // Close loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Sensitive action: Please re-login and try again to delete.")),
              );
              return;
            }
          }
          rethrow;
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error during deletion: $e")));
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
        title: const Text("Account Settings", style: TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader("Coming Soon"),
          _buildComingSoonTile("Notifications", "Receive alerts for incoming calls"),
          _buildComingSoonTile("Incognito Mode", "Hide your online status"),

          const SizedBox(height: 32),
          _buildSectionHeader("Legal"),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Privacy Policy", style: TextStyle(color: Colors.white)),
            subtitle: const Text("How we handle your data", style: TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalScreen(title: "Privacy Policy", content: LegalScreen.getPrivacyPolicy()))),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Terms of Use", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Rules for using Midnight", style: TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalScreen(title: "Terms of Use", content: LegalScreen.getTermsOfUse()))),
          ),

          const SizedBox(height: 32),
          _buildSectionHeader("Danger Zone"),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Delete Account", style: TextStyle(color: Colors.red)),
            subtitle: const Text("Permanently remove your account and balance", style: TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: Colors.red),
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title.toUpperCase(), style: const TextStyle(color: MidnightTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildComingSoonTile(String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white54)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
        child: const Text("Soon", style: TextStyle(color: Colors.grey, fontSize: 11)),
      ),
    );
  }
}
