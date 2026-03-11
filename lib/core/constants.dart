import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get agoraAppId => dotenv.env['AGORA_APP_ID'] ?? '';
  static String get razorpayKey => dotenv.env['RAZORPAY_KEY'] ?? '';

  // Session pricing (in INR)
  static const int sessionBasePay = 30; // Amount listener earns per session
  static const int sessionCost = 30; // Amount seeker pays per session
}
