import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../wallet/services/wallet_service.dart';
import '../../call/services/request_service.dart';
import '../../call/models/help_request.dart';
import '../../home/screens/home_screen.dart';

class ListenerEarningsScreen extends StatefulWidget {
  final String requestId;
  final Duration callDuration;

  const ListenerEarningsScreen({
    super.key,
    required this.requestId,
    required this.callDuration,
  });

  @override
  State<ListenerEarningsScreen> createState() => _ListenerEarningsScreenState();
}

class _ListenerEarningsScreenState extends State<ListenerEarningsScreen> {
  final RequestService _requestService = RequestService();
  HelpRequest? _request;
  bool _isLoading = true;
  bool _hasAddedEarnings = false;

  @override
  void initState() {
    super.initState();
    _loadRequestData();
  }

  Future<void> _loadRequestData() async {
    final request = await _requestService.getRequestById(widget.requestId);
    if (mounted) {
      setState(() {
        _request = request;
        _isLoading = false;
      });
      if (request != null && !_hasAddedEarnings) {
        _hasAddedEarnings = true;
        _addToWallet(request);
      }
    }
  }

  Future<void> _addToWallet(HelpRequest request) async {
    final walletService = WalletService();
    final basePay = AppConstants.sessionBasePay.toDouble();
    final tipAmount = (request.tip ?? 0).toDouble();
    final totalAmount = basePay + tipAmount;

    // Single call with total amount to avoid isPaid flag blocking the tip
    final description = tipAmount > 0
        ? "Session Earnings (₹${basePay.toInt()} base + ₹${tipAmount.toInt()} tip)"
        : "Session Earnings (Base)";

    final success = await walletService.addEarnings(totalAmount, description, request.id);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to add earnings. Please contact support."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final basePay = AppConstants.sessionBasePay;
    final tip = _request?.tip ?? 0;
    final total = basePay + tip;
    final rating = _request?.rating ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Success Icon
              const Icon(
                Icons.check_circle,
                color: Color(0xFF00E676),
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                "Great job!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "You just helped someone feel heard.",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 48),

              // Earnings Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: MidnightTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    _buildRow("Base Pay", "₹$basePay", Colors.white),
                    const SizedBox(height: 16),
                    if (tip > 0)
                      _buildRow(
                        "Tip Received",
                        "+ ₹$tip",
                        const Color(0xFF00E676),
                        isBold: true,
                      ),
                    if (tip > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: Colors.white24),
                      ),
                    _buildRow(
                      "Total Earned",
                      "₹$total",
                      Colors.white,
                      isTotal: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Rating Feedback
              if (rating > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "User rated you: ",
                        style: TextStyle(color: Colors.amber),
                      ),
                      ...List.generate(
                        rating,
                        (index) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                      ...List.generate(
                        5 - rating,
                        (index) => const Icon(
                          Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Return Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate back to Dashboard cleanly
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HomeScreen(isListener: true),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Return to Night Watch",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.white : Colors.grey,
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isTotal ? 24 : 16,
            fontWeight: (isBold || isTotal)
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
