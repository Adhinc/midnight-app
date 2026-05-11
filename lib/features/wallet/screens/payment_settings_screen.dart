import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme.dart';
import '../../../core/validators.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upiController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _existingAccountNumber;

  @override
  void initState() {
    super.initState();
    _loadPaymentDetails();
  }

  Future<void> _loadPaymentDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        final payout = data['payoutInfo'] as Map<String, dynamic>?;
        if (payout != null) {
          _upiController.text = payout['upiId'] ?? '';
          _existingAccountNumber = payout['accountNumber'];
          if (_existingAccountNumber != null && _existingAccountNumber!.length > 4) {
             // Mask account number: ************1234
            _accountNumberController.text = '************${_existingAccountNumber!.substring(_existingAccountNumber!.length - 4)}';
          } else {
            _accountNumberController.text = _existingAccountNumber ?? '';
          }
          _ifscController.text = payout['ifscCode'] ?? '';
        }
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading payout info: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_formKey.currentState!.validate()) return;

    final upi = _upiController.text.trim();
    var acc = _accountNumberController.text.trim();
    final ifsc = _ifscController.text.trim().toUpperCase();

    // Logic: Either UPI or (Acc AND IFSC) must be complete
    bool hasUPI = upi.isNotEmpty;
    bool hasBank = acc.isNotEmpty && ifsc.isNotEmpty;
    
    if (!hasUPI && !hasBank) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide either a valid UPI ID or complete Bank details")));
      return;
    }

    // Confirmation for overwrite
    if (_existingAccountNumber != null || _upiController.text.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: MidnightTheme.surfaceColor,
          title: const Text("Confirm Change", style: TextStyle(color: Colors.white)),
          content: const Text("Are you sure you want to update your payout details? Earnings will be sent to this new account.", style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Update", style: TextStyle(color: MidnightTheme.primaryColor))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    // If account number is still masked, use the existing one
    if (acc.contains('****')) {
      acc = _existingAccountNumber!;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'payoutInfo': {
          'upiId': upi,
          'accountNumber': acc,
          'ifscCode': ifsc,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payout details updated!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeDetails() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MidnightTheme.surfaceColor,
        title: const Text("Remove Payout Info", style: TextStyle(color: Colors.white)),
        content: const Text("This will remove your saved bank/UPI details. You won't be able to withdraw earnings until you add them back.", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'payoutInfo': FieldValue.delete(),
      });
      if (mounted) {
        _upiController.clear();
        _accountNumberController.clear();
        _ifscController.clear();
        _existingAccountNumber = null;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payout info removed")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _upiController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Payout Settings", style: TextStyle(color: Colors.white)),
        actions: [
          if (!_isLoading && (_existingAccountNumber != null || _upiController.text.isNotEmpty))
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _removeDetails),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: MidnightTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("UPI Details"),
                    const SizedBox(height: 16),
                    _buildFormField("UPI ID (e.g., user@okaxis)", _upiController, validator: Validators.upiId),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Bank Transfer"),
                    const SizedBox(height: 16),
                    _buildFormField("Account Number", _accountNumberController, keyboardType: TextInputType.number, maxLength: 18, validator: Validators.accountNumber, 
                      onChanged: (val) {
                        // If user starts typing in a masked field, clear it
                        if (val.contains('****')) _accountNumberController.clear();
                      }),
                    const SizedBox(height: 16),
                    _buildFormField("IFSC Code", _ifscController, maxLength: 11, validator: Validators.ifscCode, textCapitalization: TextCapitalization.characters),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveDetails,
                        style: ElevatedButton.styleFrom(backgroundColor: MidnightTheme.primaryColor, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text("Save Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(color: MidnightTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 16));
  }

  Widget _buildFormField(String label, TextEditingController controller, {TextInputType? keyboardType, int? maxLength, String? Function(String?)? validator, TextCapitalization textCapitalization = TextCapitalization.none, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      validator: validator,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: MidnightTheme.surfaceColor,
        counterStyle: const TextStyle(color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MidnightTheme.primaryColor)),
      ),
    );
  }
}
